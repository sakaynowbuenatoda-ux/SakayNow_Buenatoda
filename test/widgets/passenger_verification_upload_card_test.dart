import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/widgets/firebase_storage_image.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_verification_upload_card.dart';

void main() {
  testWidgets('shows the empty ID placeholder above the upload button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassengerVerificationUploadCard(
            documentKey: 'id',
            title: 'School or Government ID',
            subtitle: 'Upload a clear ID.',
            buttonText: 'Choose ID Photo',
            emptyTitle: 'No ID uploaded yet',
            emptyMessage: 'Choose a clear ID photo to preview it here.',
            buttonIcon: Icons.upload_file_rounded,
            emptyIcon: Icons.badge_outlined,
            onTap: () {},
            selectedFile: null,
            uploadedImageUrl: null,
          ),
        ),
      ),
    );

    expect(find.text('No ID uploaded yet'), findsOneWidget);
    expect(
      find.text('Choose a clear ID photo to preview it here.'),
      findsOneWidget,
    );

    final previewTop = tester
        .getTopLeft(find.byKey(const Key('verification-id-preview')))
        .dy;
    final buttonTop = tester
        .getTopLeft(find.byKey(const Key('verification-id-upload-button')))
        .dy;
    expect(previewTop, lessThan(buttonTop));
  });

  testWidgets('provides a clear unavailable and offline placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerificationDocumentPreviewPlaceholder(
            state: VerificationPreviewState.unavailable,
            icon: Icons.cloud_off_outlined,
            title: 'Preview unavailable',
            message: 'Check your internet connection and try again.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Verification photo unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a dedicated empty selfie placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PassengerVerificationDocumentPreview(
            selectedFile: null,
            uploadedImageUrl: null,
            emptyTitle: 'No selfie uploaded yet',
            emptyMessage: 'Capture a selfie to preview it here.',
            emptyIcon: Icons.person_outline_rounded,
          ),
        ),
      ),
    );

    expect(find.text('No selfie uploaded yet'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('renders a saved document URL in the preview area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PassengerVerificationDocumentPreview(
            selectedFile: null,
            uploadedImageUrl: 'https://example.test/id.jpg',
            emptyTitle: 'No ID uploaded yet',
            emptyMessage: 'Choose an ID photo.',
            emptyIcon: Icons.badge_outlined,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    final image = tester.widget<FirebaseStorageImage>(
      find.byType(FirebaseStorageImage),
    );
    expect(image.imageUrl, 'https://example.test/id.jpg');
    expect(image.fit, BoxFit.contain);
    expect(find.text('No ID uploaded yet'), findsNothing);
    expect(find.text('Loading uploaded photo'), findsOneWidget);
  });
}
