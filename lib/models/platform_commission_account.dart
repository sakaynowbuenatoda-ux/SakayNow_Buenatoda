import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PlatformCommissionAccountType { gcash, maya, bank }

extension PlatformCommissionAccountTypeX on PlatformCommissionAccountType {
  String get firestoreValue {
    return switch (this) {
      PlatformCommissionAccountType.gcash => 'gcash',
      PlatformCommissionAccountType.maya => 'maya',
      PlatformCommissionAccountType.bank => 'bank',
    };
  }

  String get label {
    return switch (this) {
      PlatformCommissionAccountType.gcash => 'GCash',
      PlatformCommissionAccountType.maya => 'Maya',
      PlatformCommissionAccountType.bank => 'Bank Account',
    };
  }

  IconData get icon {
    return switch (this) {
      PlatformCommissionAccountType.gcash =>
        Icons.account_balance_wallet_rounded,
      PlatformCommissionAccountType.maya => Icons.wallet_rounded,
      PlatformCommissionAccountType.bank => Icons.account_balance_rounded,
    };
  }

  static PlatformCommissionAccountType fromFirestore(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return switch (normalized) {
      'maya' || 'paymaya' => PlatformCommissionAccountType.maya,
      'bank' || 'bank_account' => PlatformCommissionAccountType.bank,
      _ => PlatformCommissionAccountType.gcash,
    };
  }
}

class PlatformCommissionAccount {
  final String id;
  final PlatformCommissionAccountType type;
  final String label;
  final String accountName;
  final String accountReference;
  final String bankName;
  final bool isEnabled;
  final String updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlatformCommissionAccount({
    required this.id,
    required this.type,
    required this.label,
    required this.accountName,
    required this.accountReference,
    this.bankName = '',
    required this.isEnabled,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlatformCommissionAccount.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final type = PlatformCommissionAccountTypeX.fromFirestore(
      data['account_type'],
    );

    return PlatformCommissionAccount(
      id: document.id,
      type: type,
      label: _readString(data['label'], fallback: type.label),
      accountName: _readString(data['account_name']),
      accountReference: _readString(data['account_reference']),
      bankName: _readString(data['bank_name']),
      isEnabled: data['is_enabled'] == true,
      updatedBy: _readString(data['updated_by']),
      createdAt: _readDate(data['created_at']),
      updatedAt: _readDate(data['updated_at']),
    );
  }

  String get displayLabel {
    final normalized = label.trim();
    return normalized.isEmpty ? '${type.label} commission account' : normalized;
  }

  String get maskedReference {
    final normalized = accountReference.trim();
    if (normalized.length <= 4) {
      return normalized;
    }
    return '${List<String>.filled(normalized.length - 4, '*').join()}${normalized.substring(normalized.length - 4)}';
  }

  String get accountSummary {
    final parts = <String>[
      if (type == PlatformCommissionAccountType.bank &&
          bankName.trim().isNotEmpty)
        bankName.trim(),
      accountName.trim(),
      maskedReference,
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'Account details not set' : parts.join(' - ');
  }

  PlatformCommissionAccount copyWith({
    String? id,
    PlatformCommissionAccountType? type,
    String? label,
    String? accountName,
    String? accountReference,
    String? bankName,
    bool? isEnabled,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlatformCommissionAccount(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      accountName: accountName ?? this.accountName,
      accountReference: accountReference ?? this.accountReference,
      bankName: bankName ?? this.bankName,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore({
    required String adminId,
    required bool includeCreatedAt,
  }) {
    return <String, dynamic>{
      'account_type': type.firestoreValue,
      'provider': 'xendit',
      'label': displayLabel,
      'account_name': accountName.trim(),
      'account_reference': accountReference.trim(),
      'bank_name': type == PlatformCommissionAccountType.bank
          ? bankName.trim()
          : '',
      'is_enabled': isEnabled,
      'updated_by': adminId.trim(),
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
