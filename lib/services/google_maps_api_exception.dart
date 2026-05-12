class GoogleMapsApiException implements Exception {
  final String message;
  final String? status;

  const GoogleMapsApiException(this.message, {this.status});

  @override
  String toString() {
    if (status == null || status!.isEmpty) {
      return message;
    }

    return '$message ($status)';
  }
}
