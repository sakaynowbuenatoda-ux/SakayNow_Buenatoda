class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final formatting =
        json['structured_formatting'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    return PlacePrediction(
      placeId: (json['place_id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      mainText: (formatting['main_text'] ?? json['description'] ?? '')
          .toString(),
      secondaryText: (formatting['secondary_text'] ?? '').toString(),
    );
  }
}
