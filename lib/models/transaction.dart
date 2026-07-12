import 'package:cloud_firestore/cloud_firestore.dart';

/// A wallet ledger entry. Named [WalletTransaction] to avoid clashing with
/// Firestore's `Transaction` type.
///
/// `type` is one of: `topup`, `payment`, `refund`, `earning`, `withdrawal`.
/// Amounts and balances are in cents.
class WalletTransaction {
  final String txnId;
  final String userId;
  final String type;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final String description;
  final String? relatedOrderId;
  final DateTime createdAt;

  WalletTransaction({
    required this.txnId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description = '',
    this.relatedOrderId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      txnId: json['txnId'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0) as int,
      balanceBefore: (json['balanceBefore'] ?? 0) as int,
      balanceAfter: (json['balanceAfter'] ?? 0) as int,
      description: json['description'] ?? '',
      relatedOrderId: json['relatedOrderId'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'txnId': txnId,
        'userId': userId,
        'type': type,
        'amount': amount,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'description': description,
        'relatedOrderId': relatedOrderId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WalletTransaction copyWith({String? txnId}) {
    return WalletTransaction(
      txnId: txnId ?? this.txnId,
      userId: userId,
      type: type,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
      relatedOrderId: relatedOrderId,
      createdAt: createdAt,
    );
  }
}
