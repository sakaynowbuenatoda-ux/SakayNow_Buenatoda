import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/login_activity_service.dart';

void main() {
  test('records and returns successful logins newest first', () async {
    final firestore = FakeFirebaseFirestore();
    final service = LoginActivityService(
      firestore: firestore,
      platformProvider: () => 'android',
    );

    await service.recordSuccessfulLogin(userId: 'user-1');

    final snapshot = await firestore
        .collection('users')
        .doc('user-1')
        .collection('login_activity')
        .get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.data()['user_id'], 'user-1');
    expect(snapshot.docs.single.data()['platform'], 'android');
    expect(snapshot.docs.single.data()['auth_method'], 'password');
    expect(snapshot.docs.single.data()['signed_in_at'], isNotNull);

    final history = await service.watchLoginHistory(userId: 'user-1').first;
    expect(history, hasLength(1));
    expect(history.single.userId, 'user-1');
    expect(history.single.platformLabel, 'Android device');
    expect(history.single.authMethodLabel, 'Email and password');
    expect(history.single.signedInAt, isNotNull);
  });
}
