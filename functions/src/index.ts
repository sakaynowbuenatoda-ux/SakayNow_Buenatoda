import {createHmac, timingSafeEqual} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();
const paymongoSecretKey = defineSecret("PAYMONGO_SECRET_KEY");
const paymongoWebhookSecret = defineSecret("PAYMONGO_WEBHOOK_SECRET");
const paymongoApiBaseUrl = "https://api.paymongo.com/v1";
const checkoutSuccessUrl = process.env.PAYMONGO_SUCCESS_URL ??
  "https://sakaynow-buenatoda.web.app/payment/success";
const checkoutCancelUrl = process.env.PAYMONGO_CANCEL_URL ??
  "https://sakaynow-buenatoda.web.app/payment/cancelled";
const checkoutAllowedMethods = new Set(["gcash", "paymaya", "card"]);
const regularMinimumRideFare = 20;
const minimumStudentDiscountedFare = 17;
const maximumRideFare = 100;
const studentDiscountRate = 0.15;
const studentDiscountCode = "verified_student";

type TokenTarget = {
  token: string;
  refPath: string;
};

type MulticastResponse = Awaited<
  ReturnType<typeof messaging.sendEachForMulticast>
>;

type CheckoutResponse = {
  data?: {
    id?: string;
    attributes?: {
      checkout_url?: string;
      status?: string;
    };
  };
  errors?: Array<{detail?: string; code?: string}>;
};

export const createPayMongoCheckoutSession = onCall(
  {
    region: "asia-southeast1",
    secrets: [paymongoSecretKey],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to pay for a ride.");
    }

    const bookingId = readRequiredString(request.data, "booking_id");
    const requestedPaymentMethod = readRequiredString(
      request.data,
      "payment_method_type",
    );
    const paymentMethodType = normalizePaymentMethod(requestedPaymentMethod);
    if (!checkoutAllowedMethods.has(paymentMethodType)) {
      throw new HttpsError("invalid-argument", "Unsupported payment method.");
    }

    const bookingRef = firestore.collection("bookings").doc(bookingId);
    const bookingSnapshot = await bookingRef.get();
    const booking = bookingSnapshot.data();
    if (!bookingSnapshot.exists || !booking) {
      throw new HttpsError("not-found", "Booking was not found.");
    }

    if (booking.passenger_id !== uid) {
      throw new HttpsError("permission-denied", "This is not your booking.");
    }

    if (booking.payment_provider !== "paymongo") {
      throw new HttpsError(
        "failed-precondition",
        "Booking is not using PayMongo.",
      );
    }

    const existingSessionId = readOptionalString(
      booking.paymongo_checkout_session_id,
    );
    const existingCheckoutUrl = readOptionalString(booking.paymongo_checkout_url);
    const paymentStatus = readOptionalString(booking.payment_status);
    if (
      existingSessionId &&
      existingCheckoutUrl &&
      paymentStatus !== "checkout_failed"
    ) {
      return {
        session_id: existingSessionId,
        checkout_url: existingCheckoutUrl,
        payment_status: paymentStatus ?? "checkout_pending",
      };
    }

    const passenger = await firestore.collection("users").doc(uid).get();
    const passengerData = passenger.data() ?? {};
    const amount = readFareAmount(booking);
    if (!isAllowedFareAmount({amount, booking, passengerData})) {
      throw new HttpsError(
        "failed-precondition",
        "Booking fare is not ready for checkout.",
      );
    }

    const checkout = await createCheckoutSession({
      secretKey: paymongoSecretKey.value(),
      bookingId,
      passengerId: uid,
      passengerName: fullName(passengerData),
      passengerEmail: readOptionalString(passengerData.email),
      amount,
      paymentMethodType,
      description: `SakayNow Buenatoda ride ${bookingId}`,
    });

    const sessionId = checkout.data?.id;
    const checkoutUrl = checkout.data?.attributes?.checkout_url;
    if (!sessionId || !checkoutUrl) {
      const detail = checkout.errors?.[0]?.detail ?? "Checkout URL missing.";
      throw new HttpsError("internal", detail);
    }

    await bookingRef.set(
      {
        paymongo_checkout_session_id: sessionId,
        paymongo_checkout_url: checkoutUrl,
        payment_status: "checkout_pending",
        payment_method: methodLabelForStorage(paymentMethodType),
        payment_provider: "paymongo",
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {
      session_id: sessionId,
      checkout_url: checkoutUrl,
      payment_status: "checkout_pending",
    };
  },
);

export const payMongoWebhook = onRequest(
  {
    region: "asia-southeast1",
    secrets: [paymongoWebhookSecret],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    const signature = request.header("paymongo-signature") ?? "";
    if (!isValidPayMongoSignature(
      request.rawBody,
      signature,
      paymongoWebhookSecret.value(),
    )) {
      response.status(401).send("Invalid signature");
      return;
    }

    const event = request.body?.data;
    const eventId = readOptionalString(event?.id);
    const eventType = readOptionalString(event?.attributes?.type);
    if (!eventId || !eventType) {
      response.status(400).send("Invalid event");
      return;
    }

    const eventRef = firestore.collection("payment_events").doc(eventId);
    const alreadyProcessed = await eventRef.get();
    if (alreadyProcessed.exists) {
      response.status(200).send("Already processed");
      return;
    }

    await eventRef.set({
      event_id: eventId,
      type: eventType,
      provider: "paymongo",
      received_at: FieldValue.serverTimestamp(),
      payload: request.body,
    });

    if (eventType === "checkout_session.payment.paid") {
      await markCheckoutPaid(event);
    } else if (eventType === "checkout_session.payment.failed") {
      await markCheckoutFailed(event);
    }

    response.status(200).send("ok");
  },
);

export const notifyNewChatMessage = onDocumentCreated(
  {
    region: "asia-southeast1",
    document: "conversations/{conversationId}/messages/{messageId}",
  },
  async (event) => {
    const messageSnapshot = event.data;
    if (!messageSnapshot) {
      return;
    }

    const message = messageSnapshot.data();
    const conversationId = event.params.conversationId;
    const senderId = readOptionalString(message.sender_id);
    const senderRole = readOptionalString(message.sender_role) ?? "passenger";
    const text = readOptionalString(message.text);
    if (!senderId || !text) {
      return;
    }

    const conversationSnapshot = await firestore
      .collection("conversations")
      .doc(conversationId)
      .get();
    const conversation = conversationSnapshot.data();
    if (!conversationSnapshot.exists || !conversation) {
      return;
    }

    const recipientIds = await notificationRecipientIds({
      conversation,
      senderId,
      senderRole,
    });
    if (recipientIds.length === 0) {
      return;
    }

    const targets = await notificationTargetsForUsers(recipientIds);
    if (targets.length === 0) {
      return;
    }

    const title = notificationTitle({conversation, senderId, senderRole});
    const body = truncateNotificationBody(text);
    const tokens = targets.map((target) => target.token);

    for (const tokenChunk of chunk(tokens, 500)) {
      const response = await messaging.sendEachForMulticast({
        tokens: tokenChunk,
        notification: {title, body},
        android: {
          priority: "high",
          notification: {
            channelId: "sakaynow_messages",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        data: {
          type: "chat_message",
          conversation_id: conversationId,
          conversation_type:
            readOptionalString(conversation.type) ?? "support",
          sender_id: senderId,
          sender_role: senderRole,
        },
      });

      await removeInvalidTokens({
        response,
        tokenChunk,
        targets,
      });
    }
  },
);

async function createCheckoutSession(params: {
  secretKey: string;
  bookingId: string;
  passengerId: string;
  passengerName: string;
  passengerEmail?: string;
  amount: number;
  paymentMethodType: string;
  description: string;
}): Promise<CheckoutResponse> {
  const encodedKey = Buffer.from(`${params.secretKey}:`).toString("base64");
  const response = await fetch(`${paymongoApiBaseUrl}/checkout_sessions`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${encodedKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        attributes: {
          billing: {
            name: params.passengerName,
            email: params.passengerEmail,
          },
          cancel_url: checkoutCancelUrl,
          success_url: checkoutSuccessUrl,
          description: params.description,
          line_items: [
            {
              amount: params.amount * 100,
              currency: "PHP",
              name: "SakayNow Buenatoda ride",
              quantity: 1,
            },
          ],
          metadata: {
            booking_id: params.bookingId,
            passenger_id: params.passengerId,
          },
          payment_method_types: [params.paymentMethodType],
          reference_number: params.bookingId,
          send_email_receipt: false,
          show_description: true,
          show_line_items: true,
        },
      },
    }),
  });

  const checkout = await response.json() as CheckoutResponse;
  if (!response.ok) {
    const detail = checkout.errors?.[0]?.detail ?? response.statusText;
    throw new HttpsError("internal", detail);
  }

  return checkout;
}

async function markCheckoutPaid(event: unknown) {
  const checkout = checkoutDataFromEvent(event);
  const bookingId = readOptionalString(checkout.metadata?.booking_id) ??
    await bookingIdForCheckoutSession(checkout.sessionId);
  if (!bookingId) {
    return;
  }

  const bookingRef = firestore.collection("bookings").doc(bookingId);
  const bookingSnapshot = await bookingRef.get();
  const bookingData = bookingSnapshot.data() ?? {};
  const driverId = readOptionalString(bookingData.driver_id);

  await bookingRef.set(
    {
      payment_status: "paid",
      payment_reference: checkout.referenceNumber ?? checkout.paymentId,
      paymongo_payment_id: checkout.paymentId,
      paymongo_checkout_session_id: checkout.sessionId,
      payment_method_used: checkout.paymentMethod,
      driver_payout_status: driverId ? "pending" : "awaiting_driver",
      paid_at: checkout.paidAt,
      payment_confirmed_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function markCheckoutFailed(event: unknown) {
  const checkout = checkoutDataFromEvent(event);
  const bookingId = readOptionalString(checkout.metadata?.booking_id) ??
    await bookingIdForCheckoutSession(checkout.sessionId);
  if (!bookingId) {
    return;
  }

  await firestore.collection("bookings").doc(bookingId).set(
    {
      payment_status: "checkout_failed",
      paymongo_checkout_session_id: checkout.sessionId,
      updated_at: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function notificationRecipientIds(params: {
  conversation: Record<string, unknown>;
  senderId: string;
  senderRole: string;
}) {
  const conversationType = readOptionalString(params.conversation.type);
  const participantIds = readStringArray(params.conversation.participant_ids)
    .filter((participantId) => participantId !== params.senderId);

  if (conversationType !== "support") {
    return participantIds;
  }

  if (params.senderRole === "admin") {
    return participantIds;
  }

  const adminSnapshot = await firestore
    .collection("users")
    .where("role", "==", "admin")
    .get();

  return adminSnapshot.docs
    .map((doc) => doc.id)
    .filter((adminId) => adminId !== params.senderId);
}

async function notificationTargetsForUsers(userIds: string[]) {
  const uniqueUserIds = [...new Set(userIds)];
  const targets: TokenTarget[] = [];

  for (const userId of uniqueUserIds) {
    const snapshot = await firestore
      .collection("users")
      .doc(userId)
      .collection("fcm_tokens")
      .get();

    snapshot.docs.forEach((doc) => {
      const token = readOptionalString(doc.data().token);
      if (token) {
        targets.push({token, refPath: doc.ref.path});
      }
    });
  }

  return targets;
}

function notificationTitle(params: {
  conversation: Record<string, unknown>;
  senderId: string;
  senderRole: string;
}) {
  if (params.senderRole === "admin") {
    return "SakayNow Support";
  }

  const participantNames = readMap(params.conversation.participant_names);
  const senderName = readOptionalString(participantNames[params.senderId]);
  if (senderName) {
    return senderName;
  }

  return params.senderRole === "driver" ? "Driver" : "Passenger";
}

function truncateNotificationBody(text: string) {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (normalized.length <= 120) {
    return normalized;
  }

  return `${normalized.substring(0, 117)}...`;
}

function chunk<T>(items: T[], size: number) {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }

  return chunks;
}

async function removeInvalidTokens(params: {
  response: MulticastResponse;
  tokenChunk: string[];
  targets: TokenTarget[];
}) {
  const deletes: Promise<unknown>[] = [];

  params.response.responses.forEach((item, index) => {
    if (item.success) {
      return;
    }

    const code = item.error?.code;
    if (
      code !== "messaging/registration-token-not-registered" &&
      code !== "messaging/invalid-registration-token"
    ) {
      return;
    }

    const token = params.tokenChunk[index];
    const target = params.targets.find((candidate) => candidate.token === token);
    if (target) {
      deletes.push(firestore.doc(target.refPath).delete());
    }
  });

  await Promise.all(deletes);
}

function checkoutDataFromEvent(event: unknown): {
  sessionId?: string;
  paymentId?: string;
  paymentMethod?: string;
  referenceNumber?: string;
  paidAt?: Timestamp;
  metadata?: Record<string, unknown>;
} {
  const eventData = event as {
    attributes?: {
      data?: {
        id?: string;
        attributes?: {
          metadata?: Record<string, unknown>;
          payments?: Array<{
            id?: string;
            attributes?: {
              paid_at?: number;
              source?: {type?: string};
            };
          }>;
          payment_method_used?: string;
          reference_number?: string;
        };
      };
    };
  };
  const session = eventData.attributes?.data;
  const attributes = session?.attributes ?? {};
  const payment = attributes.payments?.[0];
  const paidAt = payment?.attributes?.paid_at;

  return {
    sessionId: session?.id,
    paymentId: payment?.id,
    paymentMethod:
      attributes.payment_method_used ?? payment?.attributes?.source?.type,
    referenceNumber: attributes.reference_number,
    paidAt: typeof paidAt === "number" ?
      Timestamp.fromMillis(paidAt * 1000) :
      undefined,
    metadata: attributes.metadata,
  };
}

async function bookingIdForCheckoutSession(sessionId?: string) {
  if (!sessionId) {
    return undefined;
  }

  const snapshot = await firestore
    .collection("bookings")
    .where("paymongo_checkout_session_id", "==", sessionId)
    .limit(1)
    .get();
  return snapshot.docs[0]?.id;
}

function isValidPayMongoSignature(
  body: Buffer,
  signatureHeader: string,
  secret: string,
) {
  if (!secret || !signatureHeader) {
    return false;
  }

  const timestamp = signatureValue(signatureHeader, "t");
  const signature = signatureValue(signatureHeader, "v1");
  if (!timestamp || !signature) {
    return false;
  }

  const signedPayload = `${timestamp}.${body.toString("utf8")}`;
  const expected = createHmac("sha256", secret)
    .update(signedPayload)
    .digest("hex");
  const actualBuffer = Buffer.from(signature, "hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  return actualBuffer.length === expectedBuffer.length &&
    timingSafeEqual(actualBuffer, expectedBuffer);
}

function signatureValue(header: string, key: string) {
  return header
    .split(",")
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${key}=`))
    ?.split("=")[1];
}

function readRequiredString(data: unknown, field: string) {
  const map = data as Record<string, unknown>;
  const value = readOptionalString(map[field]);
  if (!value) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }

  return value;
}

function readOptionalString(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text.length === 0 ? undefined : text;
}

function isAllowedFareAmount(params: {
  amount: number;
  booking: Record<string, unknown>;
  passengerData: Record<string, unknown>;
}) {
  if (params.amount > maximumRideFare) {
    return false;
  }

  if (params.amount >= regularMinimumRideFare) {
    return true;
  }

  if (params.amount < minimumStudentDiscountedFare) {
    return false;
  }

  return hasVerifiedStudentDiscount(params);
}

function hasVerifiedStudentDiscount(params: {
  amount: number;
  booking: Record<string, unknown>;
  passengerData: Record<string, unknown>;
}) {
  const passengerType =
    readOptionalString(params.passengerData.passenger_type)?.toLowerCase() ??
    (readOptionalString(params.passengerData.role)?.toLowerCase() === "student" ?
      "student" :
      "regular");
  const isVerified = params.passengerData.is_verified === true ||
    params.passengerData.isVerified === true ||
    params.passengerData.isVerrified === true;
  if (passengerType !== "student" || !isVerified) {
    return false;
  }

  const fareDetails = readMap(params.booking.fare_details);
  const discountApplied = params.booking.fare_discount_applied === true ||
    fareDetails.discount_applied === true;
  const discountCode = readOptionalString(
    params.booking.fare_discount_code ?? fareDetails.discount_code,
  );
  const discountRate = readNumber(
    params.booking.fare_discount_rate ?? fareDetails.discount_rate,
  );
  const baseFare = readNumber(
    params.booking.base_fare ?? fareDetails.base_amount,
  );

  if (
    !discountApplied ||
    discountCode !== studentDiscountCode ||
    discountRate === undefined ||
    Math.abs(discountRate - studentDiscountRate) > 0.001 ||
    baseFare === undefined ||
    baseFare < regularMinimumRideFare ||
    baseFare > maximumRideFare
  ) {
    return false;
  }

  return Math.round(baseFare * (1 - studentDiscountRate)) === params.amount;
}

function readMap(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  return {};
}

function readStringArray(value: unknown) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => item?.toString().trim() ?? "")
    .filter((item) => item.length > 0);
}

function readNumber(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  const parsed = Number.parseFloat(value?.toString() ?? "");
  return Number.isFinite(parsed) ? parsed : undefined;
}

function readFareAmount(data: Record<string, unknown>) {
  const candidates = [
    data.final_fare,
    data.estimated_fare_amount,
    data.estimated_fare,
    data.fare_amount,
    data.fare,
  ];

  for (const candidate of candidates) {
    if (typeof candidate === "number") {
      return Math.round(candidate);
    }

    const parsed = Number.parseInt(
      candidate?.toString().replace(/[^0-9]/g, "") ?? "",
      10,
    );
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }

  return 0;
}

function fullName(data: Record<string, unknown>) {
  const name = `${readOptionalString(data.first_name) ?? ""} ${
    readOptionalString(data.last_name) ?? ""
  }`.trim();
  return name.length === 0 ? "SakayNow Passenger" : name;
}

function normalizePaymentMethod(value: string) {
  const normalized = value.trim().toLowerCase();
  if (normalized === "maya") {
    return "paymaya";
  }

  return normalized;
}

function methodLabelForStorage(value: string) {
  if (value === "paymaya") {
    return "maya";
  }

  return value;
}
