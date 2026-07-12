import 'package:cloud_firestore/cloud_firestore.dart';

/// A venue-wide announcement created by an admin.
class Announcement {
  final String announcementId;
  final String title;
  final String message;
  final String createdBy;
  final DateTime createdAt;

  Announcement({
    required this.announcementId,
    required this.title,
    required this.message,
    this.createdBy = '',
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['announcementId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'announcementId': announcementId,
        'title': title,
        'message': message,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Announcement copyWith({String? announcementId}) {
    return Announcement(
      announcementId: announcementId ?? this.announcementId,
      title: title,
      message: message,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
