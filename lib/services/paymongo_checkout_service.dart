import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/passenger_payment_method.dart';

class PayMongoCheckoutSession {
  final String sessionId;
  final String checkoutUrl;
  final String paymentStatus;

  const PayMongoCheckoutSession({
    required this.sessionId,
    required this.checkoutUrl,
    required this.paymentStatus,
  });

  factory PayMongoCheckoutSession.fromMap(Map<Object?, Object?> data) {
    return PayMongoCheckoutSession(
      sessionId: (data['session_id'] ?? '').toString(),
      checkoutUrl: (data['checkout_url'] ?? '').toString(),
      paymentStatus: (data['payment_status'] ?? 'checkout_pending').toString(),
    );
  }
}

class PayMongoCheckoutService {
  PayMongoCheckoutService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PayMongoCheckoutSession> createCheckoutSession({
    required String bookingId,
    required PassengerPaymentMethod paymentMethod,
  }) async {
    final payMongoType = paymentMethod.payMongoPaymentMethodType;
    if (payMongoType == null) {
      throw ArgumentError('PayMongo checkout requires a cashless method.');
    }

    final callable = _functions.httpsCallable('createPayMongoCheckoutSession');
    final result = await callable.call<Map<Object?, Object?>>(<String, Object?>{
      'booking_id': bookingId,
      'payment_method_type': payMongoType,
      'payment_method_id': paymentMethod.id,
    });

    return PayMongoCheckoutSession.fromMap(result.data);
  }

  Future<void> openCheckoutUrl(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || !uri.hasScheme) {
      throw StateError('PayMongo checkout URL is not valid.');
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Unable to open PayMongo checkout.');
    }
  }
}
