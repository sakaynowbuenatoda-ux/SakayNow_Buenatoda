import 'package:flutter/material.dart';

import '../core/auth/registration_service.dart';
import 'firebase_storage_image.dart';
import 'passenger_widgets/passenger_ui.dart';
import 'registration_image_preview.dart';

enum VerificationPreviewState { empty, loading, unavailable }

class PassengerVerificationUploadCard extends StatelessWidget {
  final String documentKey;
  final String title;
  final String subtitle;
  final String buttonText;
  final String emptyTitle;
  final String emptyMessage;
  final IconData buttonIcon;
  final IconData emptyIcon;
  final VoidCallback? onTap;
  final RegistrationImageSelection? selectedFile;
  final String? uploadedImageUrl;
  final BoxFit previewFit;

  const PassengerVerificationUploadCard({
    super.key,
    required this.documentKey,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.buttonIcon,
    required this.emptyIcon,
    required this.onTap,
    required this.selectedFile,
    required this.uploadedImageUrl,
    this.previewFit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassengerUi.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PassengerUi.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: PassengerUi.body),
          ),
          const SizedBox(height: 14),
          PassengerVerificationDocumentPreview(
            key: Key('verification-$documentKey-preview'),
            selectedFile: selectedFile,
            uploadedImageUrl: uploadedImageUrl,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            emptyIcon: emptyIcon,
            fit: previewFit,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('verification-$documentKey-upload-button'),
              onPressed: onTap,
              icon: Icon(buttonIcon),
              label: Text(buttonText),
              style: OutlinedButton.styleFrom(
                foregroundColor: PassengerUi.primary,
                side: BorderSide(color: PassengerUi.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PassengerVerificationDocumentPreview extends StatelessWidget {
  static const double previewHeight = 180;

  final RegistrationImageSelection? selectedFile;
  final String? uploadedImageUrl;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final BoxFit fit;

  const PassengerVerificationDocumentPreview({
    super.key,
    required this.selectedFile,
    required this.uploadedImageUrl,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final source = uploadedImageUrl?.trim();

    return Container(
      height: previewHeight,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: selectedFile != null
          ? RegistrationImagePreview(
              selection: selectedFile!,
              height: previewHeight,
              borderRadius: 0,
              fit: fit,
            )
          : source == null || source.isEmpty || source == 'null'
          ? VerificationDocumentPreviewPlaceholder(
              state: VerificationPreviewState.empty,
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            )
          : FirebaseStorageImage(
              imageUrl: source,
              width: double.infinity,
              height: previewHeight,
              fit: fit,
              fallback: const VerificationDocumentPreviewPlaceholder(
                state: VerificationPreviewState.unavailable,
                icon: Icons.cloud_off_outlined,
                title: 'Preview unavailable',
                message: 'Check your internet connection and try again.',
              ),
              loading: const VerificationDocumentPreviewPlaceholder(
                state: VerificationPreviewState.loading,
                icon: Icons.image_search_outlined,
                title: 'Loading uploaded photo',
                message: 'Your saved document preview will appear here.',
              ),
              errorFallback: const VerificationDocumentPreviewPlaceholder(
                state: VerificationPreviewState.unavailable,
                icon: Icons.cloud_off_outlined,
                title: 'Preview unavailable',
                message: 'Check your internet connection and try again.',
              ),
            ),
    );
  }
}

class VerificationDocumentPreviewPlaceholder extends StatelessWidget {
  final VerificationPreviewState state;
  final IconData icon;
  final String title;
  final String message;

  const VerificationDocumentPreviewPlaceholder({
    super.key,
    required this.state,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: switch (state) {
        VerificationPreviewState.empty => 'No verification photo uploaded',
        VerificationPreviewState.loading => 'Loading verification photo',
        VerificationPreviewState.unavailable =>
          'Verification photo unavailable',
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: PassengerUi.body),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PassengerUi.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PassengerUi.body,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
