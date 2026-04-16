import 'package:flutter/material.dart';

class BookRidePage extends StatefulWidget {
  const BookRidePage({super.key});

  @override
  State<BookRidePage> createState() => _BookRidePageState();
}

class _BookRidePageState extends State<BookRidePage> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  int _step = 1; // 1 = destination form, 2 = select driver

  final List<SavedLocation> _savedLocations = [
    const SavedLocation(
      title: 'Home',
      address: '123 Main Street, Barangay Poblacion, Buenavista, Bohol',
    ),
    const SavedLocation(
      title: 'School',
      address: 'Buenavista National High School, Buenavista, Bohol',
    ),
    const SavedLocation(
      title: 'Work',
      address: 'Municipal Hall, Buenavista, Bohol',
    ),
  ];

  final List<DriverModel> _drivers = [
    const DriverModel(
      id: '1',
      initials: 'JDC',
      name: 'Juan Dela Cruz',
      rating: 4.9,
      trips: 523,
      motorcycle: 'Honda TMX 155',
      plateNumber: 'ABC 1234',
      etaText: '2 mins away',
    ),
    const DriverModel(
      id: '2',
      initials: 'PG',
      name: 'Pedro Garcia',
      rating: 4.7,
      trips: 387,
      motorcycle: 'Suzuki Raider 150',
      plateNumber: 'XYZ 5678',
      etaText: '2 mins away',
    ),
  ];

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step == 2) {
      setState(() => _step = 1);
      return;
    }
    Navigator.pop(context);
  }

  void _useCurrentLocation() {
    setState(() {
      _pickupController.text = 'Current Location';
    });
  }

  void _selectSavedLocation(SavedLocation location) {
    setState(() {
      _destinationController.text = location.title;
    });
  }

  void _findDrivers() {
    if (_pickupController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both pickup and destination.'),
        ),
      );
      return;
    }

    setState(() {
      _step = 2;
    });
  }

  void _selectDriver(DriverModel driver) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected ${driver.name}')),
    );

    // TODO:
    // 1. Save selected driver
    // 2. Create booking record in Firestore
    // 3. Navigate to ride confirmation / tracking page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _BookRideHeader(
              title: 'Book a Ride',
              subtitle: _step == 1 ? 'Enter your destination' : 'Select a driver',
              onBackTap: _goBack,
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E7)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: _step == 1 ? _buildStepOne() : _buildStepTwo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MapPlaceholderCard(),
        const SizedBox(height: 14),

        _LocationFieldTile(
          icon: Icons.near_me_rounded,
          iconColor: Colors.green,
          hintText: 'Pickup location',
          controller: _pickupController,
        ),
        const SizedBox(height: 12),

        _LocationFieldTile(
          icon: Icons.location_on_outlined,
          iconColor: Colors.red,
          hintText: 'Where to?',
          controller: _destinationController,
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(Icons.navigation_outlined, size: 18, color: Colors.black),
          label: const Text(
            'Use Current Location',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: Color(0xFFD8D8DD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Saved Locations',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        ..._savedLocations.map(
          (location) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SavedLocationCard(
              location: location,
              onTap: () => _selectSavedLocation(location),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _findDrivers,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF020426),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Find Available Drivers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvailableDriversBanner(count: _drivers.length),
        const SizedBox(height: 16),

        ..._drivers.map(
          (driver) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DriverCard(
              driver: driver,
              onTap: () => _selectDriver(driver),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookRideHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBackTap;

  const _BookRideHeader({
    required this.title,
    required this.subtitle,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholderCard extends StatelessWidget {
  const _MapPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F4),
        border: Border.all(color: const Color(0xFFD6D6DB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 54,
              color: Colors.blueGrey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Map with geofencing area',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Buenavista, Bohol coverage',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationFieldTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String hintText;
  final TextEditingController controller;

  const _LocationFieldTile({
    required this.icon,
    required this.iconColor,
    required this.hintText,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableDriversBanner extends StatelessWidget {
  final int count;

  const _AvailableDriversBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDD4FF)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Available drivers nearby:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF020426),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SavedLocationCard extends StatelessWidget {
  final SavedLocation location;
  final VoidCallback onTap;

  const SavedLocationCard({
    super.key,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F1FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF2D6BFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverCard extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback onTap;

  const DriverCard({
    super.key,
    required this.driver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E1E6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDF6E5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  driver.initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D7A45),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driver.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F9),
                            border: Border.all(color: const Color(0xFFE1E1E6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${driver.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          driver.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '•',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        Text(
                          '${driver.trips} trips',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      driver.motorcycle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      driver.plateNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_outlined,
                          size: 15,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driver.etaText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedLocation {
  final String title;
  final String address;

  const SavedLocation({
    required this.title,
    required this.address,
  });
}

class DriverModel {
  final String id;
  final String initials;
  final String name;
  final double rating;
  final int trips;
  final String motorcycle;
  final String plateNumber;
  final String etaText;

  const DriverModel({
    required this.id,
    required this.initials,
    required this.name,
    required this.rating,
    required this.trips,
    required this.motorcycle,
    required this.plateNumber,
    required this.etaText,
  });
}