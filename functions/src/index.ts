import {createHmac, timingSafeEqual} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();
const paymongoSecretKey = defineSecret("PAYMONGO_SECRET_KEY");
const paymongoWebhookSecret = defineSecret("PAYMONGO_WEBHOOK_SECRET");
const xenditSecretKey = defineSecret("XENDIT_SECRET_KEY");
const xenditWebhookToken = defineSecret("XENDIT_WEBHOOK_TOKEN");
const paymongoApiBaseUrl = "https://api.paymongo.com/v1";
const xenditApiBaseUrl = "https://api.xendit.co";
const checkoutSuccessUrl = process.env.PAYMONGO_SUCCESS_URL ??
  "https://sakaynow-buenatoda.web.app/payment/success";
const checkoutCancelUrl = process.env.PAYMONGO_CANCEL_URL ??
  "https://sakaynow-buenatoda.web.app/payment/cancelled";
const checkoutAllowedMethods = new Set(["gcash", "paymaya", "card"]);
const xenditAllowedMethods = new Set(["GCASH", "PAYMAYA", "CREDIT_CARD"]);
const regularMinimumRideFare = 20;
const minimumStudentDiscountedFare = 17;
const maximumRideFare = 100;
const studentDiscountRate = 0.15;
const studentDiscountCode = "verified_student";

type TokenTarget = {
  token: string;
  refPath: string;
};

type AppNotificationChannel =
  "account" | "booking" | "message" | "review" | "system";

type AppNotificationParams = {
  userId: string;
  role?: string;
  type: string;
  title: string;
  body: string;
  channel: AppNotificationChannel;
  sourceId: string;
  data?: Record<string, unknown>;
  sendPush?: boolean;
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

type XenditInvoiceResponse = {
  id?: string;
  external_id?: string;
  status?: string;
  invoice_url?: string;
  message?: string;
  error_code?: string;
};

export const createXenditCheckoutSession = onCall(
  {
    region: "asia-southeast1",
    secrets: [xenditSecretKey],
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
    const paymentMethodType = normalizeXenditPaymentMethod(
      requestedPaymentMethod,
    );
    if (!xenditAllowedMethods.has(paymentMethodType)) {
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

    if (booking.payment_provider !== "xendit") {
      throw new HttpsError(
        "failed-precondition",
        "Booking is not using Xendit.",
      );
    }

    const existingInvoiceId = readOptionalString(booking.xendit_invoice_id);
    const existingCheckoutUrl = readOptionalString(booking.xendit_checkout_url);
    const paymentStatus = readOptionalString(booking.payment_status);
    if (
      existingInvoiceId &&
      existingCheckoutUrl &&
      paymentStatus !== "checkout_failed"
    ) {
      return {
        session_id: existingInvoiceId,
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

    const invoice = await createXenditInvoice({
      secretKey: xenditSecretKey.value(),
      bookingId,
      passengerName: fullName(passengerData),
      passengerEmail: readOptionalString(passengerData.email),
      amount,
      paymentMethodType,
      description: `SakayNow Buenatoda ride ${bookingId}`,
    });

    const invoiceId = invoice.id;
    const checkoutUrl = invoice.invoice_url;
    if (!invoiceId || !checkoutUrl) {
      throw new HttpsError(
        "internal",
        invoice.message ?? "Xendit checkout URL missing.",
      );
    }

    await bookingRef.set(
      {
        xendit_invoice_id: invoiceId,
        xendit_checkout_url: checkoutUrl,
        xendit_invoice_status: invoice.status ?? "PENDING",
        payment_status: "checkout_pending",
        payment_method: methodLabelForStorage(paymentMethodType),
        payment_provider: "xendit",
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {
      session_id: invoiceId,
      checkout_url: checkoutUrl,
      payment_status: "checkout_pending",
    };
  },
);

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

export const xenditWebhook = onRequest(
  {
    region: "asia-southeast1",
    secrets: [xenditWebhookToken],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    const callbackToken = request.header("x-callback-token") ?? "";
    if (!isValidXenditCallbackToken(
      callbackToken,
      xenditWebhookToken.value(),
    )) {
      response.status(401).send("Invalid callback token");
      return;
    }

    const invoice = xenditInvoiceDataFromWebhook(request.body);
    if (!invoice.invoiceId || !invoice.status) {
      response.status(400).send("Invalid invoice event");
      return;
    }

    const webhookId = readOptionalString(request.header("webhook-id"));
    const eventId = webhookId ??
      `xendit_${invoice.invoiceId}_${invoice.status}`;
    const eventRef = firestore.collection("payment_events").doc(eventId);
    const alreadyProcessed = await eventRef.get();
    if (alreadyProcessed.exists) {
      response.status(200).send("Already processed");
      return;
    }

    await eventRef.set({
      event_id: eventId,
      type: `invoice.${invoice.status.toLowerCase()}`,
      provider: "xendit",
      received_at: FieldValue.serverTimestamp(),
      payload: request.body,
    });

    if (invoice.status === "PAID" || invoice.status === "SETTLED") {
      await markXenditInvoicePaid(invoice);
    } else if (
      invoice.status === "EXPIRED" ||
      invoice.status === "FAILED"
    ) {
      await markXenditInvoiceFailed(invoice);
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

    const targets = await notificationTargetsForUsers(recipientIds, "message");
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

export const notifyNewVerificationRequest = onDocumentCreated(
  {
    region: "asia-southeast1",
    document: "users/{userId}",
  },
  async (event) => {
    const userSnapshot = event.data;
    if (!userSnapshot) {
      return;
    }

    const userId = event.params.userId;
    const user = userSnapshot.data();
    const role = normalizedUserRole(user);
    if (role === "admin" || isVerifiedAccount(user)) {
      return;
    }

    const name = fullName(user);
    await notifyAdmins({
      type: "verification_request",
      title: "New verification request",
      body: `${name} is waiting for account verification.`,
      channel: "system",
      sourceId: `verification_request_${userId}`,
      data: {
        user_id: userId,
        role,
      },
      sendPush: true,
    });
  },
);

export const notifyAccountStatusChanged = onDocumentUpdated(
  {
    region: "asia-southeast1",
    document: "users/{userId}",
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const userId = event.params.userId;
    const before = change.before.data();
    const after = change.after.data();
    const role = normalizedUserRole(after);
    if (role === "admin") {
      return;
    }

    const wasVerified = isVerifiedAccount(before);
    const isVerified = isVerifiedAccount(after);
    const wasBanned = isBannedAccount(before);
    const isBanned = isBannedAccount(after);

    if (!wasBanned && isBanned) {
      await createAppNotification({
        userId,
        role,
        type: "account_restricted",
        title: "Account restricted",
        body: "Your SakayNow account access has been restricted.",
        channel: "account",
        sourceId: `account_restricted_${userId}`,
        data: {
          user_id: userId,
          role,
        },
        sendPush: true,
      });
      return;
    }

    if (wasBanned && !isBanned) {
      await createAppNotification({
        userId,
        role,
        type: "account_restored",
        title: "Account restored",
        body: "Your SakayNow account access has been restored.",
        channel: "account",
        sourceId: `account_restored_${userId}`,
        data: {
          user_id: userId,
          role,
        },
        sendPush: true,
      });
      return;
    }

    if (!wasVerified && isVerified && !wasBanned && !isBanned) {
      await createAppNotification({
        userId,
        role,
        type: "account_verified",
        title: "Verification approved",
        body: "Your SakayNow account verification has been approved.",
        channel: "account",
        sourceId: `account_verified_${userId}`,
        data: {
          user_id: userId,
          role,
        },
        sendPush: true,
      });
    }
  },
);

export const notifyNewBookingRequest = onDocumentCreated(
  {
    region: "asia-southeast1",
    document: "bookings/{bookingId}",
  },
  async (event) => {
    const bookingSnapshot = event.data;
    if (!bookingSnapshot) {
      return;
    }

    const bookingId = event.params.bookingId;
    const booking = bookingSnapshot.data();
    if (normalizedBookingStatus(booking.status) !== "searching") {
      return;
    }

    const driverIds = await bookingRequestRecipientIds(booking);
    if (driverIds.length === 0) {
      return;
    }

    const pickupLabel = locationLabel(booking.pickup_location, "pickup");
    const dropoffLabel = locationLabel(booking.dropoff_location, "drop-off");
    await Promise.all(driverIds.map((driverId) =>
      createAppNotification({
        userId: driverId,
        role: "driver",
        type: "booking_request",
        title: "New booking request",
        body: `Pickup at ${pickupLabel}. Drop-off: ${dropoffLabel}.`,
        channel: "booking",
        sourceId: `booking_request_${bookingId}_${driverId}`,
        data: {
          booking_id: bookingId,
          passenger_id: readOptionalString(booking.passenger_id) ?? "",
          pickup_label: pickupLabel,
          dropoff_label: dropoffLabel,
        },
        sendPush: true,
      }),
    ));
  },
);

export const notifyBookingStatusChanged = onDocumentUpdated(
  {
    region: "asia-southeast1",
    document: "bookings/{bookingId}",
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const bookingId = event.params.bookingId;
    const before = change.before.data();
    const after = change.after.data();
    const passengerId = readOptionalString(after.passenger_id);
    const driverId = readOptionalString(after.driver_id);
    const previousStatus = normalizedBookingStatus(before.status);
    const currentStatus = normalizedBookingStatus(after.status);
    const notifications: Array<Promise<void>> = [];

    const previousDeclinedDriverId = readOptionalString(
      before.last_declined_driver_id,
    );
    const declinedDriverId = readOptionalString(after.last_declined_driver_id);
    if (
      passengerId &&
      declinedDriverId &&
      declinedDriverId !== previousDeclinedDriverId
    ) {
      notifications.push(createAppNotification({
        userId: passengerId,
        role: "passenger",
        type: "booking_declined",
        title: "Driver declined booking",
        body: "A driver declined your request. We are still looking for one.",
        channel: "booking",
        sourceId: `booking_declined_${bookingId}_${declinedDriverId}`,
        data: {
          booking_id: bookingId,
          driver_id: declinedDriverId,
        },
        sendPush: true,
      }));
    }

    if (previousStatus === currentStatus) {
      await Promise.all(notifications);
      return;
    }

    if (currentStatus === "cancelled") {
      notifications.push(
        ...bookingCancellationNotifications({
          bookingId,
          booking: after,
          passengerId,
          driverId,
        }),
      );
      await Promise.all(notifications);
      return;
    }

    const statusCopy = bookingStatusNotificationCopy(currentStatus);
    if (statusCopy && passengerId) {
      notifications.push(createAppNotification({
        userId: passengerId,
        role: "passenger",
        type: statusCopy.type,
        title: statusCopy.title,
        body: statusCopy.passengerBody,
        channel: "booking",
        sourceId: `${statusCopy.type}_${bookingId}_${passengerId}`,
        data: {
          booking_id: bookingId,
          driver_id: driverId ?? "",
          status: currentStatus,
        },
        sendPush: true,
      }));
    }

    if (currentStatus === "completed" && driverId) {
      notifications.push(createAppNotification({
        userId: driverId,
        role: "driver",
        type: "ride_completed",
        title: "Ride completed",
        body: "The ride has been marked completed.",
        channel: "booking",
        sourceId: `ride_completed_${bookingId}_${driverId}`,
        data: {
          booking_id: bookingId,
          passenger_id: passengerId ?? "",
          status: currentStatus,
        },
        sendPush: true,
      }));
    }

    await Promise.all(notifications);
  },
);

export const notifyReviewReceived = onDocumentCreated(
  {
    region: "asia-southeast1",
    document: "reviews/{reviewId}",
  },
  async (event) => {
    const reviewSnapshot = event.data;
    if (!reviewSnapshot) {
      return;
    }

    const review = reviewSnapshot.data();
    const revieweeId = readOptionalString(review.reviewee_id);
    if (!revieweeId) {
      return;
    }

    const revieweeRole = readOptionalString(review.reviewee_role) ??
      "passenger";
    const rating = readNumber(review.rating);
    const ratingLabel = rating === undefined ?
      "new" :
      `${Math.round(rating)}-star`;

    await createAppNotification({
      userId: revieweeId,
      role: revieweeRole,
      type: "review_received",
      title: "New review received",
      body: `You received a ${ratingLabel} review.`,
      channel: "review",
      sourceId: `review_received_${event.params.reviewId}_${revieweeId}`,
      data: {
        review_id: event.params.reviewId,
        booking_id: readOptionalString(review.booking_id) ?? "",
        reviewer_id: readOptionalString(review.reviewer_id) ?? "",
        reviewer_role: readOptionalString(review.reviewer_role) ?? "",
        rating: rating?.toString() ?? "",
      },
      sendPush: false,
    });
  },
);

async function createAppNotification(params: AppNotificationParams) {
  const notificationId = notificationDocumentId(params);
  const notificationRef = firestore
    .collection("notifications")
    .doc(notificationId);
  const existing = await notificationRef.get();
  if (existing.exists) {
    return;
  }

  const data = notificationData({
    ...params.data,
    notification_id: notificationId,
    type: params.type,
    channel: params.channel,
    title: params.title,
    body: params.body,
  });

  await notificationRef.set({
    notification_id: notificationId,
    user_id: params.userId,
    role: params.role ?? "",
    type: params.type,
    title: params.title,
    body: params.body,
    channel: params.channel,
    source_id: params.sourceId,
    data,
    is_read: false,
    push_sent: false,
    created_at: FieldValue.serverTimestamp(),
    read_at: null,
  });

  if (params.sendPush === false) {
    return;
  }

  const pushSent = await sendPushToUser({
    userId: params.userId,
    title: params.title,
    body: params.body,
    channel: params.channel,
    data,
  });

  if (pushSent) {
    await notificationRef.set(
      {
        push_sent: true,
        push_sent_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
}

async function sendPushToUser(params: {
  userId: string;
  title: string;
  body: string;
  channel: AppNotificationChannel;
  data: Record<string, string>;
}) {
  const targets = await notificationTargetsForUsers(
    [params.userId],
    params.channel,
  );
  if (targets.length === 0) {
    return false;
  }

  const tokens = targets.map((target) => target.token);
  let successCount = 0;
  for (const tokenChunk of chunk(tokens, 500)) {
    const response = await messaging.sendEachForMulticast({
      tokens: tokenChunk,
      notification: {
        title: params.title,
        body: params.body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: notificationChannelId(params.channel),
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
      data: params.data,
    });

    successCount += response.successCount;
    await removeInvalidTokens({
      response,
      tokenChunk,
      targets,
    });
  }

  return successCount > 0;
}

async function notifyAdmins(params: Omit<AppNotificationParams, "userId">) {
  const snapshot = await firestore
    .collection("users")
    .where("role", "==", "admin")
    .get();

  await Promise.all(snapshot.docs.map((doc) =>
    createAppNotification({
      ...params,
      userId: doc.id,
      role: "admin",
    }),
  ));
}

function notificationDocumentId(params: AppNotificationParams) {
  return `${params.type}_${params.sourceId}_${params.userId}`
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .substring(0, 480);
}

function notificationData(value: Record<string, unknown>) {
  return Object.entries(value).reduce<Record<string, string>>(
    (data, [key, entry]) => {
      const text = entry?.toString().trim() ?? "";
      data[key] = text;
      return data;
    },
    {},
  );
}

function notificationChannelId(channel: AppNotificationChannel) {
  switch (channel) {
    case "account":
      return "sakaynow_account";
    case "booking":
      return "sakaynow_bookings";
    case "message":
      return "sakaynow_messages";
    case "review":
      return "sakaynow_system";
    case "system":
      return "sakaynow_system";
  }
}

async function bookingRequestRecipientIds(booking: Record<string, unknown>) {
  const preferredDriverId = readOptionalString(booking.preferred_driver_id);
  if (preferredDriverId) {
    return await isEligibleDriver(preferredDriverId) ?
      [preferredDriverId] :
      [];
  }

  const locationSnapshot = await firestore
    .collection("driver_locations")
    .where("is_available", "==", true)
    .get();
  const candidates = locationSnapshot.docs
    .filter((doc) => isFreshDriverLocation(doc.data()))
    .map((doc) => readOptionalString(doc.data().driver_id) ?? doc.id);
  const uniqueCandidates = [...new Set(candidates)];
  const eligibility = await Promise.all(uniqueCandidates.map(async (driverId) =>
    await isEligibleDriver(driverId) ? driverId : undefined,
  ));

  return eligibility.filter((driverId): driverId is string => Boolean(driverId));
}

async function isEligibleDriver(driverId: string) {
  const driverSnapshot = await firestore.collection("users").doc(driverId).get();
  const driver = driverSnapshot.data() ?? {};
  return driverSnapshot.exists &&
    normalizedUserRole(driver) === "driver" &&
    isVerifiedAccount(driver) &&
    !isBannedAccount(driver);
}

function isFreshDriverLocation(data: Record<string, unknown>) {
  const updatedAtMillis = timestampMillis(data.updated_at);
  if (updatedAtMillis === undefined) {
    return false;
  }

  return Date.now() - updatedAtMillis <= 15 * 60 * 1000;
}

function timestampMillis(value: unknown) {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  return undefined;
}

function bookingCancellationNotifications(params: {
  bookingId: string;
  booking: Record<string, unknown>;
  passengerId?: string;
  driverId?: string;
}) {
  const cancelledBy = bookingCancellationActor(params.booking);
  const passengerCancelled =
    params.passengerId !== undefined && cancelledBy === params.passengerId;
  const driverCancelled =
    params.driverId !== undefined && cancelledBy === params.driverId;
  const unassignedCancellationWithoutActor = !params.driverId && !cancelledBy;
  const notifications: Array<Promise<void>> = [];

  if (
    params.passengerId &&
    !passengerCancelled &&
    !unassignedCancellationWithoutActor
  ) {
    notifications.push(createAppNotification({
      userId: params.passengerId,
      role: "passenger",
      type: "booking_cancelled",
      title: "Booking cancelled",
      body: driverCancelled ?
        "Your driver cancelled this booking." :
        "Your booking was cancelled.",
      channel: "booking",
      sourceId:
        `booking_cancelled_${params.bookingId}_${cancelledBy ?? "system"}`,
      data: {
        booking_id: params.bookingId,
        cancelled_by: cancelledBy ?? "",
        status: "cancelled",
      },
      sendPush: true,
    }));
  }

  if (params.driverId && !driverCancelled) {
    notifications.push(createAppNotification({
      userId: params.driverId,
      role: "driver",
      type: "booking_cancelled",
      title: "Booking cancelled",
      body: passengerCancelled ?
        "The passenger cancelled this booking." :
        "This booking was cancelled.",
      channel: "booking",
      sourceId:
        `booking_cancelled_${params.bookingId}_${cancelledBy ?? "system"}`,
      data: {
        booking_id: params.bookingId,
        cancelled_by: cancelledBy ?? "",
        status: "cancelled",
      },
      sendPush: true,
    }));
  }

  return notifications;
}

function bookingCancellationActor(booking: Record<string, unknown>) {
  const explicitActor = readOptionalString(booking.cancelled_by);
  if (explicitActor) {
    return explicitActor;
  }

  const history = booking.status_history;
  if (!Array.isArray(history)) {
    return undefined;
  }

  for (let index = history.length - 1; index >= 0; index -= 1) {
    const entry = readMap(history[index]);
    if (normalizedBookingStatus(entry.status) === "cancelled") {
      return readOptionalString(entry.changed_by);
    }
  }

  return undefined;
}

function bookingStatusNotificationCopy(status: string) {
  switch (status) {
    case "accepted":
      return {
        type: "booking_accepted",
        title: "Booking accepted",
        passengerBody: "A driver accepted your booking.",
      };
    case "driver_arriving":
      return {
        type: "driver_arriving",
        title: "Driver on the way",
        passengerBody: "Your driver is on the way to your pickup point.",
      };
    case "arrived":
      return {
        type: "driver_arrived",
        title: "Driver arrived",
        passengerBody: "Your driver has arrived at the pickup point.",
      };
    case "in_progress":
      return {
        type: "ride_started",
        title: "Ride started",
        passengerBody: "Your ride is now in progress.",
      };
    case "completed":
      return {
        type: "ride_completed",
        title: "Ride completed",
        passengerBody: "Your ride has been completed.",
      };
    default:
      return undefined;
  }
}

function normalizedBookingStatus(value: unknown) {
  const normalized = readOptionalString(value)?.toLowerCase()
    .replace(/[-\s]+/g, "_");

  switch (normalized) {
    case "accepted":
    case "assigned":
      return "accepted";
    case "driver_arriving":
      return "driver_arriving";
    case "arrived":
      return "arrived";
    case "in_progress":
    case "ongoing":
      return "in_progress";
    case "completed":
      return "completed";
    case "cancelled":
    case "canceled":
    case "rejected":
      return "cancelled";
    case "searching":
    case "pending":
    case "queued":
    case "new":
    default:
      return "searching";
  }
}

function normalizedUserRole(data: Record<string, unknown>) {
  const role = readOptionalString(data.role)?.toLowerCase() ?? "passenger";
  if (role === "regular" || role === "student") {
    return "passenger";
  }

  if (role === "driver" || role === "admin") {
    return role;
  }

  return "passenger";
}

function isVerifiedAccount(data: Record<string, unknown>) {
  return isTruthy(data.is_verified) ||
    isTruthy(data.isVerified) ||
    isTruthy(data.isVerrified);
}

function isBannedAccount(data: Record<string, unknown>) {
  return isTruthy(data.is_banned) || isTruthy(data.isBanned);
}

function isTruthy(value: unknown) {
  return value === true || value?.toString().toLowerCase() === "true";
}

function locationLabel(value: unknown, fallback: string) {
  const data = readMap(value);
  const candidates = [
    data.name,
    data.address,
    data.display_label,
    data.formatted_address,
    data.label,
  ];

  for (const candidate of candidates) {
    const label = readOptionalString(candidate);
    if (label && label !== "Pinned location") {
      return label;
    }
  }

  return fallback;
}

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

async function createXenditInvoice(params: {
  secretKey: string;
  bookingId: string;
  passengerName: string;
  passengerEmail?: string;
  amount: number;
  paymentMethodType: string;
  description: string;
}): Promise<XenditInvoiceResponse> {
  const encodedKey = Buffer.from(`${params.secretKey}:`).toString("base64");
  const response = await fetch(`${xenditApiBaseUrl}/v2/invoices`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${encodedKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      external_id: params.bookingId,
      amount: params.amount,
      currency: "PHP",
      description: params.description,
      payer_email: params.passengerEmail,
      customer: {
        given_names: params.passengerName,
        email: params.passengerEmail,
      },
      payment_methods: [params.paymentMethodType],
      success_redirect_url: checkoutSuccessUrl,
      failure_redirect_url: checkoutCancelUrl,
    }),
  });

  const invoice = await response.json() as XenditInvoiceResponse;
  if (!response.ok) {
    throw new HttpsError(
      "internal",
      invoice.message ?? invoice.error_code ?? response.statusText,
    );
  }

  return invoice;
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

async function markXenditInvoicePaid(invoice: {
  invoiceId?: string;
  externalId?: string;
  status?: string;
  paymentId?: string;
  paymentMethod?: string;
  paidAt?: Timestamp;
}) {
  const bookingId = invoice.externalId ??
    await bookingIdForXenditInvoice(invoice.invoiceId);
  if (!bookingId) {
    return;
  }

  const bookingRef = firestore.collection("bookings").doc(bookingId);
  const bookingSnapshot = await bookingRef.get();
  const bookingData = bookingSnapshot.data() ?? {};
  if (!bookingSnapshot.exists) {
    return;
  }

  const driverId = readOptionalString(bookingData.driver_id);

  await bookingRef.set(
    {
      payment_status: "paid",
      payment_reference: invoice.paymentId ?? invoice.invoiceId,
      xendit_invoice_id: invoice.invoiceId,
      xendit_invoice_status: invoice.status,
      ...(invoice.paymentId ? {xendit_payment_id: invoice.paymentId} : {}),
      ...(invoice.paymentMethod ?
        {payment_method_used: invoice.paymentMethod} :
        {}),
      driver_payout_status: driverId ? "pending" : "awaiting_driver",
      ...(invoice.paidAt ? {paid_at: invoice.paidAt} : {}),
      payment_confirmed_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function markXenditInvoiceFailed(invoice: {
  invoiceId?: string;
  externalId?: string;
  status?: string;
}) {
  const bookingId = invoice.externalId ??
    await bookingIdForXenditInvoice(invoice.invoiceId);
  if (!bookingId) {
    return;
  }

  const bookingRef = firestore.collection("bookings").doc(bookingId);
  const bookingSnapshot = await bookingRef.get();
  if (!bookingSnapshot.exists) {
    return;
  }

  await bookingRef.set(
    {
      payment_status: "checkout_failed",
      xendit_invoice_id: invoice.invoiceId,
      xendit_invoice_status: invoice.status,
      updated_at: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

function xenditInvoiceDataFromWebhook(body: unknown): {
  invoiceId?: string;
  externalId?: string;
  status?: string;
  paymentId?: string;
  paymentMethod?: string;
  paidAt?: Timestamp;
} {
  const data = readMap(body);
  const nestedData = readMap(data.data);
  const invoice = Object.keys(nestedData).length > 0 ? nestedData : data;
  const paidAt = readOptionalString(
    invoice.paid_at ?? invoice.paidAt ?? invoice.updated,
  );

  return {
    invoiceId: readOptionalString(invoice.id ?? invoice.invoice_id),
    externalId: readOptionalString(
      invoice.external_id ?? invoice.externalId ?? invoice.reference_id,
    ),
    status: readOptionalString(invoice.status)?.toUpperCase(),
    paymentId: readOptionalString(
      invoice.payment_id ?? invoice.paymentId ?? invoice.payment_request_id,
    ),
    paymentMethod: readOptionalString(
      invoice.payment_method ??
        invoice.paymentMethod ??
        invoice.payment_channel,
    ),
    paidAt: paidAt ? timestampFromDateString(paidAt) : undefined,
  };
}

async function bookingIdForXenditInvoice(invoiceId?: string) {
  if (!invoiceId) {
    return undefined;
  }

  const snapshot = await firestore
    .collection("bookings")
    .where("xendit_invoice_id", "==", invoiceId)
    .limit(1)
    .get();
  return snapshot.docs[0]?.id;
}

function isValidXenditCallbackToken(actual: string, expected: string) {
  if (!actual || !expected) {
    return false;
  }

  const actualBuffer = Buffer.from(actual);
  const expectedBuffer = Buffer.from(expected);
  return actualBuffer.length === expectedBuffer.length &&
    timingSafeEqual(actualBuffer, expectedBuffer);
}

function timestampFromDateString(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ?
    undefined :
    Timestamp.fromDate(date);
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

async function notificationTargetsForUsers(
  userIds: string[],
  channel: AppNotificationChannel = "system",
) {
  const uniqueUserIds = [...new Set(userIds)];
  const targets: TokenTarget[] = [];

  for (const userId of uniqueUserIds) {
    const userRef = firestore.collection("users").doc(userId);
    const userSnapshot = await userRef.get();
    if (!notificationPreferencesAllow(userSnapshot.data() ?? {}, channel)) {
      continue;
    }

    const snapshot = await userRef
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

function notificationPreferencesAllow(
  user: Record<string, unknown>,
  channel: AppNotificationChannel,
) {
  const preferences = readMap(user.notification_preferences);
  if (!readOptionalBool(preferences.push_enabled, true)) {
    return false;
  }

  switch (channel) {
    case "booking":
      return readOptionalBool(preferences.booking_updates_enabled, true);
    case "message":
      return readOptionalBool(preferences.message_updates_enabled, true);
    case "account":
      return readOptionalBool(preferences.account_updates_enabled, true);
    case "review":
    case "system":
      return readOptionalBool(preferences.system_updates_enabled, true);
  }
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

function readOptionalBool(value: unknown, fallback: boolean) {
  if (typeof value === "boolean") {
    return value;
  }

  const text = readOptionalString(value)?.toLowerCase();
  if (text === "true") {
    return true;
  }

  if (text === "false") {
    return false;
  }

  return fallback;
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
  if (value === "PAYMAYA") {
    return "maya";
  }

  if (value === "CREDIT_CARD") {
    return "card";
  }

  if (value === "GCASH") {
    return "gcash";
  }

  if (value === "paymaya") {
    return "maya";
  }

  return value;
}

function normalizeXenditPaymentMethod(value: string) {
  const normalized = value.trim().toUpperCase();
  if (normalized === "MAYA" || normalized === "PAYMAYA") {
    return "PAYMAYA";
  }

  if (normalized === "CARD" || normalized === "CREDIT_CARD") {
    return "CREDIT_CARD";
  }

  return normalized;
}
