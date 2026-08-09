import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;
  late String migrationSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
    migrationSource = File(
      'functions/src/migrate_super_admin.ts',
    ).readAsStringSync();
  });

  test('admin account lifecycle is restricted to explicit super admins', () {
    expect(functionsSource, contains('function isSuperAdmin('));
    expect(
      functionsSource,
      contains('normalizedUserRole(user) === "super_admin"'),
    );
    expect(functionsSource, isNot(contains('hasMainAdminName')));
    expect(functionsSource, isNot(contains('isMainAdmin')));
  });

  test('admin direct conversations are created by a secured callable', () {
    expect(
      functionsSource,
      contains('export const ensureAdminDirectConversation = onCall('),
    );
    expect(functionsSource, contains('if (!targetSnapshot.exists'));
    expect(functionsSource, contains('!isAdminStaff(requester)'));
    expect(functionsSource, contains('[requesterId, targetAdminId].sort()'));
    expect(functionsSource, contains('participant_roles: participantRoles'));
  });

  test('notifications include regular and super admins', () {
    expect(
      functionsSource,
      contains('.where("role", "in", ["admin", "super_admin"])'),
    );
    expect(functionsSource, contains('isAdminStaffRole(params.senderRole)'));
  });

  test('migration fails closed and uses deterministic audit data', () {
    expect(migrationSource, contains('multiple active super admins exist'));
    expect(
      migrationSource,
      contains('requires exactly one active admin named admin'),
    );
    expect(
      migrationSource,
      contains('already exists; no records were overwritten'),
    );
    expect(migrationSource, contains(r'super_admin_promoted_${promoted.id}'));
    expect(migrationSource, contains('firestore.recursiveDelete'));
    expect(migrationSource, contains('data.participant_names = names'));
    expect(migrationSource, contains('data.participant_roles = roles'));
    expect(
      migrationSource,
      isNot(contains('data.updated_at = FieldValue.serverTimestamp()')),
    );
  });
}
