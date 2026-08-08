import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/admin/admin_models.dart';

void main() {
  test('admin booking record exposes commission and payout totals', () async {
    final firestore = FakeFirebaseFirestore();
    final reference = firestore.collection('bookings').doc('booking-1');
    await reference.set(<String, dynamic>{
      'booking_id': 'booking-1',
      'passenger_id': 'passenger-1',
      'driver_id': 'driver-1',
      'status': 'completed',
      'pickup_location': 'Pickup',
      'dropoff_location': 'Drop-off',
      'gross_fare': 100,
      'commission_rate': 0.10,
      'commission_amount': 10,
      'driver_net_earnings': 90,
      'driver_payout_status': 'pending',
      'timestamp': Timestamp.now(),
      'completed_at': Timestamp.now(),
    });

    final record = AdminBookingRecord.fromDocument(await reference.get());

    expect(record.grossFareAmount, 100);
    expect(record.commissionRate, 0.10);
    expect(record.commissionRateLabel, '10%');
    expect(record.commissionAmount, 10);
    expect(record.driverNetEarnings, 90);
    expect(record.driverPayoutStatusLabel, 'Payout pending');
    expect(record.completedAt, isNotNull);
  });
}
