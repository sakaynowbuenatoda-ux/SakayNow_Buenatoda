class DistanceMatrixResult {
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;

  const DistanceMatrixResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
  });

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'distance_text': distanceText,
      'duration_text': durationText,
    };
  }
}
