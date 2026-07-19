import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';

/// Admin control over stall lifecycle: approve, reject, suspend, reactivate.
class AdminStallRepository {
  final FirebaseFirestore _db;

  AdminStallRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  Stream<List<Stall>> watchAllStalls() {
    return _stalls.snapshots().map(
          (snap) => snap.docs.map((d) => Stall.fromJson(d.data())).toList(),
        );
  }

  Future<void> _setStatus(String stallId, String status) {
    return _stalls.doc(stallId).update({
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> approve(String stallId) =>
      _setStatus(stallId, AppConstants.stallOpen);

  Future<void> reject(String stallId) =>
      _setStatus(stallId, AppConstants.stallRejected);

  Future<void> suspend(String stallId) =>
      _setStatus(stallId, AppConstants.stallSuspended);

  Future<void> reactivate(String stallId) =>
      _setStatus(stallId, AppConstants.stallClosed);
}
