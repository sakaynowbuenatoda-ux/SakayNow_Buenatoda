import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/admin/widgets/admin_ui.dart';

void main() {
  testWidgets('shared admin section card keeps a clear divided hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: AdminSectionCard(
              title: 'Account Metrics',
              subtitle: 'Current account indicators.',
              child: const Text('Section content'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Account Metrics'), findsOneWidget);
    expect(find.text('Current account indicators.'), findsOneWidget);
    expect(find.text('Section content'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('count page header stays aligned at compact width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: AdminCountPageHeader(
              title: 'Document Reviews',
              subtitle: 'Review pending document updates.',
              count: '12',
              countLabel: 'Pending',
              accentColor: AdminUi.warning,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Document Reviews'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('secondary admin pages use the shared detail app bar', () {
    final adminDirectory = Directory('lib/pages/admin');
    final pageSources = adminDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_page.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(pageSources, isNot(contains('appBar: AppBar(')));
    expect(pageSources, contains('appBar: AdminDetailAppBar('));
  });
}
