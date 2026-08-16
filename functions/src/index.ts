import {createHmac, timingSafeEqual} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type Query,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  canonicalRideConversationId,
  selectMostRecentRideConversation,
} from "./chat_conversations";

initializeApp();

const firestore = getFirestore();
const auth = getAuth();
const messaging = getMessaging();
const storage = getStorage();
const paymongoSecretKey = defineSecret("PAYMONGO_SECRET_KEY");
const paymongoWebhookSecret = defineSecret("PAYMONGO_WEBHOOK_SECRET");
const xenditSecretKey = defineSecret("XENDIT_SECRET_KEY");
const xenditWebhookToken = defineSecret("XENDIT_WEBHOOK_TOKEN");
const paymongoApiBaseUrl = "https://api.paymongo.com/v1";
const xenditApiBaseUrl = "https://api.xendit.co";
const checkoutSuccessUrl = process.env.XENDIT_SUCCESS_URL ??
  "https://sakaynow-buenatoda.web.app/payment/success";
const checkoutCancelUrl = process.env.XENDIT_FAILURE_URL ??
  process.env.XENDIT_CANCEL_URL ??
  "https://sakaynow-buenatoda.web.app/payment/cancelled";
const checkoutAllowedMethods = new Set(["gcash", "paymaya", "card"]);
const xenditAllowedMethods = new Set(["GCASH", "PAYMAYA", "CREDIT_CARD"]);
const regularMinimumRideFare = 25;
const minimumStudentDiscountedFare = 21;
const maximumRideFare = 100;
const regularPassengerDiscountRate = 0;
const studentDiscountRate = 0.15;
const seniorCitizenDiscountRate = 0.15;
const defaultMaxDriverPickupSurcharge = 10;
const regularPassengerDiscountCode = "regular_passenger";
const studentDiscountCode = "verified_student";
const seniorCitizenDiscountCode = "verified_senior_citizen";
const fareSettingsCollection = "fare_settings";
const currentFareSettingsDocument = "current";
const adminLogsCollection = "admin_logs";
const driverRatingPriorAverage = 4.0;
const driverRatingMinimumReviews = 20;
const driverLeaderboardLimit = 20;
const risingDriverAverage = 4.7;
const deactivationRestoreWindowDays = 60;
const transactionRetentionYears = 5;
const scheduledCleanupLimit = 250;
const driverDocumentExpiryWarningDays = 30;

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

type RevieweeTarget = {
  id: string;
  role: "driver" | "passenger";
};

type FareValidationSettings = {
  regularMinimumRideFare: number;
  minimumDiscountedFare: number;
  maximumRideFare: number;
  regularPassengerDiscountRate: number;
  studentDiscountRate: number;
  seniorCitizenDiscountRate: number;
};

type AdminLogParams = {
  logDocumentId?: string;
  action: string;
  adminId: string;
  adminName?: string;
  summary: string;
  targetId?: string;
  targetName?: string;
  targetRole?: string;
  metadata?: Record<string, unknown>;
};

const defaultFareValidationSettings: FareValidationSettings = {
  regularMinimumRideFare,
  minimumDiscountedFare: minimumStudentDiscountedFare,
  maximumRideFare: maximumRideFare + defaultMaxDriverPickupSurcharge,
  regularPassengerDiscountRate,
  studentDiscountRate,
  seniorCitizenDiscountRate,
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
    const existingCheckoutUrl =
      readOptionalString(booking.xendit_checkout_url) ??
      readOptionalString(booking.checkout_url);
    const paymentStatus = readOptionalString(booking.payment_status);
    if (
      existingInvoiceId &&
      existingCheckoutUrl &&
      paymentStatus !== "checkout_failed"
    ) {
      await bookingRef.set(
        {
          xendit_checkout_url: existingCheckoutUrl,
          checkout_url: existingCheckoutUrl,
          payment_method_type: paymentMethodType,
          payment_provider: "xendit",
          updated_at: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {
        session_id: existingInvoiceId,
        checkout_url: existingCheckoutUrl,
        payment_status: paymentStatus ?? "checkout_pending",
      };
    }

    const passenger = await firestore.collection("users").doc(uid).get();
    const passengerData = passenger.data() ?? {};
    const amount = readFareAmount(booking);
    const fareSettings = await loadFareValidationSettings();
    if (!isAllowedFareAmount({amount, booking, passengerData, fareSettings})) {
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
        checkout_url: checkoutUrl,
        xendit_invoice_status: invoice.status ?? "PENDING",
        payment_status: "checkout_pending",
        payment_method: methodLabelForStorage(paymentMethodType),
        payment_method_type: paymentMethodType,
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
    const fareSettings = await loadFareValidationSettings();
    if (!isAllowedFareAmount({amount, booking, passengerData, fareSettings})) {
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

export const createAdminAccount = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in as the super admin to create admin accounts.",
      );
    }

    const requesterSnapshot = await firestore
      .collection("users")
      .doc(requesterId)
      .get();
    const requester = requesterSnapshot.data();
    if (!requesterSnapshot.exists || !requester || !isSuperAdmin(requester)) {
      throw new HttpsError(
        "permission-denied",
        "Only the super admin account can create admin accounts.",
      );
    }

    const email = readRequiredString(request.data, "email").toLowerCase();
    const password = readRequiredString(request.data, "password");
    const firstName = readRequiredString(request.data, "first_name");
    const lastName = readRequiredString(request.data, "last_name");
    const rawAge = readRequiredString(request.data, "age");
    const gender = readRequiredString(request.data, "gender").toLowerCase();
    const age = Number.parseInt(rawAge, 10);

    validateAdminAccountInput({
      email,
      password,
      firstName,
      lastName,
      age,
      gender,
    });

    let createdUserId: string | undefined;
    try {
      const createdUser = await auth.createUser({
        email,
        password,
        displayName: `${firstName} ${lastName}`.trim(),
        disabled: false,
      });
      createdUserId = createdUser.uid;

      await firestore.collection("users").doc(createdUser.uid).set({
        user_id: createdUser.uid,
        email,
        first_name: firstName,
        last_name: lastName,
        role: "admin",
        age,
        gender,
        is_verified: true,
        is_active: true,
        is_banned: false,
        is_deactivated: false,
        account_status: "active",
        created_by: requesterId,
        created_at: FieldValue.serverTimestamp(),
        reviewed_by: requesterId,
        reviewed_at: FieldValue.serverTimestamp(),
      });

      await writeAdminLog({
        action: "admin_account_created",
        adminId: requesterId,
        adminName: fullName(requester),
        summary: `${fullName(requester)} created admin account ${
          `${firstName} ${lastName}`.trim()
        }.`,
        targetId: createdUser.uid,
        targetName: `${firstName} ${lastName}`.trim(),
        targetRole: "admin",
        metadata: {email},
      });

      return {user_id: createdUser.uid};
    } catch (error) {
      if (createdUserId) {
        await auth.deleteUser(createdUserId).catch(() => undefined);
      }

      const code = (error as {code?: string}).code;
      if (code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "That email is already used.");
      }

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        (error as {message?: string}).message ??
          "Unable to create admin account.",
      );
    }
  },
);

export const deactivateAdminAccount = onCall(
  {
    region: "asia-southeast1",
    cpu: "gcf_gen1",
    invoker: "public",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in as the super admin to deactivate admin accounts.",
      );
    }

    const requesterSnapshot = await firestore
      .collection("users")
      .doc(requesterId)
      .get();
    const requester = requesterSnapshot.data();
    if (!requesterSnapshot.exists || !requester || !isSuperAdmin(requester)) {
      throw new HttpsError(
        "permission-denied",
        "Only the active super admin account can deactivate admin accounts.",
      );
    }

    const adminUserId = readRequiredString(request.data, "admin_user_id");
    if (adminUserId === requesterId) {
      throw new HttpsError(
        "failed-precondition",
        "The super admin account cannot be deactivated.",
      );
    }

    const targetRef = firestore.collection("users").doc(adminUserId);
    const targetSnapshot = await targetRef.get();
    const target = targetSnapshot.data();
    if (!targetSnapshot.exists || !target) {
      throw new HttpsError("not-found", "Admin account was not found.");
    }

    if (normalizedUserRole(target) !== "admin") {
      throw new HttpsError(
        "invalid-argument",
        "Only admin accounts can be deactivated here.",
      );
    }

    if (isDeletedAccount(target)) {
      throw new HttpsError(
        "failed-precondition",
        "Deleted admin accounts cannot be deactivated.",
      );
    }

    const targetName = fullName(target);
    if (!isDeactivatedAccount(target)) {
      await targetRef.set(
        {
          is_active: false,
          is_deactivated: true,
          account_status: "deactivated",
          deactivated_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
          deactivated_by: requesterId,
        },
        {merge: true},
      );
    }

    await writeAdminLog({
      action: "admin_account_deactivated",
      adminId: requesterId,
      adminName: fullName(requester),
      summary: `${targetName} admin account was deactivated.`,
      targetId: adminUserId,
      targetName,
      targetRole: "admin",
      metadata: {admin_user_id: adminUserId},
    });

    return {admin_user_id: adminUserId};
  },
);

export const restoreAdminAccount = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in as the super admin to restore admin accounts.",
      );
    }

    const requesterSnapshot = await firestore
      .collection("users")
      .doc(requesterId)
      .get();
    const requester = requesterSnapshot.data();
    if (!requesterSnapshot.exists || !requester || !isSuperAdmin(requester)) {
      throw new HttpsError(
        "permission-denied",
        "Only the active super admin account can restore admin accounts.",
      );
    }

    const adminUserId = readRequiredString(request.data, "admin_user_id");
    if (adminUserId === requesterId) {
      throw new HttpsError(
        "failed-precondition",
        "The super admin account does not need restoration.",
      );
    }

    const targetRef = firestore.collection("users").doc(adminUserId);
    const targetSnapshot = await targetRef.get();
    const target = targetSnapshot.data();
    if (!targetSnapshot.exists || !target) {
      throw new HttpsError("not-found", "Admin account was not found.");
    }

    if (normalizedUserRole(target) !== "admin") {
      throw new HttpsError(
        "invalid-argument",
        "Only admin accounts can be restored here.",
      );
    }

    if (isDeletedAccount(target)) {
      throw new HttpsError(
        "failed-precondition",
        "Deleted admin accounts cannot be restored.",
      );
    }

    const targetName = fullName(target);
    if (isDeactivatedAccount(target) || !readOptionalBool(target.is_active, true)) {
      await targetRef.set(
        {
          is_active: true,
          is_deactivated: false,
          account_status: "active",
          deactivated_at: FieldValue.delete(),
          deactivated_by: FieldValue.delete(),
          restored_at: FieldValue.serverTimestamp(),
          restored_by: requesterId,
          updated_at: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }

    await writeAdminLog({
      action: "admin_account_restored",
      adminId: requesterId,
      adminName: fullName(requester),
      summary: `${targetName} admin account was restored.`,
      targetId: adminUserId,
      targetName,
      targetRole: "admin",
      metadata: {admin_user_id: adminUserId},
    });

    return {admin_user_id: adminUserId};
  },
);

export const ensureAdminDirectConversation = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in with an admin account to start this conversation.",
      );
    }

    const targetAdminId = readRequiredString(request.data, "target_admin_id");
    if (targetAdminId === requesterId) {
      throw new HttpsError("invalid-argument", "Choose another admin to message.");
    }

    const [requesterSnapshot, targetSnapshot] = await Promise.all([
      firestore.collection("users").doc(requesterId).get(),
      firestore.collection("users").doc(targetAdminId).get(),
    ]);
    const requester = requesterSnapshot.data();
    const target = targetSnapshot.data();
    if (!requesterSnapshot.exists || !requester || !isAdminStaff(requester)) {
      throw new HttpsError(
        "permission-denied",
        "Only active admin staff can start admin conversations.",
      );
    }
    if (!targetSnapshot.exists || !target || !isAdminStaff(target)) {
      throw new HttpsError(
        "failed-precondition",
        "The selected admin account is not active.",
      );
    }

    const participantIds = [requesterId, targetAdminId].sort();
    const conversationId = `admin_direct_${participantIds[0]}_${participantIds[1]}`;
    const conversationRef = firestore
      .collection("conversations")
      .doc(conversationId);
    const conversationSnapshot = await conversationRef.get();
    if (conversationSnapshot.exists) {
      const existing = conversationSnapshot.data() ?? {};
      const existingParticipantIds = readStringArray(existing.participant_ids)
        .sort();
      if (
        readOptionalString(existing.type) !== "admin_direct" ||
        existingParticipantIds.length !== 2 ||
        existingParticipantIds[0] !== participantIds[0] ||
        existingParticipantIds[1] !== participantIds[1]
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The admin conversation ID conflicts with an existing record.",
        );
      }
    }
    const participantNames: Record<string, string> = {
      [requesterId]: fullName(requester),
      [targetAdminId]: fullName(target),
    };
    const participantRoles: Record<string, string> = {
      [requesterId]: normalizedUserRole(requester),
      [targetAdminId]: normalizedUserRole(target),
    };

    await conversationRef.set(
      {
        conversation_id: conversationId,
        type: "admin_direct",
        participant_ids: participantIds,
        participant_names: participantNames,
        participant_roles: participantRoles,
        ...(conversationSnapshot.exists ? {} : {
          created_at: FieldValue.serverTimestamp(),
        }),
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {conversation_id: conversationId};
  },
);

export const ensureRideConversation = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to start this ride conversation.",
      );
    }

    const bookingId = readRequiredString(request.data, "booking_id");
    const bookingSnapshot = await firestore
      .collection("bookings")
      .doc(bookingId)
      .get();
    const booking = bookingSnapshot.data();
    if (!bookingSnapshot.exists || !booking) {
      throw new HttpsError("not-found", "The selected booking was not found.");
    }

    const passengerId = readOptionalString(booking.passenger_id);
    const driverId = readOptionalString(booking.driver_id);
    if (!passengerId || !driverId) {
      throw new HttpsError(
        "failed-precondition",
        "This booking does not have an assigned passenger and driver.",
      );
    }
    if (requesterId !== passengerId && requesterId !== driverId) {
      throw new HttpsError(
        "permission-denied",
        "You are not part of this ride.",
      );
    }

    const [passengerSnapshot, driverSnapshot, conversationSnapshot] =
      await Promise.all([
        firestore.collection("users").doc(passengerId).get(),
        firestore.collection("users").doc(driverId).get(),
        firestore
          .collection("conversations")
          .where("passenger_id", "==", passengerId)
          .where("driver_id", "==", driverId)
          .get(),
      ]);
    const candidates = conversationSnapshot.docs
      .filter((document) => {
        const data = document.data();
        const participantIds = readStringArray(data.participant_ids);
        return readOptionalString(data.type) === "ride" &&
          participantIds.length === 2 &&
          participantIds.includes(passengerId) &&
          participantIds.includes(driverId);
      })
      .map((document) => ({
        id: document.id,
        activityAtMillis: conversationActivityMillis(document.data()),
      }));
    const selected = selectMostRecentRideConversation(candidates);
    const conversationId = selected?.id ??
      canonicalRideConversationId(passengerId, driverId);
    const conversationRef = firestore
      .collection("conversations")
      .doc(conversationId);
    const passenger = passengerSnapshot.data() ?? {};
    const driver = driverSnapshot.data() ?? {};

    await firestore.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(conversationRef);
      if (currentSnapshot.exists) {
        const current = currentSnapshot.data() ?? {};
        const currentParticipantIds = readStringArray(current.participant_ids);
        if (
          readOptionalString(current.type) !== "ride" ||
          currentParticipantIds.length !== 2 ||
          !currentParticipantIds.includes(passengerId) ||
          !currentParticipantIds.includes(driverId)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The ride conversation ID conflicts with an existing record.",
          );
        }
      }

      transaction.set(
        conversationRef,
        {
          conversation_id: conversationId,
          type: "ride",
          booking_id: bookingId,
          booking_ids: FieldValue.arrayUnion(bookingId),
          passenger_id: passengerId,
          driver_id: driverId,
          participant_ids: [passengerId, driverId],
          participant_names: {
            [passengerId]: rideParticipantName(passenger, "Passenger"),
            [driverId]: rideParticipantName(driver, "Driver"),
          },
          participant_roles: {
            [passengerId]: "passenger",
            [driverId]: "driver",
          },
          ...(currentSnapshot.exists ? {} : {
            created_at: FieldValue.serverTimestamp(),
          }),
          updated_at: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    return {conversation_id: conversationId};
  },
);

export const unsendChatMessage = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError("unauthenticated", "Sign in to unsend a message.");
    }

    const conversationId = readRequiredString(
      request.data,
      "conversation_id",
    );
    const messageId = readRequiredString(request.data, "message_id");
    const conversationRef = firestore
      .collection("conversations")
      .doc(conversationId);
    const messageRef = conversationRef.collection("messages").doc(messageId);
    const requesterSnapshot = await firestore
      .collection("users")
      .doc(requesterId)
      .get();
    const requester = requesterSnapshot.data();

    await firestore.runTransaction(async (transaction) => {
      const [conversationSnapshot, messageSnapshot] = await Promise.all([
        transaction.get(conversationRef),
        transaction.get(messageRef),
      ]);
      const conversation = conversationSnapshot.data();
      const message = messageSnapshot.data();
      if (!conversationSnapshot.exists || !conversation) {
        throw new HttpsError("not-found", "Conversation was not found.");
      }
      if (!messageSnapshot.exists || !message) {
        throw new HttpsError("not-found", "Message was not found.");
      }
      if (!canAccessChatConversation(conversation, requesterId, requester)) {
        throw new HttpsError(
          "permission-denied",
          "You do not have access to this conversation.",
        );
      }
      if (readOptionalString(message.sender_id) !== requesterId) {
        throw new HttpsError(
          "permission-denied",
          "You can only unsend your own messages.",
        );
      }

      if (readOptionalString(message.type) === "unsent") {
        return;
      }

      transaction.update(messageRef, {
        type: "unsent",
        text: FieldValue.delete(),
        unsent_at: FieldValue.serverTimestamp(),
        unsent_by: requesterId,
      });

      if (isCurrentConversationMessage(conversation, message, messageId)) {
        transaction.update(conversationRef, {
          last_message_text: FieldValue.delete(),
          last_message_id: messageId,
          last_message_type: "unsent",
        });
      }
    });

    return {conversation_id: conversationId, message_id: messageId};
  },
);

export const deleteChatConversationForMe = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    const requesterId = request.auth?.uid;
    if (!requesterId) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to delete this conversation.",
      );
    }

    const conversationId = readRequiredString(
      request.data,
      "conversation_id",
    );
    const conversationRef = firestore
      .collection("conversations")
      .doc(conversationId);
    const requesterSnapshot = await firestore
      .collection("users")
      .doc(requesterId)
      .get();
    const requester = requesterSnapshot.data();

    await firestore.runTransaction(async (transaction) => {
      const conversationSnapshot = await transaction.get(conversationRef);
      const conversation = conversationSnapshot.data();
      if (!conversationSnapshot.exists || !conversation) {
        throw new HttpsError("not-found", "Conversation was not found.");
      }
      if (!canAccessChatConversation(conversation, requesterId, requester)) {
        throw new HttpsError(
          "permission-denied",
          "You do not have access to this conversation.",
        );
      }

      const updates: Record<string, unknown> = {
        [`deleted_at_by.${requesterId}`]: FieldValue.serverTimestamp(),
        [`last_read_at.${requesterId}`]: FieldValue.serverTimestamp(),
      };
      if (readStringArray(conversation.participant_ids).includes(requesterId)) {
        updates[`unread_counts.${requesterId}`] = 0;
      }
      transaction.update(conversationRef, updates);
    });

    return {conversation_id: conversationId};
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
      retention_expires_at: retentionExpiresFromNow(),
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
      retention_expires_at: retentionExpiresFromNow(),
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
    const soundProfile = notificationSoundProfile("chat_message", "message");

    for (const tokenChunk of chunk(tokens, 500)) {
      const response = await messaging.sendEachForMulticast({
        tokens: tokenChunk,
        notification: {title, body},
        android: {
          priority: "high",
          notification: {
            channelId: soundProfile.androidChannelId,
            sound: soundProfile.androidSound,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: soundProfile.appleSound,
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
          notification_sound: soundProfile.key,
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
    if (isAdminStaffRole(role) || isVerifiedAccount(user)) {
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
    if (isAdminStaffRole(role)) {
      return;
    }

    const wasVerified = isVerifiedAccount(before);
    const isVerified = isVerifiedAccount(after);
    const wasBanned = isBannedAccount(before);
    const isBanned = isBannedAccount(after);
    const wasDeactivated = isDeactivatedAccount(before);
    const isDeactivated = isDeactivatedAccount(after);
    const isDeleted = isDeletedAccount(after);

    if (!wasDeactivated && isDeactivated) {
      const deactivatedAt = timestampFromUnknown(after.deactivated_at) ??
        Timestamp.now();
      const restoreDeadline = timestampAfterDays(
        deactivatedAt,
        deactivationRestoreWindowDays,
      );

      await change.after.ref.set(
        {
          deactivation_restore_deadline: restoreDeadline,
          deactivation_purge_after: restoreDeadline,
          restored_at: FieldValue.delete(),
          restored_by: FieldValue.delete(),
          updated_at: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      await createAppNotification({
        userId,
        role,
        type: "account_deactivated",
        title: "Account deactivated",
        body:
          "Your account can be restored by an admin within 60 days.",
        channel: "account",
        sourceId: `account_deactivated_${userId}`,
        data: {
          user_id: userId,
          role,
        },
        sendPush: true,
      });
      return;
    }

    if (wasDeactivated && !isDeactivated && !isDeleted) {
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

export const notifyDriverRenewalSubmitted = onDocumentUpdated(
  {
    region: "asia-southeast1",
    document: "users/{userId}",
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const before = change.before.data();
    const after = change.after.data();
    if (
      normalizedUserRole(after) !== "driver" ||
      readOptionalString(before.renewal_status) === "pending_renewal" ||
      readOptionalString(after.renewal_status) !== "pending_renewal"
    ) {
      return;
    }

    const userId = event.params.userId;
    const documentType = readOptionalString(after.renewal_document_type) ??
      "driver_document";
    await notifyAdmins({
      type: "driver_renewal_submitted",
      title: "Driver renewal submitted",
      body: `${fullName(after)} submitted a ${driverDocumentLabel(
        documentType,
      )} renewal for review.`,
      channel: "system",
      sourceId: `driver_renewal_${userId}_${event.id}`,
      data: {
        user_id: userId,
        role: "driver",
        document_type: documentType,
      },
      sendPush: true,
    });
  },
);

export const notifyDriverRenewalDecision = onDocumentUpdated(
  {
    region: "asia-southeast1",
    cpu: "gcf_gen1",
    document: "users/{userId}",
  },
  async (event) => {
    const change = event.data;
    if (!change) return;
    const before = change.before.data();
    const after = change.after.data();
    const decision = readOptionalString(after.renewal_status);
    if (
      normalizedUserRole(after) !== "driver" ||
      readOptionalString(before.renewal_status) !== "pending_renewal" ||
      (decision !== "approved" && decision !== "rejected")
    ) {
      return;
    }

    const approved = decision === "approved";
    const reason = readOptionalString(after.renewal_rejection_reason);
    await createAppNotification({
      userId: event.params.userId,
      role: "driver",
      type: approved ? "driver_renewal_approved" : "driver_renewal_rejected",
      title: approved ? "Document renewal approved" : "Document renewal rejected",
      body: approved ?
        "Your replacement document was approved. Check your renewal status before going active." :
        `Your replacement document needs changes.${reason ? ` ${reason}` : ""}`,
      channel: "account",
      sourceId: `driver_renewal_decision_${event.params.userId}_${event.id}`,
      data: {
        user_id: event.params.userId,
        role: "driver",
        renewal_status: decision,
      },
      sendPush: true,
    });
  },
);

export const logAdminUserAction = onDocumentUpdated(
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
    if (isAdminStaffRole(role)) {
      return;
    }

    const reviewedBy = readOptionalString(after.reviewed_by);
    const restoredBy = readOptionalString(after.restored_by);
    const targetName = fullName(after);
    const baseLog = {
      logDocumentId: `user_${event.id}`,
      targetId: userId,
      targetName,
      targetRole: role,
      metadata: {user_id: userId},
    };

    if (
      isDeactivatedAccount(before) &&
      !isDeactivatedAccount(after) &&
      !isDeletedAccount(after) &&
      restoredBy
    ) {
      await writeAdminLog({
        ...baseLog,
        action: "deactivated_user_restored",
        adminId: restoredBy,
        summary: `${targetName} was restored from deactivation.`,
      });
      return;
    }

    if (!isBannedAccount(before) && isBannedAccount(after) && reviewedBy) {
      await writeAdminLog({
        ...baseLog,
        action: "user_restricted",
        adminId: reviewedBy,
        summary: `${targetName} was restricted.`,
      });
      return;
    }

    if (isBannedAccount(before) && !isBannedAccount(after) && reviewedBy) {
      await writeAdminLog({
        ...baseLog,
        action: "user_restored",
        adminId: reviewedBy,
        summary: `${targetName} was restored after restriction.`,
      });
      return;
    }

    if (
      !isVerifiedAccount(before) &&
      isVerifiedAccount(after) &&
      reviewedBy
    ) {
      await writeAdminLog({
        ...baseLog,
        action: "user_approved",
        adminId: reviewedBy,
        summary: `${targetName} was verified.`,
      });
    }
  },
);

export const stampBookingRetention = onDocumentWritten(
  {
    region: "asia-southeast1",
    document: "bookings/{bookingId}",
  },
  async (event) => {
    const snapshot = event.data?.after;
    if (!snapshot?.exists) {
      return;
    }

    const booking = snapshot.data() ?? {};
    if (timestampFromUnknown(booking.retention_expires_at)) {
      return;
    }

    const baseTimestamp = timestampFromUnknown(
      booking.timestamp ?? booking.created_at ?? booking.updated_at,
    ) ?? Timestamp.now();

    await snapshot.ref.set(
      {
        retention_expires_at: timestampAfterYears(
          baseTimestamp,
          transactionRetentionYears,
        ),
      },
      {merge: true},
    );
  },
);

export const logFareSettingsUpdated = onDocumentWritten(
  {
    region: "asia-southeast1",
    document: "fare_settings/{settingId}",
  },
  async (event) => {
    const snapshot = event.data?.after;
    if (!snapshot?.exists || event.params.settingId !== "current") {
      return;
    }

    const settings = snapshot.data() ?? {};
    const adminId = readOptionalString(settings.updated_by);
    if (!adminId) {
      return;
    }

    await writeAdminLog({
      logDocumentId: `fare_${event.id}`,
      action: "fare_settings_updated",
      adminId,
      summary: "Fare settings were updated.",
      targetId: event.params.settingId,
      targetName: "Fare Settings",
      targetRole: "system",
      metadata: {
        one_barangay_fare: settings.one_barangay_fare,
        buenavista_five_barangay_fare:
          settings.buenavista_five_barangay_fare,
        outside_buenavista_min_fare: settings.outside_buenavista_min_fare,
        outside_buenavista_max_fare: settings.outside_buenavista_max_fare,
        regular_passenger_discount_rate:
          settings.regular_passenger_discount_rate ?? 0,
        student_discount_rate: settings.student_discount_rate ?? 0.15,
        senior_citizen_discount_rate:
          settings.senior_citizen_discount_rate ?? 0.15,
        driver_pickup_surcharge_per_extra_barangay:
          settings.driver_pickup_surcharge_per_extra_barangay ?? 5,
        max_driver_pickup_surcharge:
          settings.max_driver_pickup_surcharge ?? 10,
        commission_rate: settings.commission_rate ?? 0,
      },
    });
  },
);

export const stampPaymentEventRetention = onDocumentWritten(
  {
    region: "asia-southeast1",
    document: "payment_events/{eventId}",
  },
  async (event) => {
    const snapshot = event.data?.after;
    if (!snapshot?.exists) {
      return;
    }

    const paymentEvent = snapshot.data() ?? {};
    if (timestampFromUnknown(paymentEvent.retention_expires_at)) {
      return;
    }

    const baseTimestamp = timestampFromUnknown(paymentEvent.received_at) ??
      Timestamp.now();
    await snapshot.ref.set(
      {
        retention_expires_at: timestampAfterYears(
          baseTimestamp,
          transactionRetentionYears,
        ),
      },
      {merge: true},
    );
  },
);

export const purgeExpiredDeactivatedAccounts = onSchedule(
  {
    region: "asia-southeast1",
    cpu: "gcf_gen1",
    schedule: "every day 02:00",
    timeZone: "Asia/Manila",
  },
  async () => {
    const now = Timestamp.now();
    const snapshot = await firestore
      .collection("users")
      .where("deactivation_purge_after", "<=", now)
      .limit(scheduledCleanupLimit)
      .get();

    await Promise.all(snapshot.docs.map(async (doc) => {
      const user = doc.data();
      if (!isDeactivatedAccount(user) || isDeletedAccount(user)) {
        return;
      }

      await anonymizeExpiredUserAccount(doc.id, user);
    }));
  },
);

export const purgeExpiredTransactionRecords = onSchedule(
  {
    region: "asia-southeast1",
    schedule: "every day 03:00",
    timeZone: "Asia/Manila",
  },
  async () => {
    const now = Timestamp.now();
    await deleteExpiredCollectionRecords({
      collectionName: "bookings",
      fallbackDateFields: ["timestamp", "created_at", "updated_at"],
      now,
      retentionField: "retention_expires_at",
    });
    await deleteExpiredCollectionRecords({
      collectionName: "payment_events",
      fallbackDateFields: ["received_at"],
      now,
      retentionField: "retention_expires_at",
    });
  },
);

export const refreshDriverDocumentStatuses = onSchedule(
  {
    region: "asia-southeast1",
    schedule: "every day 01:00",
    timeZone: "Asia/Manila",
  },
  async () => {
    const now = Timestamp.now();
    const snapshot = await firestore
      .collection("users")
      .where("role", "==", "driver")
      .limit(scheduledCleanupLimit)
      .get();

    await Promise.all(snapshot.docs.map(async (doc) => {
      const driver = doc.data();
      const status = driverDocumentExpiryState(driver, now);
      if (!status) {
        // Legacy drivers without expiry fields remain eligible until dates are
        // added through a reviewed renewal or migration.
        return;
      }

      const currentStatus = readOptionalString(driver.document_status);
      const shouldForceOffline = status === "expired" &&
        readOptionalBool(driver.is_active, false);
      if (currentStatus !== status || shouldForceOffline) {
        await doc.ref.set(
          {
            document_status: status,
            document_status_updated_at: FieldValue.serverTimestamp(),
            ...(status === "expired" ? {is_active: false} : {}),
            updated_at: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      if (status === "expired") {
        await firestore.collection("driver_locations").doc(doc.id).set(
          {
            driver_id: doc.id,
            is_available: false,
            updated_at: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      if (currentStatus !== status && status !== "valid") {
        const expiry = earliestDriverDocumentExpiry(driver);
        const type = status === "expired" ?
          "driver_documents_expired" :
          "driver_documents_expiring";
        await createAppNotification({
          userId: doc.id,
          role: "driver",
          type,
          title: status === "expired" ?
            "Driver document expired" :
            "Driver document expiring soon",
          body: status === "expired" ?
            "You are offline until an admin approves a valid replacement document." :
            "Your Driver's License or OR/CR expires within 30 days. Submit a renewal in the Driver Info Hub.",
          channel: "account",
          sourceId: `driver_document_${status}_${doc.id}_${expiry?.seconds ?? 0}`,
          data: {
            user_id: doc.id,
            role: "driver",
            document_status: status,
          },
          sendPush: true,
        });
      }
    }));
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
    cpu: "gcf_gen1",
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

export const syncRevieweeRatingStats = onDocumentWritten(
  {
    region: "asia-southeast1",
    cpu: "gcf_gen1",
    document: "reviews/{reviewId}",
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const affectedReviewees = new Map<string, RevieweeTarget>();
    addAffectedReviewee(
      affectedReviewees,
      change.before.exists ? change.before.data() : undefined,
    );
    addAffectedReviewee(
      affectedReviewees,
      change.after.exists ? change.after.data() : undefined,
    );

    let shouldRefreshDriverRanks = false;
    for (const target of affectedReviewees.values()) {
      await recomputeRevieweeRatingStats(target);
      shouldRefreshDriverRanks =
        shouldRefreshDriverRanks || target.role === "driver";
    }

    if (shouldRefreshDriverRanks) {
      await refreshTopDriverRanks();
    }
  },
);

function addAffectedReviewee(
  targets: Map<string, RevieweeTarget>,
  review: Record<string, unknown> | undefined,
) {
  if (!review) {
    return;
  }

  const id = readOptionalString(review.reviewee_id);
  const role = readOptionalString(review.reviewee_role);
  if (!id || (role !== "driver" && role !== "passenger")) {
    return;
  }

  targets.set(`${role}:${id}`, {id, role});
}

async function recomputeRevieweeRatingStats(target: RevieweeTarget) {
  const userRef = firestore.collection("users").doc(target.id);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    return;
  }

  const reviewsSnapshot = await firestore
    .collection("reviews")
    .where("reviewee_id", "==", target.id)
    .get();

  let ratingTotal = 0;
  let reviewCount = 0;
  reviewsSnapshot.docs.forEach((doc) => {
    const review = doc.data();
    if (readOptionalString(review.reviewee_role) !== target.role) {
      return;
    }

    const rating = readNumber(review.rating);
    if (rating === undefined || rating < 1 || rating > 5) {
      return;
    }

    ratingTotal += Math.round(rating);
    reviewCount += 1;
  });

  const averageRating = reviewCount === 0 ? 0 : ratingTotal / reviewCount;
  const now = FieldValue.serverTimestamp();

  if (target.role === "driver") {
    const weightedRating = driverWeightedRating({
      ratingTotal,
      reviewCount,
    });

    await userRef.set(
      {
        driver_review_rating_total: ratingTotal,
        driver_review_count: reviewCount,
        driver_average_rating: averageRating,
        driver_weighted_rating: weightedRating,
        driver_rating_badge: driverRatingBadge({
          reviewCount,
          averageRating,
        }),
        driver_rating_updated_at: now,
        review_rating_total: ratingTotal,
        review_count: reviewCount,
        average_rating: averageRating,
        updated_at: now,
      },
      {merge: true},
    );
    return;
  }

  await userRef.set(
    {
      passenger_review_rating_total: ratingTotal,
      passenger_review_count: reviewCount,
      passenger_average_rating: averageRating,
      review_rating_total: ratingTotal,
      review_count: reviewCount,
      average_rating: averageRating,
      updated_at: now,
    },
    {merge: true},
  );
}

async function refreshTopDriverRanks() {
  const topSnapshot = await firestore
    .collection("users")
    .where("role", "==", "driver")
    .where("is_verified", "==", true)
    .where("is_banned", "==", false)
    .orderBy("driver_weighted_rating", "desc")
    .orderBy("driver_review_count", "desc")
    .limit(driverLeaderboardLimit)
    .get();
  const previousRankedSnapshot = await firestore
    .collection("users")
    .where("role", "==", "driver")
    .where("driver_rating_rank", "in", driverRankValues())
    .get();

  const rankedDrivers = topSnapshot.docs
    .filter((doc) => driverReviewCountFromData(doc.data()) > 0)
    .slice(0, driverLeaderboardLimit);
  const rankedDriverIds = new Set(rankedDrivers.map((doc) => doc.id));
  const batch = firestore.batch();
  let writeCount = 0;

  rankedDrivers.forEach((doc, index) => {
    const rank = index + 1;
    batch.set(
      doc.ref,
      {
        driver_rating_rank: rank,
        driver_rating_badge: `#${rank}`,
        driver_rating_updated_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    writeCount += 1;
  });

  previousRankedSnapshot.docs.forEach((doc) => {
    if (rankedDriverIds.has(doc.id)) {
      return;
    }

    const data = doc.data();
    batch.set(
      doc.ref,
      {
        driver_rating_rank: FieldValue.delete(),
        driver_rating_badge: driverRatingBadgeFromData(data),
        driver_rating_updated_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    writeCount += 1;
  });

  if (writeCount > 0) {
    await batch.commit();
  }
}

function driverRankValues() {
  return Array.from(
    {length: driverLeaderboardLimit},
    (_, index) => index + 1,
  );
}

function driverWeightedRating(params: {
  ratingTotal: number;
  reviewCount: number;
}) {
  if (params.reviewCount <= 0) {
    return 0;
  }

  return (
    params.ratingTotal +
    driverRatingPriorAverage * driverRatingMinimumReviews
  ) / (params.reviewCount + driverRatingMinimumReviews);
}

function driverRatingBadgeFromData(data: Record<string, unknown>) {
  return driverRatingBadge({
    reviewCount: driverReviewCountFromData(data),
    averageRating: readNumber(data.driver_average_rating) ?? 0,
  });
}

function driverReviewCountFromData(data: Record<string, unknown>) {
  return Math.round(readNumber(data.driver_review_count) ?? 0);
}

function driverRatingBadge(params: {
  reviewCount: number;
  averageRating: number;
  rank?: number;
}) {
  if (
    params.rank !== undefined &&
    params.rank >= 1 &&
    params.rank <= driverLeaderboardLimit
  ) {
    return `#${params.rank}`;
  }

  if (params.reviewCount < 5) {
    return "New Driver";
  }

  if (
    params.reviewCount < driverRatingMinimumReviews &&
    params.averageRating >= risingDriverAverage
  ) {
    return "Rising Driver";
  }

  if (params.reviewCount >= 50) {
    return "Highly Reviewed";
  }

  return "";
}

async function createAppNotification(params: AppNotificationParams) {
  const notificationId = notificationDocumentId(params);
  const notificationRef = firestore
    .collection("notifications")
    .doc(notificationId);
  const existing = await notificationRef.get();
  if (existing.exists) {
    return;
  }

  const soundProfile = notificationSoundProfile(params.type, params.channel);
  const data = notificationData({
    ...params.data,
    notification_id: notificationId,
    type: params.type,
    channel: params.channel,
    notification_sound: soundProfile.key,
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

  const soundProfile = notificationSoundProfile(
    params.data.type,
    params.channel,
  );
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
          channelId: soundProfile.androidChannelId,
          sound: soundProfile.androidSound,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: soundProfile.appleSound,
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
    .where("role", "in", ["admin", "super_admin"])
    .get();

  await Promise.all(
    snapshot.docs
      .filter((doc) => isActiveAccount(doc.data()))
      .map((doc) =>
        createAppNotification({
          ...params,
          userId: doc.id,
          role: normalizedUserRole(doc.data()),
        }),
      ),
  );
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

function notificationSoundProfile(
  type: string | undefined,
  channel: AppNotificationChannel,
) {
  switch (type) {
    case "chat_message":
      return {
        key: "message",
        androidChannelId: "sakaynow_messages_sound_v1",
        androidSound: "sakaynow_message",
        appleSound: "sakaynow_message.wav",
      };
    case "booking_accepted":
      return {
        key: "booking_accepted",
        androidChannelId: "sakaynow_booking_accepted_sound_v1",
        androidSound: "sakaynow_booking_accepted",
        appleSound: "sakaynow_booking_accepted.wav",
      };
    case "driver_arrived":
      return {
        key: "driver_arrived",
        androidChannelId: "sakaynow_driver_arrived_sound_v1",
        androidSound: "sakaynow_driver_arrived",
        appleSound: "sakaynow_driver_arrived.wav",
      };
    case "booking_request":
      return {
        key: "booking_request",
        androidChannelId: "sakaynow_booking_request_sound_v1",
        androidSound: "sakaynow_booking_request",
        appleSound: "sakaynow_booking_request.wav",
      };
    default:
      return {
        key: "standard",
        androidChannelId: notificationChannelId(channel),
        androidSound: "default",
        appleSound: "default",
      };
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
    hasCurrentDriverDocuments(driver, Timestamp.now()) &&
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
  if (role === "regular" || role === "student" || role === "senior_citizen") {
    return "passenger";
  }

  if (role === "driver" || role === "admin" || role === "super_admin") {
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

function isDeactivatedAccount(data: Record<string, unknown>) {
  return isTruthy(data.is_deactivated) ||
    isTruthy(data.isDeactivated) ||
    readOptionalString(data.account_status)?.toLowerCase() === "deactivated";
}

function isDeletedAccount(data: Record<string, unknown>) {
  return readOptionalString(data.account_status)?.toLowerCase() === "deleted" ||
    data.account_anonymized_at instanceof Timestamp;
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

function timestampFromUnknown(value: unknown) {
  if (value instanceof Timestamp) {
    return value;
  }

  if (value instanceof Date) {
    return Timestamp.fromDate(value);
  }

  const text = readOptionalString(value);
  if (!text) {
    return undefined;
  }

  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? undefined : Timestamp.fromDate(date);
}

function timestampAfterDays(value: Timestamp, days: number) {
  return Timestamp.fromMillis(value.toMillis() + days * 24 * 60 * 60 * 1000);
}

function timestampAfterYears(value: Timestamp, years: number) {
  const date = value.toDate();
  date.setFullYear(date.getFullYear() + years);
  return Timestamp.fromDate(date);
}

function driverDocumentExpiryState(
  driver: Record<string, unknown>,
  now: Timestamp,
): "valid" | "expiring_soon" | "expired" | undefined {
  const expiries = driverDocumentExpiries(driver);
  if (expiries.length === 0) {
    return undefined;
  }
  if (expiries.some((expiry) => expiry.toMillis() <= now.toMillis())) {
    return "expired";
  }

  const warningAt = timestampAfterDays(now, driverDocumentExpiryWarningDays);
  if (expiries.some((expiry) => expiry.toMillis() <= warningAt.toMillis())) {
    return "expiring_soon";
  }
  return "valid";
}

function hasCurrentDriverDocuments(
  driver: Record<string, unknown>,
  now: Timestamp,
) {
  if (readOptionalString(driver.document_status) === "expired") {
    return false;
  }
  return driverDocumentExpiries(driver)
    .every((expiry) => expiry.toMillis() > now.toMillis());
}

function driverDocumentExpiries(driver: Record<string, unknown>) {
  return [
    timestampFromUnknown(driver.drivers_license_expiry),
    timestampFromUnknown(driver.or_cr_expiry),
  ].filter((expiry): expiry is Timestamp => expiry !== undefined);
}

function earliestDriverDocumentExpiry(driver: Record<string, unknown>) {
  return driverDocumentExpiries(driver)
    .sort((left, right) => left.toMillis() - right.toMillis())[0];
}

function driverDocumentLabel(documentType: string) {
  return documentType === "drivers_license" ? "Driver's License" : "OR/CR";
}

function retentionExpiresFromNow() {
  return timestampAfterYears(Timestamp.now(), transactionRetentionYears);
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

  if (isAdminStaffRole(params.senderRole)) {
    return participantIds;
  }

  const adminSnapshot = await firestore
    .collection("users")
    .where("role", "in", ["admin", "super_admin"])
    .get();

  return adminSnapshot.docs
    .filter((doc) => isActiveAccount(doc.data()))
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
    const userData = userSnapshot.data() ?? {};
    if (isAdminStaffRole(normalizedUserRole(userData)) && !isActiveAccount(userData)) {
      continue;
    }

    if (!notificationPreferencesAllow(userData, channel)) {
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
  const conversationType = readOptionalString(params.conversation.type);
  if (isAdminStaffRole(params.senderRole) && conversationType !== "admin_direct") {
    return "SakayNow Support";
  }

  const participantNames = readMap(params.conversation.participant_names);
  const senderName = readOptionalString(participantNames[params.senderId]);
  if (senderName) {
    return senderName;
  }

  if (params.senderRole === "driver") {
    return "Driver";
  }
  if (params.senderRole === "super_admin") {
    return "Super Admin";
  }
  return params.senderRole === "admin" ? "Admin" : "Passenger";
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

async function anonymizeExpiredUserAccount(
  userId: string,
  user: Record<string, unknown>,
) {
  await deleteAuthUser(userId);
  await deleteUserStorageFiles(userId);
  await deleteUserSubcollections(userId);
  await deleteUserNotifications(userId);

  const allowedTombstoneFields = new Set([
    "user_id",
    "role",
    "created_at",
    "deactivated_at",
    "account_anonymized_at",
    "account_status",
    "is_active",
    "is_banned",
    "is_deactivated",
    "is_verified",
    "updated_at",
  ]);
  const updates: Record<string, unknown> = {};
  for (const key of Object.keys(user)) {
    if (!allowedTombstoneFields.has(key)) {
      updates[key] = FieldValue.delete();
    }
  }

  updates.user_id = userId;
  updates.role = normalizedUserRole(user);
  updates.is_active = false;
  updates.is_banned = false;
  updates.is_deactivated = false;
  updates.is_verified = false;
  updates.account_status = "deleted";
  updates.account_anonymized_at = FieldValue.serverTimestamp();
  updates.updated_at = FieldValue.serverTimestamp();
  updates.privacy_deletion_reason = "expired_deactivation_window";

  await firestore.collection("users").doc(userId).set(updates, {merge: true});
}

async function deleteAuthUser(userId: string) {
  try {
    await auth.deleteUser(userId);
  } catch (error) {
    const code = (error as {code?: string}).code;
    if (code !== "auth/user-not-found") {
      throw error;
    }
  }
}

async function deleteUserStorageFiles(userId: string) {
  await storage.bucket().deleteFiles({
    force: true,
    prefix: `users/${userId}/`,
  });
}

async function deleteUserSubcollections(userId: string) {
  const userRef = firestore.collection("users").doc(userId);
  await Promise.all([
    deleteQuerySnapshot(userRef.collection("payment_methods")),
    deleteQuerySnapshot(userRef.collection("payout_accounts")),
    deleteQuerySnapshot(userRef.collection("fcm_tokens")),
  ]);
}

async function deleteUserNotifications(userId: string) {
  await deleteQuerySnapshot(
    firestore.collection("notifications").where("user_id", "==", userId),
  );
}

async function deleteExpiredCollectionRecords(params: {
  collectionName: string;
  fallbackDateFields: string[];
  now: Timestamp;
  retentionField: string;
}) {
  await deleteQuerySnapshot(
    firestore
      .collection(params.collectionName)
      .where(params.retentionField, "<=", params.now),
  );

  const cutoff = timestampAfterYears(params.now, -transactionRetentionYears);
  for (const field of params.fallbackDateFields) {
    const snapshot = await firestore
      .collection(params.collectionName)
      .where(field, "<=", cutoff)
      .limit(scheduledCleanupLimit)
      .get();
    const batch = firestore.batch();
    let deleteCount = 0;

    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (timestampFromUnknown(data[params.retentionField])) {
        return;
      }

      batch.delete(doc.ref);
      deleteCount += 1;
    });

    if (deleteCount > 0) {
      await batch.commit();
    }
  }
}

async function deleteQuerySnapshot(query: Query<DocumentData>) {
  while (true) {
    const snapshot = await query.limit(scheduledCleanupLimit).get();
    if (snapshot.empty) {
      return;
    }

    const batch = firestore.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    if (snapshot.size < scheduledCleanupLimit) {
      return;
    }
  }
}

async function writeAdminLog(params: AdminLogParams) {
  if (!params.adminId) {
    return;
  }

  const logRef = params.logDocumentId ?
    firestore.collection(adminLogsCollection).doc(params.logDocumentId) :
    firestore.collection(adminLogsCollection).doc();
  const adminName = params.adminName ?? await adminNameForId(params.adminId);

  await logRef.set(
    {
      log_id: logRef.id,
      action: params.action,
      admin_id: params.adminId,
      admin_name: adminName,
      summary: params.summary,
      created_at: FieldValue.serverTimestamp(),
      ...(params.targetId ? {target_id: params.targetId} : {}),
      ...(params.targetName ? {target_name: params.targetName} : {}),
      ...(params.targetRole ? {target_role: params.targetRole} : {}),
      ...(params.metadata ? {metadata: params.metadata} : {}),
    },
    {merge: false},
  );
}

async function adminNameForId(adminId: string) {
  const snapshot = await firestore.collection("users").doc(adminId).get();
  const data = snapshot.data();
  if (!snapshot.exists || !data) {
    return "Admin";
  }

  const name = fullName(data);
  return name === "SakayNow Passenger" ? "Admin" : name;
}

function isAdminStaffRole(role: string) {
  return role === "admin" || role === "super_admin";
}

function isAdminStaff(user: Record<string, unknown>) {
  return isAdminStaffRole(normalizedUserRole(user)) && isActiveAccount(user);
}

function isSuperAdmin(user: Record<string, unknown>) {
  return normalizedUserRole(user) === "super_admin" && isActiveAccount(user);
}

function isActiveAccount(user: Record<string, unknown>) {
  return readOptionalBool(user.is_active, true) &&
    !isBannedAccount(user) &&
    !isDeactivatedAccount(user) &&
    !isDeletedAccount(user);
}

function validateAdminAccountInput(params: {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  age: number;
  gender: string;
}) {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(params.email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }

  if (params.password.length < 8 || /\s/.test(params.password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 8 characters with no spaces.",
    );
  }

  if (!/[A-Za-z]/.test(params.password) || !/\d/.test(params.password)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must include letters and at least one number.",
    );
  }

  validateAccountName(params.firstName, "First name", {reserved: true});
  validateAccountName(params.lastName, "Last name");

  if (!Number.isInteger(params.age) || params.age < 18 || params.age > 100) {
    throw new HttpsError("invalid-argument", "Admin age must be 18 to 100.");
  }

  if (!["male", "female", "other"].includes(params.gender)) {
    throw new HttpsError("invalid-argument", "Select a valid gender.");
  }
}

function validateAccountName(
  value: string,
  fieldName: string,
  options: {reserved?: boolean} = {},
) {
  const name = value.trim();
  if (name.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be at least 2 characters.`,
    );
  }

  if (/\d/.test(name)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} cannot contain numbers.`,
    );
  }

  if (options.reserved && name.toLowerCase() === "admin") {
    throw new HttpsError("invalid-argument", "The name admin is reserved.");
  }
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

async function loadFareValidationSettings(): Promise<FareValidationSettings> {
  const snapshot = await firestore
    .collection(fareSettingsCollection)
    .doc(currentFareSettingsDocument)
    .get();
  const data = snapshot.data();
  if (!snapshot.exists || !data) {
    return defaultFareValidationSettings;
  }

  const oneBarangayFare = readPositiveNumber(
    data.one_barangay_fare,
    regularMinimumRideFare,
  );
  const fiveBarangayFare = Math.max(
    oneBarangayFare,
    readPositiveNumber(
      data.buenavista_five_barangay_fare,
      regularMinimumRideFare,
    ),
  );
  const outsideMinimumFare = readPositiveNumber(
    data.outside_buenavista_min_fare,
    regularMinimumRideFare,
  );
  const outsideNineKmFare = Math.max(
    outsideMinimumFare,
    readPositiveNumber(data.outside_buenavista_9km_fare, 40),
  );
  const outsideTwelveKmFare = Math.max(
    outsideNineKmFare,
    readPositiveNumber(data.outside_buenavista_12km_fare, 60),
  );
  const outsideSixteenKmFare = Math.max(
    outsideTwelveKmFare,
    readPositiveNumber(data.outside_buenavista_16km_fare, 80),
  );
  const outsideMaximumFare = Math.max(
    outsideSixteenKmFare,
    readPositiveNumber(data.outside_buenavista_max_fare, maximumRideFare),
  );
  const regularDiscountRate = Math.min(
    1,
    Math.max(
      0,
      readNumber(data.regular_passenger_discount_rate) ??
        regularPassengerDiscountRate,
    ),
  );
  const activeStudentDiscountRate = Math.min(
    1,
    Math.max(
      0,
      readNumber(data.student_discount_rate) ?? studentDiscountRate,
    ),
  );
  const activeSeniorDiscountRate = Math.min(
    1,
    Math.max(
      0,
      readNumber(data.senior_citizen_discount_rate) ??
        seniorCitizenDiscountRate,
    ),
  );
  const pickupSurchargePerExtraBarangay = Math.max(
    0,
    Math.round(
      readNumber(data.driver_pickup_surcharge_per_extra_barangay) ?? 5,
    ),
  );
  const maximumPickupSurcharge = pickupSurchargePerExtraBarangay === 0 ? 0 :
    Math.max(
      pickupSurchargePerExtraBarangay,
      Math.round(
        readNumber(data.max_driver_pickup_surcharge) ??
          defaultMaxDriverPickupSurcharge,
      ),
    );
  const minimumRegularFare = Math.min(
    oneBarangayFare,
    fiveBarangayFare,
    outsideMinimumFare,
  );

  return {
    regularMinimumRideFare: minimumRegularFare,
    minimumDiscountedFare: Math.max(
      1,
      Math.min(
        Math.round(minimumRegularFare * (1 - regularDiscountRate)),
        Math.round(minimumRegularFare * (1 - activeStudentDiscountRate)),
        Math.round(minimumRegularFare * (1 - activeSeniorDiscountRate)),
      ),
    ),
    maximumRideFare: outsideMaximumFare + maximumPickupSurcharge,
    regularPassengerDiscountRate: regularDiscountRate,
    studentDiscountRate: activeStudentDiscountRate,
    seniorCitizenDiscountRate: activeSeniorDiscountRate,
  };
}

function readPositiveNumber(value: unknown, fallback: number) {
  const parsed = readNumber(value);
  if (parsed === undefined || parsed <= 0) {
    return fallback;
  }

  return Math.round(parsed);
}

function isAllowedFareAmount(params: {
  amount: number;
  booking: Record<string, unknown>;
  passengerData: Record<string, unknown>;
  fareSettings: FareValidationSettings;
}) {
  if (params.amount > params.fareSettings.maximumRideFare) {
    return false;
  }

  if (params.amount >= params.fareSettings.regularMinimumRideFare) {
    return true;
  }

  if (params.amount < params.fareSettings.minimumDiscountedFare) {
    return false;
  }

  return hasValidPassengerDiscount(params);
}

function hasValidPassengerDiscount(params: {
  amount: number;
  booking: Record<string, unknown>;
  passengerData: Record<string, unknown>;
  fareSettings: FareValidationSettings;
}) {
  const passengerType =
    readOptionalString(params.passengerData.passenger_type)?.toLowerCase() ??
    (() => {
      const role = readOptionalString(params.passengerData.role)?.toLowerCase();
      if (role === "student") return "student";
      if (role === "senior_citizen") return "senior_citizen";
      return "regular";
    })();
  const isVerified = params.passengerData.is_verified === true ||
    params.passengerData.isVerified === true ||
    params.passengerData.isVerrified === true;
  const discountConfiguration = passengerType === "student" ? {
    rate: params.fareSettings.studentDiscountRate,
    code: studentDiscountCode,
    requiresVerification: true,
  } : passengerType === "senior_citizen" ? {
    rate: params.fareSettings.seniorCitizenDiscountRate,
    code: seniorCitizenDiscountCode,
    requiresVerification: true,
  } : {
    rate: params.fareSettings.regularPassengerDiscountRate,
    code: regularPassengerDiscountCode,
    requiresVerification: false,
  };
  if (
    discountConfiguration.rate <= 0 ||
    (discountConfiguration.requiresVerification && !isVerified)
  ) {
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
    discountCode !== discountConfiguration.code ||
    discountRate === undefined ||
    Math.abs(discountRate - discountConfiguration.rate) > 0.001 ||
    baseFare === undefined ||
    baseFare < params.fareSettings.regularMinimumRideFare ||
    baseFare > params.fareSettings.maximumRideFare
  ) {
    return false;
  }

  return Math.max(
    1,
    Math.round(baseFare * (1 - discountConfiguration.rate)),
  ) === params.amount;
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

function canAccessChatConversation(
  conversation: Record<string, unknown>,
  requesterId: string,
  requester: Record<string, unknown> | undefined,
) {
  const conversationType = readOptionalString(conversation.type);
  const participantIds = readStringArray(conversation.participant_ids);
  if (
    participantIds.includes(requesterId) &&
    ["ride", "support", "admin_direct"].includes(conversationType ?? "")
  ) {
    return true;
  }

  return conversationType === "support" &&
    requester !== undefined &&
    isAdminStaff(requester);
}

function isCurrentConversationMessage(
  conversation: Record<string, unknown>,
  message: Record<string, unknown>,
  messageId: string,
) {
  const currentMessageId = readOptionalString(conversation.last_message_id);
  if (currentMessageId) {
    return currentMessageId === messageId;
  }

  const conversationTimestamp = timestampFromUnknown(
    conversation.last_message_at,
  );
  const messageTimestamp = timestampFromUnknown(message.created_at);
  return conversationTimestamp !== undefined &&
    messageTimestamp !== undefined &&
    conversationTimestamp.isEqual(messageTimestamp);
}

function conversationActivityMillis(data: Record<string, unknown>) {
  for (const value of [
    data.last_message_at,
    data.updated_at,
    data.created_at,
  ]) {
    const timestamp = timestampFromUnknown(value);
    if (timestamp) {
      return timestamp.toMillis();
    }
  }

  return 0;
}

function rideParticipantName(
  data: Record<string, unknown>,
  fallback: string,
) {
  const name = `${readOptionalString(data.first_name) ?? ""} ${
    readOptionalString(data.last_name) ?? ""
  }`.trim();
  if (name.length > 0) {
    return name;
  }

  return readOptionalString(data.email) ?? fallback;
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
