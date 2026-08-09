import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {after, before, beforeEach, test} from "node:test";

import {deleteApp, getApps} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const projectId = "sakaynow-super-admin-rules-test";
let firestore;
let runSuperAdminMigration;

before(() => {
  process.env.GCLOUD_PROJECT = projectId;
  ({runSuperAdminMigration} = require("../lib/migrate_super_admin.js"));
  firestore = getFirestore();
});

beforeEach(async () => {
  const collections = await firestore.listCollections();
  for (const collection of collections) {
    await firestore.recursiveDelete(collection);
  }
});

after(async () => {
  for (const app of getApps()) {
    await deleteApp(app);
  }
});

test("promotes one account, canonicalizes threads, and is repeatable", async () => {
  await seedAdmin("z-admin", " Admin ");
  await seedAdmin("a-admin", "Alex");

  const originalCreatedAt = Timestamp.fromMillis(1_700_000_000_000);
  const originalUpdatedAt = Timestamp.fromMillis(1_700_000_001_000);
  const originalMessageAt = Timestamp.fromMillis(1_700_000_002_000);
  const sourceId = "admin_direct_z-admin_a-admin";
  const targetId = "admin_direct_a-admin_z-admin";
  const source = firestore.collection("conversations").doc(sourceId);
  await source.set({
    conversation_id: sourceId,
    type: "admin_direct",
    main_admin_id: "z-admin",
    target_admin_id: "a-admin",
    participant_ids: ["z-admin", "a-admin"],
    participant_names: {
      "z-admin": "Main Admin",
      "a-admin": "Alex User",
    },
    participant_roles: {
      "z-admin": "admin",
      "a-admin": "admin",
    },
    unread_counts: {"z-admin": 4, "a-admin": 2},
    created_at: originalCreatedAt,
    updated_at: originalUpdatedAt,
  });
  await source.collection("messages").doc("message-1").set({
    message_id: "message-1",
    conversation_id: sourceId,
    sender_id: "a-admin",
    text: "Please check this.",
    created_at: originalMessageAt,
  });

  const firstResult = await runSuperAdminMigration();
  assert.deepEqual(firstResult, {
    promotedUserId: "z-admin",
    normalizedConversationCount: 1,
  });

  const promoted = await firestore.doc("users/z-admin").get();
  assert.equal(promoted.data().role, "super_admin");

  assert.equal((await source.get()).exists, false);
  const target = await firestore.doc(`conversations/${targetId}`).get();
  assert.equal(target.exists, true);
  assert.deepEqual(target.data().participant_ids, ["a-admin", "z-admin"]);
  assert.deepEqual(target.data().participant_names, {
    "a-admin": "Alex User",
    "z-admin": "Admin User",
  });
  assert.deepEqual(target.data().participant_roles, {
    "a-admin": "admin",
    "z-admin": "super_admin",
  });
  assert.deepEqual(target.data().unread_counts, {"z-admin": 4, "a-admin": 2});
  assert.equal(target.data().created_at.toMillis(), originalCreatedAt.toMillis());
  assert.equal(target.data().updated_at.toMillis(), originalUpdatedAt.toMillis());
  assert.equal(target.data().main_admin_id, undefined);
  assert.equal(target.data().target_admin_id, undefined);

  const message = await firestore
    .doc(`conversations/${targetId}/messages/message-1`)
    .get();
  assert.equal(message.exists, true);
  assert.equal(message.data().created_at.toMillis(), originalMessageAt.toMillis());

  const secondResult = await runSuperAdminMigration();
  assert.deepEqual(secondResult, firstResult);
  const logs = await firestore.collection("admin_logs").get();
  assert.equal(logs.size, 1);
  assert.equal(logs.docs[0].data().action, "super_admin_promoted");
  const repeatedTarget = await firestore.doc(`conversations/${targetId}`).get();
  assert.equal(
    repeatedTarget.data().updated_at.toMillis(),
    originalUpdatedAt.toMillis(),
  );
});

test("fails without writes when the promotion candidate is missing", async () => {
  await seedAdmin("admin-1", "Alex");

  await assert.rejects(
    runSuperAdminMigration,
    /requires exactly one active admin named admin; found 0/,
  );

  const user = await firestore.doc("users/admin-1").get();
  assert.equal(user.data().role, "admin");
  assert.equal((await firestore.collection("admin_logs").get()).empty, true);
});

test("fails without writes when promotion candidates are duplicated", async () => {
  await seedAdmin("admin-1", "Admin");
  await seedAdmin("admin-2", "admin");

  await assert.rejects(
    runSuperAdminMigration,
    /requires exactly one active admin named admin; found 2/,
  );

  for (const userId of ["admin-1", "admin-2"]) {
    const user = await firestore.doc(`users/${userId}`).get();
    assert.equal(user.data().role, "admin");
  }
  assert.equal((await firestore.collection("admin_logs").get()).empty, true);
});

test("refuses a canonical conversation ID conflict without writes", async () => {
  await seedAdmin("z-admin", "Admin");
  await seedAdmin("a-admin", "Alex");

  const sourceId = "admin_direct_z-admin_a-admin";
  const targetId = "admin_direct_a-admin_z-admin";
  await firestore.doc(`conversations/${sourceId}`).set({
    conversation_id: sourceId,
    type: "admin_direct",
    participant_ids: ["z-admin", "a-admin"],
  });
  await firestore.doc(`conversations/${targetId}`).set({
    conversation_id: targetId,
    type: "support",
    marker: "keep-me",
  });

  await assert.rejects(
    runSuperAdminMigration,
    /already exists; no records were overwritten/,
  );

  assert.equal((await firestore.doc(`conversations/${sourceId}`).get()).exists, true);
  const conflict = await firestore.doc(`conversations/${targetId}`).get();
  assert.equal(conflict.data().marker, "keep-me");
  assert.equal((await firestore.doc("users/z-admin").get()).data().role, "admin");
  assert.equal((await firestore.collection("admin_logs").get()).empty, true);
});

async function seedAdmin(userId, firstName) {
  await firestore.doc(`users/${userId}`).set({
    user_id: userId,
    first_name: firstName,
    last_name: "User",
    role: "admin",
    is_active: true,
    is_banned: false,
    is_deactivated: false,
    account_status: "active",
  });
}
