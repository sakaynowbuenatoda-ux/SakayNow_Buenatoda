import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";

initializeApp();

const firestore = getFirestore();

export async function runSuperAdminMigration() {
  const adminSnapshot = await firestore
    .collection("users")
    .where("role", "in", ["admin", "super_admin"])
    .get();
  const activeSuperAdmins = adminSnapshot.docs.filter((document) =>
    isActiveRole(document, "super_admin"),
  );
  if (activeSuperAdmins.length > 1) {
    throw new Error("Migration stopped: multiple active super admins exist.");
  }

  const legacyCandidates = adminSnapshot.docs.filter((document) =>
    isActiveRole(document, "admin") &&
    readString(document.data().first_name).toLowerCase() === "admin",
  );
  const promoted = activeSuperAdmins.length === 1 ?
    activeSuperAdmins[0] :
    requireSingleLegacyCandidate(legacyCandidates);

  const directSnapshot = await firestore
    .collection("conversations")
    .where("type", "==", "admin_direct")
    .get();
  const adminStaff = new Map(
    adminSnapshot.docs.map((document) => [document.id, document.data()]),
  );
  const migrations = directSnapshot.docs.map((document) =>
    buildConversationMigration(document, promoted.id, adminStaff),
  );

  const targetSources = new Map<string, string[]>();
  for (const migration of migrations) {
    const sources = targetSources.get(migration.targetId) ?? [];
    sources.push(migration.source.id);
    targetSources.set(migration.targetId, sources);
  }
  for (const [targetId, sources] of targetSources) {
    if (sources.length > 1) {
      throw new Error(
        `Migration stopped: ${sources.join(", ")} conflict at ${targetId}; ` +
        "no records were overwritten.",
      );
    }
  }

  for (const migration of migrations) {
    if (migration.source.id === migration.targetId) {
      continue;
    }
    const target = await firestore
      .collection("conversations")
      .doc(migration.targetId)
      .get();
    if (target.exists) {
      throw new Error(
        `Migration stopped: ${migration.targetId} already exists; no records were overwritten.`,
      );
    }
  }

  const writer = firestore.bulkWriter();
  for (const migration of migrations) {
    const targetRef = firestore
      .collection("conversations")
      .doc(migration.targetId);
    writer.set(targetRef, migration.data);

    if (migration.source.id !== migration.targetId) {
      const messages = await migration.source.ref.collection("messages").get();
      for (const message of messages.docs) {
        writer.set(targetRef.collection("messages").doc(message.id), message.data());
      }
    }
  }
  await writer.close();

  for (const migration of migrations) {
    if (migration.source.id !== migration.targetId) {
      await firestore.recursiveDelete(migration.source.ref);
    }
  }

  const wasAlreadySuperAdmin =
    readString(promoted.data().role).toLowerCase() === "super_admin";
  if (!wasAlreadySuperAdmin) {
    await promoted.ref.set(
      {
        role: "super_admin",
        updated_at: FieldValue.serverTimestamp(),
        promoted_to_super_admin_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  const logRef = firestore
    .collection("admin_logs")
    .doc(`super_admin_promoted_${promoted.id}`);
  if (!(await logRef.get()).exists) {
    const promotedName = fullName(promoted.data());
    await logRef.set({
      log_id: logRef.id,
      action: "super_admin_promoted",
      admin_id: promoted.id,
      admin_name: promotedName,
      summary: `${promotedName} was promoted to Super Admin.`,
      target_id: promoted.id,
      target_name: promotedName,
      target_role: "super_admin",
      created_at: FieldValue.serverTimestamp(),
    });
  }

  return {
    promotedUserId: promoted.id,
    normalizedConversationCount: migrations.length,
  };
}

function requireSingleLegacyCandidate(
  candidates: QueryDocumentSnapshot[],
) {
  if (candidates.length !== 1) {
    throw new Error(
      `Migration requires exactly one active admin named admin; found ${candidates.length}.`,
    );
  }
  return candidates[0];
}

function isActiveRole(document: QueryDocumentSnapshot, role: string) {
  const data = document.data();
  return readString(data.role).toLowerCase() === role &&
    data.is_active !== false &&
    data.is_banned !== true &&
    data.is_deactivated !== true &&
    !["deactivated", "deleted"].includes(
      readString(data.account_status).toLowerCase(),
    );
}

function participantIds(document: QueryDocumentSnapshot) {
  const value = document.data().participant_ids;
  return Array.isArray(value) ?
    value.map((entry) => readString(entry)).filter(Boolean) :
    [];
}

function buildConversationMigration(
  source: QueryDocumentSnapshot,
  superAdminId: string,
  adminStaff: Map<string, Record<string, unknown>>,
) {
  const ids = [...new Set(participantIds(source))].sort();
  if (ids.length !== 2) {
    throw new Error(
      `Migration stopped: ${source.id} does not have exactly two participants.`,
    );
  }

  const data: Record<string, unknown> = {...source.data()};
  delete data.main_admin_id;
  delete data.target_admin_id;
  delete data.main_admin_name;
  delete data.target_admin_name;
  delete data.main_admin_role;
  delete data.target_admin_role;
  const roles: Record<string, string> = {};
  const names: Record<string, string> = {};
  for (const id of ids) {
    const user = adminStaff.get(id);
    const role = id === superAdminId ?
      "super_admin" :
      readString(user?.role).toLowerCase();
    if (!user || !["admin", "super_admin"].includes(role)) {
      throw new Error(
        `Migration stopped: ${source.id} references non-admin participant ${id}.`,
      );
    }
    roles[id] = role;
    names[id] = fullName(user);
  }
  const targetId = `admin_direct_${ids[0]}_${ids[1]}`;
  data.conversation_id = targetId;
  data.type = "admin_direct";
  data.participant_ids = ids;
  data.participant_names = names;
  data.participant_roles = roles;

  return {source, targetId, data};
}

function fullName(data: Record<string, unknown>) {
  const name = [readString(data.first_name), readString(data.last_name)]
    .filter(Boolean)
    .join(" ")
    .trim();
  return name || "Super Admin";
}

function readString(value: unknown) {
  return value?.toString().trim() ?? "";
}

if (require.main === module) {
  void runSuperAdminMigration()
    .then((result) => {
      console.log(
        `Super admin migration complete for ${result.promotedUserId}; ` +
        `${result.normalizedConversationCount} direct conversation(s) normalized.`,
      );
    })
    .catch((error: unknown) => {
      console.error(error);
      process.exitCode = 1;
    });
}
