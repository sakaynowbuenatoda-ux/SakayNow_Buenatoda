import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, test} from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import {getBytes, ref, uploadBytes} from "firebase/storage";

const projectRoot = path.resolve(import.meta.dirname, "../..");
const projectId = "sakaynow-super-admin-rules-test";
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(projectRoot, "firestore.rules"),
        "utf8",
      ),
    },
    storage: {
      rules: fs.readFileSync(path.join(projectRoot, "storage.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.clearStorage();
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const users = {
      "super-1": activeUser("super_admin"),
      "admin-1": activeUser("admin"),
      "admin-2": activeUser("admin"),
      "admin-3": activeUser("admin"),
      "admin-disabled": {
        ...activeUser("admin"),
        is_active: false,
        is_deactivated: true,
        account_status: "deactivated",
      },
      "passenger-1": activeUser("passenger"),
      "legacy-passenger": {
        role: "passenger",
        passenger_type: "student",
        email: "legacy@example.com",
        isVerified: false,
        isActive: false,
        isBanned: false,
        isDeactivated: false,
        account_status: "active",
      },
      "driver-1": activeUser("driver"),
      "legacy-driver": {
        role: "driver",
        email: "legacy-driver@example.com",
        is_verified: false,
        isVerified: true,
        is_active: true,
        is_banned: false,
        is_deactivated: false,
        account_status: "active",
        tricycle_front_url: "https://example.com/legacy-front.jpg",
        tricycle_back_url: "https://example.com/legacy-back.jpg",
      },
      "new-driver": {
        role: "driver",
        email: "new-driver@example.com",
        is_verified: false,
        is_active: false,
        is_banned: false,
        is_deactivated: false,
        account_status: "active",
      },
    };
    for (const [userId, data] of Object.entries(users)) {
      await setDoc(doc(firestore, "users", userId), {
        ...data,
        user_id: userId,
      });
    }
    await setDoc(doc(firestore, "admin_logs", "log-1"), {
      log_id: "log-1",
      action: "user_approved",
      admin_id: "admin-1",
      admin_name: "Admin One",
      summary: "A user was approved.",
    });
    await setDoc(doc(firestore, "conversations", "admin_direct_admin-1_admin-2"), {
      conversation_id: "admin_direct_admin-1_admin-2",
      type: "admin_direct",
      participant_ids: ["admin-1", "admin-2"],
      participant_names: {
        "admin-1": "Admin One",
        "admin-2": "Admin Two",
      },
      participant_roles: {
        "admin-1": "admin",
        "admin-2": "admin",
      },
    });
    await setDoc(doc(firestore, "conversations", "ride_booking-1"), {
      conversation_id: "ride_booking-1",
      type: "ride",
      booking_id: "booking-1",
      booking_ids: ["booking-1"],
      passenger_id: "passenger-1",
      driver_id: "driver-1",
      participant_ids: ["passenger-1", "driver-1"],
      participant_names: {
        "passenger-1": "Passenger One",
        "driver-1": "Driver One",
      },
      participant_roles: {
        "passenger-1": "passenger",
        "driver-1": "driver",
      },
    });
  });
});

after(async () => {
  await environment.cleanup();
});

test("regular and super admins can read shared admin logs", async () => {
  for (const userId of ["admin-1", "super-1"]) {
    const firestore = environment.authenticatedContext(userId).firestore();
    await assertSucceeds(getDoc(doc(firestore, "admin_logs", "log-1")));
  }

  const passenger = environment.authenticatedContext("passenger-1").firestore();
  await assertFails(getDoc(doc(passenger, "admin_logs", "log-1")));
});

test("legacy passengers can upload and submit their verification documents", async () => {
  const passenger = environment.authenticatedContext("legacy-passenger");
  const storage = passenger.storage();
  const firestore = passenger.firestore();
  const idPath =
    "users/legacy-passenger/verification_documents/id_1000.jpg";
  const idFile = ref(storage, idPath);

  await assertSucceeds(
    uploadBytes(idFile, new Uint8Array([1, 2, 3]), {
      contentType: "image/jpeg",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(firestore, "users", "legacy-passenger"), {
      pending_document_review: {
        kind: "passenger_identity",
        id_image_url: "https://example.com/legacy-passenger-id.jpg",
        id_image_path: idPath,
        submitted_at: serverTimestamp(),
      },
      document_review_status: "pending",
      document_review_submitted_at: serverTimestamp(),
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      document_submitted_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const stagedPassenger = await getDoc(
    doc(firestore, "users", "legacy-passenger"),
  );
  assert.equal(stagedPassenger.data().isVerified, false);
  assert.equal(stagedPassenger.data().isActive, false);
  assert.equal(stagedPassenger.data().id_image_url, undefined);
  assert.equal(
    stagedPassenger.data().pending_document_review.kind,
    "passenger_identity",
  );

  const otherPassenger = environment.authenticatedContext("passenger-1");
  await assertFails(
    uploadBytes(
      ref(otherPassenger.storage(), "users/legacy-passenger/id_upload.jpg"),
      new Uint8Array([4, 5, 6]),
      {contentType: "image/jpeg"},
    ),
  );
  await assertFails(
    updateDoc(doc(firestore, "users", "legacy-passenger"), {
      id_image_url: "https://example.com/bypass-review.jpg",
      updated_at: serverTimestamp(),
    }),
  );
});

test("verified passengers stay verified while document updates are pending", async () => {
  const passenger = environment.authenticatedContext("passenger-1");
  const firestore = passenger.firestore();
  const idPath = "users/passenger-1/verification_documents/id_2000.jpg";

  await assertSucceeds(
    uploadBytes(ref(passenger.storage(), idPath), new Uint8Array([1, 2, 3]), {
      contentType: "image/jpeg",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(firestore, "users", "passenger-1"), {
      pending_document_review: {
        kind: "passenger_identity",
        id_image_url: "https://example.com/passenger-id.jpg",
        id_image_path: idPath,
        submitted_at: serverTimestamp(),
      },
      document_review_status: "pending",
      document_review_submitted_at: serverTimestamp(),
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      document_submitted_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const stagedPassenger = await getDoc(
    doc(firestore, "users", "passenger-1"),
  );
  assert.equal(stagedPassenger.data().is_verified, true);
  assert.equal(stagedPassenger.data().is_active, true);
  assert.equal(stagedPassenger.data().document_review_status, "pending");
});

test("new drivers can attach all initial registration documents", async () => {
  const driver = environment.authenticatedContext("new-driver");
  const storage = driver.storage();
  const firestore = driver.firestore();
  const files = [
    "nbi_clearance.jpg",
    "drivers_license.jpg",
    "selfie.jpg",
    "or_cr.jpg",
    "tricycle_front.jpg",
    "tricycle_back.jpg",
  ];

  for (const fileName of files) {
    await assertSucceeds(
      uploadBytes(
        ref(storage, `users/new-driver/${fileName}`),
        new Uint8Array([1, 2, 3]),
        {contentType: "image/jpeg"},
      ),
    );
  }

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "new-driver"), {
      nbi_clearance_url: "https://example.com/nbi.jpg",
      drivers_license_url: "https://example.com/license.jpg",
      selfie_url: "https://example.com/selfie.jpg",
      or_cr_url: "https://example.com/or-cr.jpg",
      tricycle_front_url: "https://example.com/front.jpg",
      tricycle_back_url: "https://example.com/back.jpg",
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
    }),
  );

  const profile = await getDoc(doc(firestore, "users", "new-driver"));
  assert.equal(profile.data().is_verified, false);
  assert.equal(profile.data().is_active, false);
  assert.equal(profile.data().drivers_license_url.includes("license"), true);
});

test("new drivers can record a document upload failure", async () => {
  const firestore = environment
    .authenticatedContext("new-driver")
    .firestore();

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "new-driver"), {
      document_upload_status: "failed",
      document_upload_error: "Credential upload did not complete.",
    }),
  );

  const profile = await getDoc(doc(firestore, "users", "new-driver"));
  assert.equal(profile.data().is_verified, false);
  assert.equal(profile.data().is_active, false);
  assert.equal(profile.data().document_upload_status, "failed");
});

test("unverified drivers can recover a missing credential from Driver Hub", async () => {
  const driver = environment.authenticatedContext("new-driver");
  const firestore = driver.firestore();
  const credentialPath =
    "users/new-driver/credentials/nbi_clearance_4000.jpg";
  await assertSucceeds(
    uploadBytes(
      ref(driver.storage(), credentialPath),
      new Uint8Array([1, 2, 3]),
      {contentType: "image/jpeg"},
    ),
  );

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "new-driver"), {
      nbi_clearance_url: "https://example.com/recovery-nbi.jpg",
      nbi_clearance_path: credentialPath,
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      credential_updated_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const profile = await getDoc(doc(firestore, "users", "new-driver"));
  assert.equal(profile.data().is_verified, false);
  assert.equal(profile.data().nbi_clearance_path, credentialPath);
  assert.equal(profile.data().pending_document_review, undefined);
});

test("unverified drivers can recover vehicle photos from Driver Hub", async () => {
  const driver = environment.authenticatedContext("new-driver");
  const firestore = driver.firestore();
  const frontPath =
    "users/new-driver/vehicle_photos/tricycle_front_5000.jpg";
  const backPath =
    "users/new-driver/vehicle_photos/tricycle_back_5000.jpg";
  for (const photoPath of [frontPath, backPath]) {
    await assertSucceeds(
      uploadBytes(
        ref(driver.storage(), photoPath),
        new Uint8Array([1, 2, 3]),
        {contentType: "image/jpeg"},
      ),
    );
  }

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "new-driver"), {
      vehicle_type: "Traditional Tricycle",
      tricycle_color: "Black",
      plate_number: "BUENA-500",
      tricycle_front_url: "https://example.com/recovery-front.jpg",
      tricycle_front_path: frontPath,
      tricycle_back_url: "https://example.com/recovery-back.jpg",
      tricycle_back_path: backPath,
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      vehicle_details_updated_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const profile = await getDoc(doc(firestore, "users", "new-driver"));
  assert.equal(profile.data().is_verified, false);
  assert.equal(profile.data().plate_number, "BUENA-500");
  assert.equal(profile.data().pending_document_review, undefined);
});

test("existing drivers can submit vehicle details and owner-scoped photos", async () => {
  const driver = environment.authenticatedContext("driver-1");
  const storage = driver.storage();
  const firestore = driver.firestore();
  const frontPath =
    "users/driver-1/vehicle_photos/tricycle_front_1000.jpg";
  const backPath = "users/driver-1/vehicle_photos/tricycle_back_1000.jpg";

  for (const photoPath of [frontPath, backPath]) {
    await assertSucceeds(
      uploadBytes(ref(storage, photoPath), new Uint8Array([1, 2, 3]), {
        contentType: "image/jpeg",
      }),
    );
  }

  const outsider = environment.authenticatedContext("passenger-1");
  await assertFails(
    uploadBytes(
      ref(
        outsider.storage(),
        "users/driver-1/vehicle_photos/tricycle_front_2000.jpg",
      ),
      new Uint8Array([4, 5, 6]),
      {contentType: "image/jpeg"},
    ),
  );

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "driver-1"), {
      pending_document_review: {
        kind: "driver_vehicle",
        vehicle_type: "Traditional Tricycle",
        tricycle_color: "Blue",
        plate_number: "BUENA-101",
        tricycle_front_url: "https://example.com/front.jpg",
        tricycle_front_path: frontPath,
        tricycle_back_url: "https://example.com/back.jpg",
        tricycle_back_path: backPath,
        submitted_at: serverTimestamp(),
      },
      document_review_status: "pending",
      document_review_submitted_at: serverTimestamp(),
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      vehicle_details_updated_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const stagedDriver = await getDoc(doc(firestore, "users", "driver-1"));
  assert.equal(stagedDriver.data().is_verified, true);
  assert.equal(stagedDriver.data().is_active, true);
  assert.equal(stagedDriver.data().plate_number, undefined);
  assert.equal(
    stagedDriver.data().pending_document_review.plate_number,
    "BUENA-101",
  );

  await assertSucceeds(getBytes(ref(outsider.storage(), frontPath)));
  await assertFails(
    updateDoc(doc(firestore, "users", "driver-1"), {
      plate_number: "SPOOFED-1",
      vehicle_details_updated_at: serverTimestamp(),
      is_verified: true,
      is_active: true,
      updated_at: serverTimestamp(),
    }),
  );
});

test("verified drivers stage credential replacements without losing access", async () => {
  const driver = environment.authenticatedContext("driver-1");
  const firestore = driver.firestore();
  const credentialPath =
    "users/driver-1/credentials/drivers_license_3000.jpg";

  await assertSucceeds(
    uploadBytes(
      ref(driver.storage(), credentialPath),
      new Uint8Array([1, 2, 3]),
      {contentType: "image/jpeg"},
    ),
  );
  await assertSucceeds(
    updateDoc(doc(firestore, "users", "driver-1"), {
      pending_document_review: {
        kind: "driver_credential",
        credential_type: "drivers_license",
        document_url: "https://example.com/new-license.jpg",
        document_path: credentialPath,
        expiry: Timestamp.fromMillis(Date.now() + 86_400_000),
        submitted_at: serverTimestamp(),
      },
      document_review_status: "pending",
      document_review_submitted_at: serverTimestamp(),
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      credential_updated_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const stagedDriver = await getDoc(doc(firestore, "users", "driver-1"));
  assert.equal(stagedDriver.data().is_verified, true);
  assert.equal(stagedDriver.data().is_active, true);
  assert.equal(stagedDriver.data().drivers_license_url, undefined);

  await assertFails(
    updateDoc(doc(firestore, "users", "driver-1"), {
      is_verified: false,
      is_active: false,
      updated_at: serverTimestamp(),
    }),
  );
});

test("legacy verified drivers canonicalize verification during review", async () => {
  const firestore = environment
    .authenticatedContext("legacy-driver")
    .firestore();

  await assertSucceeds(
    updateDoc(doc(firestore, "users", "legacy-driver"), {
      is_verified: true,
      pending_document_review: {
        kind: "driver_vehicle",
        vehicle_type: "Traditional Tricycle",
        tricycle_color: "Black",
        plate_number: "LEGACY-1",
        tricycle_front_url: "https://example.com/legacy-front.jpg",
        tricycle_back_url: "https://example.com/legacy-back.jpg",
        submitted_at: serverTimestamp(),
      },
      document_review_status: "pending",
      document_review_submitted_at: serverTimestamp(),
      document_upload_status: "uploaded",
      document_upload_error: deleteField(),
      vehicle_details_updated_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    }),
  );

  const profile = await getDoc(doc(firestore, "users", "legacy-driver"));
  assert.equal(profile.data().is_verified, true);
  assert.equal(profile.data().isVerified, true);
  assert.equal(profile.data().document_review_status, "pending");
});

test("admin-direct threads are restricted to active participants", async () => {
  const conversationPath = "conversations/admin_direct_admin-1_admin-2";
  for (const userId of ["admin-1", "admin-2"]) {
    const firestore = environment.authenticatedContext(userId).firestore();
    await assertSucceeds(getDoc(doc(firestore, conversationPath)));
  }

  for (const userId of ["admin-3", "admin-disabled", "passenger-1"]) {
    const firestore = environment.authenticatedContext(userId).firestore();
    await assertFails(getDoc(doc(firestore, conversationPath)));
  }

  const participant = environment.authenticatedContext("admin-1").firestore();
  await assertSucceeds(
    updateDoc(doc(participant, conversationPath), {
      last_message_text: "Please review the queue.",
    }),
  );
  const outsider = environment.authenticatedContext("admin-3").firestore();
  await assertFails(
    updateDoc(doc(outsider, conversationPath), {
      last_message_text: "Unauthorized update",
    }),
  );
});

test("clients cannot create admin-direct conversations", async () => {
  const firestore = environment.authenticatedContext("super-1").firestore();
  await assertFails(
    setDoc(doc(firestore, "conversations", "admin_direct_admin-1_super-1"), {
      conversation_id: "admin_direct_admin-1_super-1",
      type: "admin_direct",
      participant_ids: ["admin-1", "super-1"],
      participant_names: {
        "admin-1": "Admin One",
        "super-1": "Super Admin",
      },
      participant_roles: {
        "admin-1": "admin",
        "super-1": "super_admin",
      },
    }),
  );
});

test("ride conversation creation and identity stay server-owned", async () => {
  const passenger = environment.authenticatedContext("passenger-1").firestore();
  await assertFails(
    setDoc(doc(passenger, "conversations", "ride_booking-2"), {
      conversation_id: "ride_booking-2",
      type: "ride",
      booking_id: "booking-2",
      booking_ids: ["booking-2"],
      passenger_id: "passenger-1",
      driver_id: "driver-1",
      participant_ids: ["passenger-1", "driver-1"],
      participant_names: {
        "passenger-1": "Passenger One",
        "driver-1": "Driver One",
      },
      participant_roles: {
        "passenger-1": "passenger",
        "driver-1": "driver",
      },
    }),
  );

  const ride = doc(passenger, "conversations", "ride_booking-1");
  await assertSucceeds(updateDoc(ride, {last_message_text: "On my way"}));
  await assertFails(updateDoc(ride, {booking_id: "booking-2"}));
  await assertFails(updateDoc(ride, {driver_id: "driver-2"}));
});

test("passengers can still create their stable support conversation", async () => {
  const passenger = environment.authenticatedContext("passenger-1").firestore();
  await assertSucceeds(
    setDoc(doc(passenger, "conversations", "support_passenger-1"), {
      conversation_id: "support_passenger-1",
      type: "support",
      support_user_id: "passenger-1",
      admin_visible: true,
      participant_ids: ["passenger-1"],
      participant_names: {"passenger-1": "Passenger One"},
      participant_roles: {"passenger-1": "passenger"},
    }),
  );
});

test("conversation deletion cutoffs hide only the deleting user's old messages", async () => {
  const conversationPath = "conversations/ride_booking-1";
  const oldMessagePath = `${conversationPath}/messages/message-old`;
  const newMessagePath = `${conversationPath}/messages/message-new`;
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await updateDoc(doc(firestore, conversationPath), {
      deleted_at_by: {"passenger-1": Timestamp.fromMillis(2_000)},
      last_message_at: Timestamp.fromMillis(3_000),
    });
    for (const [messageId, createdAt] of [
      ["message-old", Timestamp.fromMillis(1_000)],
      ["message-new", Timestamp.fromMillis(3_000)],
    ]) {
      await setDoc(doc(firestore, `${conversationPath}/messages/${messageId}`), {
        message_id: messageId,
        conversation_id: "ride_booking-1",
        sender_id: "driver-1",
        sender_role: "driver",
        type: "text",
        text: messageId,
        read_by: {"driver-1": true},
        created_at: createdAt,
      });
    }
  });

  const passenger = environment.authenticatedContext("passenger-1").firestore();
  await assertFails(getDoc(doc(passenger, oldMessagePath)));
  await assertSucceeds(getDoc(doc(passenger, newMessagePath)));
  const visibleSnapshot = await assertSucceeds(
    getDocs(query(
      collection(passenger, `${conversationPath}/messages`),
      where("created_at", ">", Timestamp.fromMillis(2_000)),
      orderBy("created_at"),
    )),
  );
  assert.equal(visibleSnapshot.docs.length, 1);
  assert.equal(visibleSnapshot.docs[0].id, "message-new");

  const driver = environment.authenticatedContext("driver-1").firestore();
  await assertSucceeds(getDoc(doc(driver, oldMessagePath)));
  await assertSucceeds(getDoc(doc(driver, newMessagePath)));
});

test("clients cannot spoof conversation deletion or unsent tombstones", async () => {
  const conversationPath = "conversations/ride_booking-1";
  const passenger = environment.authenticatedContext("passenger-1").firestore();
  await assertFails(
    updateDoc(doc(passenger, conversationPath), {
      "deleted_at_by.passenger-1": serverTimestamp(),
    }),
  );

  const messagePath = `${conversationPath}/messages/message-1`;
  await assertFails(
    setDoc(doc(passenger, messagePath), {
      message_id: "message-1",
      conversation_id: "ride_booking-1",
      sender_id: "passenger-1",
      sender_role: "passenger",
      type: "unsent",
      unsent_by: "passenger-1",
      text: "hidden",
      created_at: serverTimestamp(),
    }),
  );

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), messagePath), {
      message_id: "message-1",
      conversation_id: "ride_booking-1",
      sender_id: "passenger-1",
      sender_role: "passenger",
      type: "text",
      text: "Original message",
      created_at: Timestamp.fromMillis(1_000),
    });
  });
  await assertFails(updateDoc(doc(passenger, messagePath), {type: "unsent"}));
  await assertFails(deleteDoc(doc(passenger, messagePath)));
});

test("admin accounts cannot be managed through client writes", async () => {
  for (const userId of ["admin-1", "super-1"]) {
    const firestore = environment.authenticatedContext(userId).firestore();
    await assertFails(
      updateDoc(doc(firestore, "users", "admin-2"), {
        is_active: false,
        is_deactivated: true,
        account_status: "deactivated",
      }),
    );
  }
});

test("regular and super admins can read protected driver files", async () => {
  const ownerStorage = environment.authenticatedContext("driver-1").storage();
  const file = ref(ownerStorage, "users/driver-1/renewals/license.jpg");
  await assertSucceeds(
    uploadBytes(file, new Uint8Array([1, 2, 3]), {
      contentType: "image/jpeg",
    }),
  );

  for (const userId of ["admin-1", "super-1"]) {
    const storage = environment.authenticatedContext(userId).storage();
    await assertSucceeds(
      getBytes(ref(storage, "users/driver-1/renewals/license.jpg")),
    );
  }
  const disabled = environment.authenticatedContext("admin-disabled").storage();
  await assertFails(
    getBytes(ref(disabled, "users/driver-1/renewals/license.jpg")),
  );
});

function activeUser(role) {
  return {
    role,
    is_active: true,
    is_verified: true,
    is_banned: false,
    is_deactivated: false,
    account_status: "active",
  };
}
