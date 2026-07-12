import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/menu_item.dart';
import '../../../models/stall.dart';

/// Read access to stalls and their menu items for customers.
class StallRepository {
  final FirestoreService _firestore;

  StallRepository({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  String get _col => AppConstants.stallsCollection;

  String _menuPath(String stallId) =>
      '$_col/$stallId/${AppConstants.menuItemsSubcollection}';

  /// Streams stalls visible to customers (open or temporarily closed, but not
  /// pending/suspended/rejected).
  Stream<List<Stall>> watchVisibleStalls() {
    return _firestore
        .collectionStream(
          _col,
          query: (q) => q.where(
            'status',
            whereIn: [AppConstants.stallOpen, AppConstants.stallClosed],
          ),
        )
        .map((rows) => rows.map(Stall.fromJson).toList());
  }

  Future<List<Stall>> getVisibleStalls() async {
    final rows = await _firestore.getCollection(
      _col,
      query: (q) => q.where(
        'status',
        whereIn: [AppConstants.stallOpen, AppConstants.stallClosed],
      ),
    );
    return rows.map(Stall.fromJson).toList();
  }

  Future<Stall?> getStall(String stallId) async {
    final data = await _firestore.getDocument('$_col/$stallId');
    return data == null ? null : Stall.fromJson(data);
  }

  Stream<Stall?> watchStall(String stallId) {
    return _firestore
        .documentStream('$_col/$stallId')
        .map((data) => data == null ? null : Stall.fromJson(data));
  }

  Future<List<MenuItem>> getMenuItems(String stallId) async {
    final rows = await _firestore.getCollection(_menuPath(stallId));
    return rows.map(MenuItem.fromJson).toList();
  }

  Stream<List<MenuItem>> watchMenuItems(String stallId) {
    return _firestore
        .collectionStream(_menuPath(stallId))
        .map((rows) => rows.map(MenuItem.fromJson).toList());
  }
}
