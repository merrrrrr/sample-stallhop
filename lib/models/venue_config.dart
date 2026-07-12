import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton configuration document stored at `config/venue`.
///
/// The pickup code is built from [pickupCodePrefix] + a zero-padded
/// [pickupCodeCounter]; the counter increments atomically per order and the
/// prefix/counter reset daily.
class VenueConfig {
  final String venueName;
  final double defaultCommission;
  final int serviceFee; // cents
  final String pickupCodePrefix;
  final int pickupCodeCounter;
  final double? latitude;
  final double? longitude;
  final DateTime updatedAt;

  VenueConfig({
    this.venueName = 'StallHop',
    this.defaultCommission = 0.10,
    this.serviceFee = 50,
    this.pickupCodePrefix = 'A',
    this.pickupCodeCounter = 0,
    this.latitude,
    this.longitude,
    required this.updatedAt,
  });

  factory VenueConfig.fromJson(Map<String, dynamic> json) {
    return VenueConfig(
      venueName: json['venueName'] ?? 'StallHop',
      defaultCommission: (json['defaultCommission'] ?? 0.10).toDouble(),
      serviceFee: (json['serviceFee'] ?? 50) as int,
      pickupCodePrefix: json['pickupCodePrefix'] ?? 'A',
      pickupCodeCounter: (json['pickupCodeCounter'] ?? 0) as int,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'venueName': venueName,
        'defaultCommission': defaultCommission,
        'serviceFee': serviceFee,
        'pickupCodePrefix': pickupCodePrefix,
        'pickupCodeCounter': pickupCodeCounter,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  VenueConfig copyWith({
    String? venueName,
    double? defaultCommission,
    int? serviceFee,
    String? pickupCodePrefix,
    int? pickupCodeCounter,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return VenueConfig(
      venueName: venueName ?? this.venueName,
      defaultCommission: defaultCommission ?? this.defaultCommission,
      serviceFee: serviceFee ?? this.serviceFee,
      pickupCodePrefix: pickupCodePrefix ?? this.pickupCodePrefix,
      pickupCodeCounter: pickupCodeCounter ?? this.pickupCodeCounter,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
