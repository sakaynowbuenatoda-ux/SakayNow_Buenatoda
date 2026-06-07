class ChatParticipantProfile {
  final String userId;
  final String displayName;
  final String role;
  final String? profileImageUrl;

  const ChatParticipantProfile({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.profileImageUrl,
  });

  factory ChatParticipantProfile.fromUserData({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final firstName = (data['first_name'] ?? '').toString().trim();
    final lastName = (data['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    final role = (data['role'] ?? '').toString().trim().toLowerCase();

    return ChatParticipantProfile(
      userId: userId,
      displayName: fullName.isEmpty ? 'SakayNow User' : fullName,
      role: role.isEmpty ? 'passenger' : role,
      profileImageUrl: _readOptional(
        data['profile_picture_url'] ??
            data['profile_image_url'] ??
            data['selfie_url'],
      ),
    );
  }

  static String? _readOptional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}
