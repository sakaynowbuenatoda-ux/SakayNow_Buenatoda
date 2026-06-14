import 'package:cloud_functions/cloud_functions.dart';

class AdminAccountService {
  AdminAccountService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<String> createAdminAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String age,
    required String gender,
  }) async {
    final callable = _functions.httpsCallable('createAdminAccount');
    final result = await callable.call<Map<String, dynamic>>({
      'email': email.trim(),
      'password': password.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'age': age.trim(),
      'gender': gender.trim(),
    });
    final data = result.data;
    final userId = data['user_id']?.toString().trim() ?? '';

    if (userId.isEmpty) {
      throw StateError(
        'Admin account was created but no user ID was returned.',
      );
    }

    return userId;
  }

  Future<void> deactivateAdminAccount({required String adminUserId}) async {
    final callable = _functions.httpsCallable('deactivateAdminAccount');
    await callable.call<Map<String, dynamic>>({
      'admin_user_id': adminUserId.trim(),
    });
  }

  Future<void> restoreAdminAccount({required String adminUserId}) async {
    final callable = _functions.httpsCallable('restoreAdminAccount');
    await callable.call<Map<String, dynamic>>({
      'admin_user_id': adminUserId.trim(),
    });
  }
}
