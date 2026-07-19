import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/menu_item.dart';
import '../../../models/stall.dart';

/// Read access to stalls and their menu items for customers.
class StallRepository {
  final FirebaseFirestore _db;

  StallRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  CollectionReference<Map<String, dynamic>> _menu(String stallId) =>
      _stalls.doc(stallId).collection(AppConstants.menuItemsSubcollection);

  /// Stalls visible to customers (open or temporarily closed, but not
  /// pending/suspended/rejected).
  Query<Map<String, dynamic>> get _visibleQuery => _stalls.where(
        'status',
        whereIn: [AppConstants.stallOpen, AppConstants.stallClosed],
      );

  Stream<List<Stall>> watchVisibleStalls() {
    return _visibleQuery.snapshots().map(
          (snap) => snap.docs.map((d) => Stall.fromJson(d.data())).toList(),
        );
  }

  Future<List<Stall>> getVisibleStalls() async {
    final snap = await _visibleQuery.get();
    return snap.docs.map((d) => Stall.fromJson(d.data())).toList();
  }

  Future<Stall?> getStall(String stallId) async {
    final snap = await _stalls.doc(stallId).get();
    final data = snap.data();
    return data == null ? null : Stall.fromJson(data);
  }

  Stream<Stall?> watchStall(String stallId) {
    return _stalls.doc(stallId).snapshots().map(
          (snap) => snap.data() == null ? null : Stall.fromJson(snap.data()!),
        );
  }

  Future<List<MenuItem>> getMenuItems(String stallId) async {
    final snap = await _menu(stallId).get();
    return snap.docs.map((d) => MenuItem.fromJson(d.data())).toList();
  }

  Stream<List<MenuItem>> watchMenuItems(String stallId) {
    return _menu(stallId).snapshots().map(
          (snap) => snap.docs.map((d) => MenuItem.fromJson(d.data())).toList(),
        );
  }
}
