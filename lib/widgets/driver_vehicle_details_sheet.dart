import 'package:flutter/material.dart';

import 'firebase_storage_image.dart';
import 'maps/map_text_styles.dart';
import 'passenger_widgets/passenger_ui.dart';

class DriverVehicleInfoCard extends StatelessWidget {
  final String? vehicleType;
  final String? tricycleColor;
  final String? plateNumber;
  final String? tricycleFrontUrl;
  final String? tricycleBackUrl;

  const DriverVehicleInfoCard({
    super.key,
    this.vehicleType,
    this.tricycleColor,
    this.plateNumber,
    this.tricycleFrontUrl,
    this.tricycleBackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.local_taxi_rounded,
                size: 20,
                color: PassengerUi.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Tricycle & Vehicle Identity',
                style: MapTextStyles.title.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SpecRow(
            label: 'Vehicle Type',
            value: (vehicleType == null || vehicleType!.trim().isEmpty)
                ? 'Not specified'
                : vehicleType!.trim(),
          ),
          const SizedBox(height: 8),
          _SpecRow(
            label: 'Tricycle Color',
            value: (tricycleColor == null || tricycleColor!.trim().isEmpty)
                ? 'Not specified'
                : tricycleColor!.trim(),
          ),
          const SizedBox(height: 8),
          _SpecRow(
            label: 'Plate / Franchise No.',
            value: (plateNumber == null || plateNumber!.trim().isEmpty)
                ? 'Not specified'
                : plateNumber!.trim(),
          ),
          const SizedBox(height: 16),
          Text(
            'Vehicle Photos',
            style: MapTextStyles.title.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _PhotoPreviewTile(
                  label: 'Front View',
                  imageUrl: tricycleFrontUrl,
                  fallbackText: 'Front photo not available',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoPreviewTile(
                  label: 'Back View',
                  imageUrl: tricycleBackUrl,
                  fallbackText: 'Back photo not available',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: MapTextStyles.body.copyWith(color: PassengerUi.body)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: MapTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: PassengerUi.title),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PhotoPreviewTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final String fallbackText;

  const _PhotoPreviewTile({
    required this.label,
    required this.imageUrl,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: MapTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: PassengerUi.title),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 110,
            width: double.infinity,
            color: PassengerUi.mutedSurface,
            child: hasUrl
                ? FirebaseStorageImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fallback: _FallbackView(fallbackText: fallbackText),
                  )
                : _FallbackView(fallbackText: fallbackText),
          ),
        ),
      ],
    );
  }
}

class _FallbackView extends StatelessWidget {
  final String fallbackText;
  const _FallbackView({required this.fallbackText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.image_not_supported_outlined,
            size: 24,
            color: PassengerUi.body,
          ),
          const SizedBox(height: 6),
          Text(
            fallbackText,
            textAlign: TextAlign.center,
            style: MapTextStyles.body.copyWith(
              fontSize: 11.5,
              color: PassengerUi.body,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDriverVehicleDetailsSheet({
  required BuildContext context,
  required String driverName,
  required String? profileImageUrl,
  required bool isVerified,
  required double rating,
  required int reviewCount,
  String? vehicleType,
  String? tricycleColor,
  String? plateNumber,
  String? tricycleFrontUrl,
  String? tricycleBackUrl,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: PassengerUi.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PassengerUi.mutedSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Driver & Vehicle Details', style: MapTextStyles.title.copyWith(fontSize: 18)),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: PassengerUi.body),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PassengerSurfaceCard(
                child: Row(
                  children: <Widget>[
                    ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: FirebaseStorageImage(
                          imageUrl: profileImageUrl,
                          fallback: Container(
                            color: PassengerUi.blueSoft,
                            alignment: Alignment.center,
                            child: Text(
                              driverName.isEmpty ? 'D' : driverName[0].toUpperCase(),
                              style: TextStyle(
                                color: PassengerUi.accentBlue,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  driverName.isEmpty ? 'Verified Driver' : driverName,
                                  style: MapTextStyles.title.copyWith(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...<Widget>[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: PassengerUi.successText,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Icon(Icons.star_rounded, size: 18, color: PassengerUi.highlightAmber),
                              const SizedBox(width: 4),
                              Text(
                                reviewCount == 0 ? 'No ratings yet' : rating.toStringAsFixed(1),
                                style: MapTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (reviewCount > 0) ...<Widget>[
                                const SizedBox(width: 4),
                                Text(
                                  '($reviewCount review${reviewCount == 1 ? '' : 's'})',
                                  style: MapTextStyles.body.copyWith(color: PassengerUi.body),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DriverVehicleInfoCard(
                vehicleType: vehicleType,
                tricycleColor: tricycleColor,
                plateNumber: plateNumber,
                tricycleFrontUrl: tricycleFrontUrl,
                tricycleBackUrl: tricycleBackUrl,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PassengerUi.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
