bool isVerifiedAccountData(Map<String, dynamic> data) {
  return _readFlag(data['is_verified']) ||
      _readFlag(data['isVerified']) ||
      _readFlag(data['isVerrified']);
}

bool _readFlag(Object? value) {
  if (value is bool) {
    return value;
  }

  return value?.toString().trim().toLowerCase() == 'true';
}
