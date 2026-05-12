import 'ride_location.dart';

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  RideLocation toRideLocation() {
    return RideLocation(
      address: formattedAddress.isNotEmpty ? formattedAddress : name,
      name: name,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry =
        json['geometry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final location =
        geometry['location'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return PlaceDetails(
      placeId: (json['place_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      formattedAddress: (json['formatted_address'] ?? '').toString(),
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}
