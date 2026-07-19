import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db;

  AnnouncementRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection(AppConstants.announcementsCollection);

  Stream<List<Announcement>> watchAnnouncements() {
    return _announcements
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Announcement.fromJson(d.data())).toList());
  }

  Future<void> create({
    required String title,
    required String message,
    required String createdBy,
  }) async {
    final ref = _announcements.doc();
    final announcement = Announcement(
      announcementId: ref.id,
      title: title,
      message: message,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    await ref.set(announcement.toJson());
  }

  Future<void> delete(String announcementId) {
    return _announcements.doc(announcementId).delete();
  }
}
