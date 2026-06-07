import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/profile_picture_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

Future<ImageSource?> showProfilePictureSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: PassengerUi.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PassengerUi.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              _ImageSourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              _ImageSourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Camera',
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showProfilePictureConfirmationDialog(
  BuildContext context, {
  required ProfilePictureSelection selection,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        title: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PassengerUi.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                color: PassengerUi.accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update profile picture',
                style: PassengerUi.cardTitle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PassengerUi.border, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  selection.bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) {
                    return Container(
                      color: PassengerUi.blueSoft,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: PassengerUi.accentBlue,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Are you sure you want to use this photo?',
              style: PassengerUi.valueText,
            ),
            const SizedBox(height: 8),
            Text(
              'After confirming, your profile picture can only be changed again after 7 days.',
              style: PassengerUi.bodyText.copyWith(height: 1.35),
            ),
          ],
        ),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Confirm'),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: PassengerUi.blueSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: PassengerUi.accentBlue),
      ),
      title: Text(title, style: PassengerUi.valueText),
      onTap: onTap,
    );
  }
}
