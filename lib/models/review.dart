import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's review of a stall, tied to a collected order.
/// `rating` is an integer from 1 to 5.
class Review {
  final String reviewId;
  final String orderId;
  final String stallId;
  final String customerUid;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.reviewId,
    required this.orderId,
    required this.stallId,
    required this.customerUid,
    required this.customerName,
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewId: json['reviewId'] ?? '',
      orderId: json['orderId'] ?? '',
      stallId: json['stallId'] ?? '',
      customerUid: json['customerUid'] ?? '',
      customerName: json['customerName'] ?? '',
      rating: (json['rating'] ?? 0) as int,
      comment: json['comment'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'reviewId': reviewId,
        'orderId': orderId,
        'stallId': stallId,
        'customerUid': customerUid,
        'customerName': customerName,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Review copyWith({String? reviewId}) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      orderId: orderId,
      stallId: stallId,
      customerUid: customerUid,
      customerName: customerName,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }
}
