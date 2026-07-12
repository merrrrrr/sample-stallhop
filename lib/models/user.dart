import 'package:cloud_firestore/cloud_firestore.dart';

/// Application user. Named [AppUser] to avoid clashing with Firebase's
/// own `User` type.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // "customer" | "vendor" | "admin"
  final String? profileImageUrl;
  final int walletBalance; // in cents
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.walletBalance = 0,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
      profileImageUrl: json['profileImageUrl'],
      walletBalance: (json['walletBalance'] ?? 0) as int,
      fcmToken: json['fcmToken'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'profileImageUrl': profileImageUrl,
        'walletBalance': walletBalance,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    int? walletBalance,
    String? fcmToken,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
