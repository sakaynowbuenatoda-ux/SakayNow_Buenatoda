import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PassengerPaymentMethodType { cash, gcash, maya, card }

extension PassengerPaymentMethodTypeX on PassengerPaymentMethodType {
  String get firestoreValue {
    return switch (this) {
      PassengerPaymentMethodType.cash => 'cash',
      PassengerPaymentMethodType.gcash => 'gcash',
      PassengerPaymentMethodType.maya => 'maya',
      PassengerPaymentMethodType.card => 'card',
    };
  }

  String get label {
    return switch (this) {
      PassengerPaymentMethodType.cash => 'Cash',
      PassengerPaymentMethodType.gcash => 'GCash',
      PassengerPaymentMethodType.maya => 'Maya',
      PassengerPaymentMethodType.card => 'Card',
    };
  }

  String? get xenditValue {
    return switch (this) {
      PassengerPaymentMethodType.cash => null,
      PassengerPaymentMethodType.gcash => 'GCASH',
      PassengerPaymentMethodType.maya => 'PAYMAYA',
      PassengerPaymentMethodType.card => 'CREDIT_CARD',
    };
  }

  IconData get icon {
    return switch (this) {
      PassengerPaymentMethodType.cash => Icons.payments_rounded,
      PassengerPaymentMethodType.gcash => Icons.account_balance_wallet_rounded,
      PassengerPaymentMethodType.maya => Icons.wallet_rounded,
      PassengerPaymentMethodType.card => Icons.credit_card_rounded,
    };
  }

  Color get accentColor {
    return switch (this) {
      PassengerPaymentMethodType.cash => const Color(0xFF174A36),
      PassengerPaymentMethodType.gcash => const Color(0xFF2563FF),
      PassengerPaymentMethodType.maya => const Color(0xFF16A34A),
      PassengerPaymentMethodType.card => const Color(0xFF030213),
    };
  }

  static PassengerPaymentMethodType fromFirestore(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return switch (text) {
      'gcash' => PassengerPaymentMethodType.gcash,
      'maya' || 'paymaya' => PassengerPaymentMethodType.maya,
      'card' => PassengerPaymentMethodType.card,
      _ => PassengerPaymentMethodType.cash,
    };
  }
}

class PassengerPaymentMethod {
  static const String cashMethodId = 'cash';

  final String id;
  final String userId;
  final PassengerPaymentMethodType type;
  final String label;
  final String accountName;
  final String accountReference;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PassengerPaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    required this.accountName,
    required this.accountReference,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PassengerPaymentMethod.cash({required String userId}) {
    return PassengerPaymentMethod(
      id: cashMethodId,
      userId: userId,
      type: PassengerPaymentMethodType.cash,
      label: 'Cash',
      accountName: 'Pay driver',
      accountReference: 'After ride',
      isDefault: false,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory PassengerPaymentMethod.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final type = PassengerPaymentMethodTypeX.fromFirestore(data['type']);

    return PassengerPaymentMethod(
      id: document.id,
      userId: (data['user_id'] ?? '').toString().trim(),
      type: type,
      label: _readString(data['label'], fallback: type.label),
      accountName: _readString(data['account_name']),
      accountReference: _readString(data['account_reference']),
      isDefault: data['is_default'] == true,
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
    );
  }

  bool get isCash => type == PassengerPaymentMethodType.cash;
  bool get usesXendit => type.xenditValue != null;
  bool get usesOnlineCheckout => usesXendit;
  String get provider => usesXendit ? 'xendit' : 'cash';
  String? get xenditPaymentMethodType => type.xenditValue;

  String get displayLabel {
    final trimmed = label.trim();
    return trimmed.isEmpty ? type.label : trimmed;
  }

  String get accountLabel {
    if (isCash) {
      return 'Pay driver after ride';
    }

    if (type == PassengerPaymentMethodType.card) {
      return 'Card via Xendit checkout';
    }

    if (type == PassengerPaymentMethodType.gcash ||
        type == PassengerPaymentMethodType.maya) {
      return '${type.label} via Xendit checkout';
    }

    final reference = accountReference.trim();
    if (reference.isEmpty) {
      return 'Xendit checkout';
    }

    final name = accountName.trim();
    if (name.isEmpty) {
      return reference;
    }

    return '$name - $reference';
  }

  PassengerPaymentMethod copyWith({
    String? id,
    String? userId,
    PassengerPaymentMethodType? type,
    String? label,
    String? accountName,
    String? accountReference,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PassengerPaymentMethod(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      label: label ?? this.label,
      accountName: accountName ?? this.accountName,
      accountReference: accountReference ?? this.accountReference,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = false}) {
    return <String, dynamic>{
      'payment_method_id': id,
      'user_id': userId,
      'type': type.firestoreValue,
      'provider': provider,
      'label': displayLabel,
      'account_name': accountName.trim(),
      'account_reference': accountReference.trim(),
      'is_default': isDefault,
      'is_enabled': true,
      'updated_at': FieldValue.serverTimestamp(),
      if (includeCreatedAt) 'created_at': FieldValue.serverTimestamp(),
    };
  }

  static String _readString(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
