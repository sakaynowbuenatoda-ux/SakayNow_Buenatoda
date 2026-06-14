import 'package:flutter/material.dart';

import '../../models/fare_settings.dart';
import '../../pages/passenger/passenger_data.dart';
import '../../services/fare_settings_service.dart';
import 'passenger_ui.dart';

class PassengerFareInformationCard extends StatefulWidget {
  final List<PassengerFareDetail>? fareDetails;
  final FareSettingsService? fareSettingsService;

  const PassengerFareInformationCard({
    super.key,
    this.fareDetails,
    this.fareSettingsService,
  });

  @override
  State<PassengerFareInformationCard> createState() =>
      _PassengerFareInformationCardState();
}

class _PassengerFareInformationCardState
    extends State<PassengerFareInformationCard> {
  Stream<FareSettings>? _fareSettingsStream;

  @override
  void initState() {
    super.initState();
    _configureFareSettingsStream();
  }

  @override
  void didUpdateWidget(PassengerFareInformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fareDetails != widget.fareDetails ||
        oldWidget.fareSettingsService != widget.fareSettingsService) {
      _configureFareSettingsStream();
    }
  }

  void _configureFareSettingsStream() {
    if (widget.fareDetails != null) {
      _fareSettingsStream = null;
      return;
    }

    final fareSettingsService =
        widget.fareSettingsService ?? FareSettingsService();
    _fareSettingsStream = fareSettingsService.watchSettings();
  }

  @override
  Widget build(BuildContext context) {
    final providedFareDetails = widget.fareDetails;
    if (providedFareDetails != null) {
      return _buildCard(fareDetails: providedFareDetails);
    }

    return StreamBuilder<FareSettings>(
      stream: _fareSettingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? FareSettings.defaults;
        final statusMessage = snapshot.hasError
            ? 'Unable to load the latest fare guide. Default fare values are shown for now.'
            : snapshot.hasData
            ? null
            : 'Loading latest fare guide...';

        return _buildCard(
          fareDetails: _fareDetailsFor(settings),
          statusMessage: statusMessage,
          statusIcon: snapshot.hasError
              ? Icons.error_outline_rounded
              : Icons.sync_rounded,
        );
      },
    );
  }

  Widget _buildCard({
    required List<PassengerFareDetail> fareDetails,
    String? statusMessage,
    IconData statusIcon = Icons.info_outline_rounded,
  }) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Fare Information', style: PassengerUi.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Transparent local fares, student-friendly pricing, and cashless options for safer travel.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 14),
          ...fareDetails.asMap().entries.map(
            (MapEntry<int, PassengerFareDetail> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == fareDetails.length - 1 ? 0 : 10,
              ),
              child: PassengerFareInformationRow(detail: entry.value),
            ),
          ),
          if (statusMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(statusIcon, size: 16, color: PassengerUi.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: PassengerUi.bodyText.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<PassengerFareDetail> _fareDetailsFor(FareSettings settings) {
    return <PassengerFareDetail>[
      PassengerFareDetail(
        label: '1 barangay fare',
        value: settings.oneBarangayFareLabel,
      ),
      PassengerFareDetail(
        label: 'Up to 5 barangays',
        value: settings.buenavistaFiveBarangayFareLabel,
      ),
      PassengerFareDetail(
        label: 'Extended route fare',
        value: settings.outsideBuenavistaRangeLabel,
      ),
      PassengerFareDetail(
        label: 'Student discount',
        value: settings.studentDiscountLabel,
        valueColor: PassengerUi.successText,
      ),
      const PassengerFareDetail(
        label: 'Cashless payment',
        value: 'Xendit checkout',
      ),
    ];
  }
}

class PassengerFareInformationRow extends StatelessWidget {
  final PassengerFareDetail detail;

  const PassengerFareInformationRow({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8, color: PassengerUi.accentBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: PassengerUi.bodyText,
              children: <InlineSpan>[
                TextSpan(text: '${detail.label}: '),
                TextSpan(
                  text: detail.value,
                  style: PassengerUi.valueText.copyWith(
                    color: detail.valueColor ?? PassengerUi.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
