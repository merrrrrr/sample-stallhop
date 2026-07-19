import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';
import '../../models/transaction.dart';
import '../../models/venue_config.dart';

/// Reads/writes the singleton `config/venue` document and provides wallet
/// monitoring totals for the admin settings screen.
///
/// Lives in `core/` rather than `features/admin/` because all three roles read
/// it — pricing resolves the venue commission and service fee from here — even
/// though only an admin writes it.
class VenueConfigRepository {
  final FirebaseFirestore _db;

  VenueConfigRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection(AppConstants.configCollection)
      .doc(AppConstants.venueConfigDoc);

  Stream<VenueConfig?> watchConfig() {
    return _doc.snapshots().map(
          (snap) => snap.data() == null ? null : VenueConfig.fromJson(snap.data()!),
        );
  }

  Future<void> updateCommission(double rate) {
    return _doc.set({
      'defaultCommission': rate,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> updateServiceFee(int cents) {
    return _doc.set({
      'serviceFee': cents,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// Total amount ever topped up across all users, in cents.
  Future<int> totalTopUps() async {
    final snap = await _db
        .collection(AppConstants.transactionsCollection)
        .where('type', isEqualTo: AppConstants.txnTopUp)
        .get();
    return snap.docs
        .map((d) => WalletTransaction.fromJson(d.data()))
        .fold<int>(0, (acc, t) => acc + t.amount);
  }
}
