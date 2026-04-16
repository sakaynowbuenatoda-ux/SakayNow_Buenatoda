import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerBookRidePage extends StatefulWidget {
  const PassengerBookRidePage({super.key});

  @override
  State<PassengerBookRidePage> createState() => _PassengerBookRidePageState();
}

class _PassengerBookRidePageState extends State<PassengerBookRidePage> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _showDrivers = false;

  final List<_PassengerDriverOption> _drivers = const <_PassengerDriverOption>[
    _PassengerDriverOption(
      name: 'Juan Dela Cruz',
      unitCode: 'Trike 014',
      eta: '2 mins away',
      rating: 4.9,
    ),
    _PassengerDriverOption(
      name: 'Pedro Garcia',
      unitCode: 'Trike 022',
      eta: '4 mins away',
      rating: 4.8,
    ),
    _PassengerDriverOption(
      name: 'Rogelio Santos',
      unitCode: 'Trike 031',
      eta: '5 mins away',
      rating: 4.7,
    ),
  ];

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.background,
        elevation: 0,
        surfaceTintColor: PassengerUi.background,
        title: Text(
          'Book a Ride',
          style: GoogleFonts.archivoBlack(
            color: PassengerUi.title,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _PassengerRideMapCard(),
              const SizedBox(height: 16),
              _PassengerLocationField(
                controller: _pickupController,
                label: 'Pickup location',
                icon: Icons.my_location_rounded,
                iconColor: PassengerUi.secondary,
              ),
              const SizedBox(height: 12),
              _PassengerLocationField(
                controller: _destinationController,
                label: 'Drop-off location',
                icon: Icons.location_on_rounded,
                iconColor: PassengerUi.primary,
              ),
              const SizedBox(height: 16),
              Row(
                children: PassengerMockData.quickDestinations
                    .asMap()
                    .entries
                    .map(
                      (MapEntry<int, PassengerQuickDestination> entry) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: entry.key == PassengerMockData.quickDestinations.length - 1
                                ? 0
                                : 10,
                          ),
                          child: _PassengerSavedLocationButton(
                            destination: entry.value,
                            onTap: () => _applyDestination(entry.value),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              PassengerSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Ride Notes', style: PassengerUi.cardTitle),
                    SizedBox(height: 8),
                    Text(
                      'Geofencing, verified drivers, and transparent local fares will be connected to live Firebase data next.',
                      style: PassengerUi.bodyText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _findDrivers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PassengerUi.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Find Available Drivers',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (_showDrivers) ...<Widget>[
                const SizedBox(height: 22),
                const PassengerSectionHeader(title: 'Nearby Drivers'),
                const SizedBox(height: 12),
                ..._drivers.asMap().entries.map(
                  (MapEntry<int, _PassengerDriverOption> entry) => Padding(
                    padding: EdgeInsets.only(bottom: entry.key == _drivers.length - 1 ? 0 : 12),
                    child: _PassengerDriverCard(
                      driver: entry.value,
                      onTap: () => _selectDriver(entry.value),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _applyDestination(PassengerQuickDestination destination) {
    setState(() {
      _destinationController.text = destination.address;
    });
  }

  void _findDrivers() {
    if (_pickupController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both pickup and drop-off locations first.'),
        ),
      );
      return;
    }

    setState(() {
      _showDrivers = true;
    });
  }

  void _selectDriver(_PassengerDriverOption driver) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${driver.name}. Booking confirmation is the next step.'),
      ),
    );
  }
}

class _PassengerRideMapCard extends StatelessWidget {
  const _PassengerRideMapCard();

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFDFF2FF),
              Color(0xFFE9F9EE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.map_rounded, size: 48, color: PassengerUi.primary),
              SizedBox(height: 8),
              Text('Geofencing coverage', style: PassengerUi.cardTitle),
              SizedBox(height: 4),
              Text(
                'Buenavista, Bohol',
                style: PassengerUi.bodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerLocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _PassengerLocationField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                labelStyle: PassengerUi.bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerSavedLocationButton extends StatelessWidget {
  final PassengerQuickDestination destination;
  final VoidCallback onTap;

  const _PassengerSavedLocationButton({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: PassengerUi.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
      child: Column(
        children: <Widget>[
          Icon(destination.icon, color: destination.accentColor),
          const SizedBox(height: 6),
          Text(
            destination.label,
            style: PassengerUi.valueText.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PassengerDriverCard extends StatelessWidget {
  final _PassengerDriverOption driver;
  final VoidCallback onTap;

  const _PassengerDriverCard({
    required this.driver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: PassengerSurfaceCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                driver.name.substring(0, 1),
                style: PassengerUi.cardTitle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(driver.name, style: PassengerUi.cardTitle),
                  const SizedBox(height: 4),
                  Text(driver.unitCode, style: PassengerUi.bodyText),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.access_time_rounded, size: 16, color: PassengerUi.secondary),
                      const SizedBox(width: 4),
                      Text(driver.eta, style: PassengerUi.bodyText.copyWith(fontSize: 13)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF4B400)),
                      const SizedBox(width: 4),
                      Text(
                        driver.rating.toStringAsFixed(1),
                        style: PassengerUi.valueText.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: PassengerUi.body),
          ],
        ),
      ),
    );
  }
}

class _PassengerDriverOption {
  final String name;
  final String unitCode;
  final String eta;
  final double rating;

  const _PassengerDriverOption({
    required this.name,
    required this.unitCode,
    required this.eta,
    required this.rating,
  });
}
