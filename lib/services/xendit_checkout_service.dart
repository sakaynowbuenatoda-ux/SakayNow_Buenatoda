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

    final callable = _functions.httpsCallable('createXenditCheckoutSession');
    final result = await callable.call<Map<Object?, Object?>>(<String, Object?>{
      'booking_id': bookingId,
      'payment_method_type': xenditType,
      'payment_method_id': paymentMethod.id,
    });

    return XenditCheckoutSession.fromMap(result.data);
  }

  Future<void> openCheckoutUrl(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw StateError('Xendit checkout URL is not valid.');
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Unable to open Xendit checkout.');
    }
  }
}
