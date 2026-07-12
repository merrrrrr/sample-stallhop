import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/menu_item.dart';

/// CRUD for a stall's menu items at `stalls/{stallId}/menuItems/{itemId}`.
class MenuRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  MenuRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService();

  String _path(String stallId) =>
      '${AppConstants.stallsCollection}/$stallId/'
      '${AppConstants.menuItemsSubcollection}';

  CollectionReference<Map<String, dynamic>> _col(String stallId) =>
      _db.collection(_path(stallId));

  Stream<List<MenuItem>> watchMenuItems(String stallId) {
    return _firestore
        .collectionStream(_path(stallId))
        .map((rows) => rows.map(MenuItem.fromJson).toList());
  }

  Future<MenuItem> addItem({
    required String stallId,
    required String name,
    required String description,
    required int price,
    required String category,
    String? imageUrl,
    List<Map<String, dynamic>> customizations = const [],
    List<Map<String, dynamic>> addOns = const [],
  }) async {
    final ref = _col(stallId).doc();
    final now = DateTime.now();
    final item = MenuItem(
      itemId: ref.id,
      stallId: stallId,
      name: name,
      description: description,
      price: price,
      category: category,
      imageUrl: imageUrl,
      customizations: customizations,
      addOns: addOns,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(item.toJson());
    return item;
  }

  Future<void> updateItem(MenuItem item) {
    return _col(item.stallId).doc(item.itemId).set(
          item.copyWith(updatedAt: DateTime.now()).toJson(),
        );
  }

  Future<void> setAvailable(String stallId, String itemId, bool available) {
    return _col(stallId).doc(itemId).update({
      'available': available,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteItem(String stallId, String itemId) {
    return _col(stallId).doc(itemId).delete();
  }
}
