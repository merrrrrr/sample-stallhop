import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/review.dart';

/// Review CRUD. Creating a review also recomputes the stall's aggregate rating
/// in the same transaction (the client-side equivalent of an `onReviewCreated`
/// Cloud Function).
class ReviewRepository {
  final FirebaseFirestore _db;

  ReviewRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection(AppConstants.reviewsCollection);

  DocumentReference<Map<String, dynamic>> _stallRef(String stallId) =>
      _db.collection(AppConstants.stallsCollection).doc(stallId);

  Future<void> createReview(Review review) async {
    await _db.runTransaction((txn) async {
      final stallRef = _stallRef(review.stallId);
      final stallSnap = await txn.get(stallRef);

      final reviewRef = _reviews.doc();
      final saved = review.copyWith(reviewId: reviewRef.id);
      txn.set(reviewRef, saved.toJson());

      if (stallSnap.exists) {
        final data = stallSnap.data()!;
        final oldCount = (data['totalReviews'] ?? 0) as int;
        final oldAvg = (data['averageRating'] ?? 0).toDouble();
        final newCount = oldCount + 1;
        final newAvg =
            ((oldAvg * oldCount) + review.rating) / newCount;
        txn.update(stallRef, {
          'totalReviews': newCount,
          'averageRating': double.parse(newAvg.toStringAsFixed(2)),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    });
  }

  Query<Map<String, dynamic>> _stallQuery(String stallId) => _reviews
      .where('stallId', isEqualTo: stallId)
      .orderBy('createdAt', descending: true);

  Future<List<Review>> getStallReviews(String stallId) async {
    final snap = await _stallQuery(stallId).get();
    return snap.docs.map((d) => Review.fromJson(d.data())).toList();
  }

  Stream<List<Review>> watchStallReviews(String stallId) {
    return _stallQuery(stallId).snapshots().map(
          (snap) => snap.docs.map((d) => Review.fromJson(d.data())).toList(),
        );
  }

  /// True if a review already exists for [orderId] (one review per order).
  Future<bool> hasReviewed(String orderId) async {
    final snap =
        await _reviews.where('orderId', isEqualTo: orderId).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
