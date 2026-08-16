import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/conversation_actions_dialog.dart';

void main() {
  testWidgets('returns delete from the conversation options dialog', (
    tester,
  ) async {
    ConversationAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedAction = await showConversationActionsDialog(
                  context,
                  conversationTitle: 'Cinnamon',
                );
              },
              child: const Text('Show options'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show options'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation options'), findsOneWidget);
    expect(find.text('Cinnamon'), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('conversation_action_delete')),
    );
    await tester.pumpAndSettle();

    expect(selectedAction, ConversationAction.delete);
  });
}
