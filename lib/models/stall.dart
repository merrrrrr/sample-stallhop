import 'package:cloud_firestore/cloud_firestore.dart';

/// A food stall owned by a vendor.
///
/// `status` is one of: `pending`, `open`, `closed`, `suspended`, `rejected`.
class Stall {
  final String stallId;
  final String vendorUid;
  final String name;
  final String description;
  final String cuisine;
  final String? imageUrl;
  final String status;
  final int prepTimeMinutes;
  final double averageRating;
  final int totalReviews;

  /// Per-stall commission override. `null` means "inherit the venue-wide
  /// default" (`config/venue.defaultCommission`), which is what makes the
  /// admin's commission setting actually reach pricing. Only an admin may
  /// write this field.
  final double? commissionRate;

  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  Stall({
    required this.stallId,
    required this.vendorUid,
    required this.name,
    this.description = '',
    this.cuisine = '',
    this.imageUrl,
    this.status = 'pending',
    this.prepTimeMinutes = 15,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.commissionRate,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';

  factory Stall.fromJson(Map<String, dynamic> json) {
    return Stall(
      stallId: json['stallId'] ?? '',
      vendorUid: json['vendorUid'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      cuisine: json['cuisine'] ?? '',
      imageUrl: json['imageUrl'],
      status: json['status'] ?? 'pending',
      prepTimeMinutes: (json['prepTimeMinutes'] ?? 15) as int,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalReviews: (json['totalReviews'] ?? 0) as int,
      // Deliberately NOT defaulted to 0.10 — a missing/null value means
      // "inherit the venue default", so it must survive the round trip.
      commissionRate: (json['commissionRate'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stallId': stallId,
        'vendorUid': vendorUid,
        'name': name,
        'description': description,
        'cuisine': cuisine,
        'imageUrl': imageUrl,
        'status': status,
        'prepTimeMinutes': prepTimeMinutes,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'commissionRate': commissionRate,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Note [clearCommissionRate]: because `null` is a meaningful value here,
  /// `copyWith(commissionRate: null)` cannot mean "clear it" — that is
  /// indistinguishable from "don't change it". Pass `clearCommissionRate: true`
  /// to reset a stall back to inheriting the venue default.
  Stall copyWith({
    String? name,
    String? description,
    String? cuisine,
    String? imageUrl,
    String? status,
    int? prepTimeMinutes,
    double? averageRating,
    int? totalReviews,
    double? commissionRate,
    bool clearCommissionRate = false,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return Stall(
      stallId: stallId,
      vendorUid: vendorUid,
      name: name ?? this.name,
      description: description ?? this.description,
      cuisine: cuisine ?? this.cuisine,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      commissionRate:
          clearCommissionRate ? null : (commissionRate ?? this.commissionRate),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
