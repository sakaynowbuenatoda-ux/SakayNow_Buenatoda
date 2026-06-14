import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/passenger_payment_method.dart';

class XenditCheckoutSession {
  final String sessionId;
  final String checkoutUrl;
  final String paymentStatus;

  const XenditCheckoutSession({
    required this.sessionId,
    required this.checkoutUrl,
    required this.paymentStatus,
  });

  factory XenditCheckoutSession.fromMap(Map<Object?, Object?> data) {
    return XenditCheckoutSession(
      sessionId: (data['session_id'] ?? '').toString(),
      checkoutUrl: (data['checkout_url'] ?? '').toString(),
      paymentStatus: (data['payment_status'] ?? 'checkout_pending').toString(),
    );
  }
}

class XenditCheckoutService {
  XenditCheckoutService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<XenditCheckoutSession> createCheckoutSession({
    required String bookingId,
    required PassengerPaymentMethod paymentMethod,
  }) async {
    final xenditType = paymentMethod.xenditPaymentMethodType;
    if (xenditType == null) {
      throw ArgumentError('Xendit checkout requires a cashless method.');
    }

    return createCheckoutSessionForPaymentType(
      bookingId: bookingId,
      paymentMethodType: xenditType,
      paymentMethodId: paymentMethod.id,
    );
  }

  Future<XenditCheckoutSession> createCheckoutSessionForPaymentType({
    required String bookingId,
    required String paymentMethodType,
    String? paymentMethodId,
  }) async {
    final normalizedType = paymentMethodType.trim();
    if (normalizedType.isEmpty) {
      throw ArgumentError('Xendit checkout requires a payment method type.');
    }

    final callable = _functions.httpsCallable('createXenditCheckoutSession');
    final result = await callable.call<Map<Object?, Object?>>(<String, Object?>{
      'booking_id': bookingId,
      'payment_method_type': normalizedType,
      if (paymentMethodId != null && paymentMethodId.trim().isNotEmpty)
        'payment_method_id': paymentMethodId.trim(),
    });

    return XenditCheckoutSession.fromMap(result.data);
  }

  Future<void> openCheckoutUrl(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw Exception('Xendit checkout URL is not valid.');
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Unable to open Xendit checkout.');
    }
  }
}
