import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  AnnouncementRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService();

  Stream<List<Announcement>> watchAnnouncements() {
    return _firestore
        .collectionStream(
          AppConstants.announcementsCollection,
          query: (q) => q.orderBy('createdAt', descending: true).limit(50),
        )
        .map((rows) => rows.map(Announcement.fromJson).toList());
  }

  Future<void> create({
    required String title,
    required String message,
    required String createdBy,
  }) async {
    final ref = _db.collection(AppConstants.announcementsCollection).doc();
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
    return _db
        .collection(AppConstants.announcementsCollection)
        .doc(announcementId)
        .delete();
  }
}
