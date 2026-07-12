import 'package:flutter/foundation.dart';

import '../../../models/order.dart';
import '../../../models/review.dart';
import '../repository/review_repository.dart';

/// Backs the review page: checks whether an order was already reviewed and
/// submits a new review (which also recomputes the stall rating).
class ReviewViewModel extends ChangeNotifier {
  final ReviewRepository _repository;

  ReviewViewModel({ReviewRepository? repository})
      : _repository = repository ?? ReviewRepository();

  bool _submitting = false;
  bool _alreadyReviewed = false;
  String? _error;

  bool get isSubmitting => _submitting;
  bool get alreadyReviewed => _alreadyReviewed;
  String? get error => _error;

  Future<void> checkExisting(String orderId) async {
    _alreadyReviewed = await _repository.hasReviewed(orderId);
    notifyListeners();
  }

  Future<bool> submit({
    required FoodOrder order,
    required int rating,
    required String comment,
  }) async {
    _error = null;
    _submitting = true;
    notifyListeners();
    try {
      final review = Review(
        reviewId: '',
        orderId: order.orderId,
        stallId: order.stallId,
        customerUid: order.customerUid,
        customerName: order.customerName,
        rating: rating,
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );
      await _repository.createReview(review);
      _alreadyReviewed = true;
      return true;
    } catch (e) {
      _error = 'Could not submit review. Please try again.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
