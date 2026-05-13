import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum DriverPayoutAccountType { gcash, maya, bank }

extension DriverPayoutAccountTypeX on DriverPayoutAccountType {
  String get firestoreValue {
    return switch (this) {
      DriverPayoutAccountType.gcash => 'gcash',
      DriverPayoutAccountType.maya => 'maya',
      DriverPayoutAccountType.bank => 'bank',
    };
  }

  String get label {
    return switch (this) {
      DriverPayoutAccountType.gcash => 'GCash',
      DriverPayoutAccountType.maya => 'Maya',
      DriverPayoutAccountType.bank => 'Bank Account',
    };
  }

  IconData get icon {
    return switch (this) {
      DriverPayoutAccountType.gcash => Icons.account_balance_wallet_rounded,
      DriverPayoutAccountType.maya => Icons.wallet_rounded,
      DriverPayoutAccountType.bank => Icons.account_balance_rounded,
    };
  }

  Color get accentColor {
    return switch (this) {
      DriverPayoutAccountType.gcash => const Color(0xFF2563FF),
      DriverPayoutAccountType.maya => const Color(0xFF16A34A),
      DriverPayoutAccountType.bank => const Color(0xFF0F766E),
    };
  }

  static DriverPayoutAccountType fromFirestore(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return switch (text) {
      'maya' || 'paymaya' => DriverPayoutAccountType.maya,
      'bank' || 'bank_account' || 'card' => DriverPayoutAccountType.bank,
      _ => DriverPayoutAccountType.gcash,
    };
  }
}

class DriverPayoutAccount {
  final String id;
  final String driverId;
  final DriverPayoutAccountType type;
  final String label;
  final String accountName;
  final String accountReference;
  final String bankName;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverPayoutAccount({
    required this.id,
    required this.driverId,
    required this.type,
    required this.label,
    required this.accountName,
    required this.accountReference,
    this.bankName = '',
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverPayoutAccount.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final type = DriverPayoutAccountTypeX.fromFirestore(data['type']);

    return DriverPayoutAccount(
      id: document.id,
      driverId: (data['driver_id'] ?? data['user_id'] ?? '').toString().trim(),
      type: type,
      label: _readString(data['label'], fallback: type.label),
      accountName: _readString(data['account_name']),
      accountReference: _readString(data['account_reference']),
      bankName: _readString(data['bank_name']),
      isDefault: data['is_default'] == true,
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
    );
  }

  String get displayLabel {
    final trimmed = label.trim();
    return trimmed.isEmpty ? type.label : trimmed;
  }

  String get accountLabel {
    final reference = accountReference.trim();
    final name = accountName.trim();
    final bank = bankName.trim();
    if (type == DriverPayoutAccountType.bank && bank.isNotEmpty) {
      if (name.isEmpty && reference.isEmpty) {
        return bank;
      }

      if (name.isEmpty) {
        return '$bank - $reference';
      }

      if (reference.isEmpty) {
        return '$bank - $name';
      }

      return '$bank - $name - $reference';
    }

    if (name.isEmpty) {
      return reference.isEmpty ? 'Payout account' : reference;
    }

    if (reference.isEmpty) {
      return name;
    }

    return '$name - $reference';
  }

  DriverPayoutAccount copyWith({
    String? id,
    String? driverId,
    DriverPayoutAccountType? type,
    String? label,
    String? accountName,
    String? accountReference,
    String? bankName,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverPayoutAccount(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      type: type ?? this.type,
      label: label ?? this.label,
      accountName: accountName ?? this.accountName,
      accountReference: accountReference ?? this.accountReference,
      bankName: bankName ?? this.bankName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = false}) {
    return <String, dynamic>{
      'payout_account_id': id,
      'driver_id': driverId,
      'user_id': driverId,
      'type': type.firestoreValue,
      'provider': 'driver_payout',
      'label': displayLabel,
      'account_name': accountName.trim(),
      'account_reference': accountReference.trim(),
      'bank_name': type == DriverPayoutAccountType.bank ? bankName.trim() : '',
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
