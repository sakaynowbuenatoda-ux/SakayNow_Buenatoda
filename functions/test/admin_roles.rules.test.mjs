import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, test} from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, updateDoc} from "firebase/firestore";
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
      "driver-1": activeUser("driver"),
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
