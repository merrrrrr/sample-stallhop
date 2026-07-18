import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
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
  final FirestoreService _firestore;

  VenueConfigRepository({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  String get _path =>
      '${AppConstants.configCollection}/${AppConstants.venueConfigDoc}';

  Stream<VenueConfig?> watchConfig() {
    return _firestore
        .documentStream(_path)
        .map((data) => data == null ? null : VenueConfig.fromJson(data));
  }

  Future<void> updateCommission(double rate) {
    return _firestore.setDocument(
      _path,
      {
        'defaultCommission': rate,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      merge: true,
    );
  }

  Future<void> updateServiceFee(int cents) {
    return _firestore.setDocument(
      _path,
      {
        'serviceFee': cents,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      merge: true,
    );
  }

  /// Total amount ever topped up across all users, in cents.
  Future<int> totalTopUps() async {
    final rows = await _firestore.getCollection(
      AppConstants.transactionsCollection,
      query: (q) => q.where('type', isEqualTo: AppConstants.txnTopUp),
    );
    return rows
        .map(WalletTransaction.fromJson)
        .fold<int>(0, (acc, t) => acc + t.amount);
  }
}
