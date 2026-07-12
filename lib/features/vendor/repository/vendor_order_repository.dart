import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../../customer/repository/order_repository.dart';

/// Vendor-facing data access: the vendor's own stall (create/read/update) and
/// the order queue. Order status changes and refunds delegate to the shared
/// [OrderRepository] so the transactional wallet logic stays in one place.
class VendorOrderRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;
  final OrderRepository _orderRepository;

  VendorOrderRepository({
    FirebaseFirestore? db,
    FirestoreService? firestore,
    OrderRepository? orderRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService(),
        _orderRepository = orderRepository ?? OrderRepository();

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  // --- Stall ---

  Stream<Stall?> watchMyStall(String vendorUid) {
    return _firestore
        .collectionStream(
          AppConstants.stallsCollection,
          query: (q) => q.where('vendorUid', isEqualTo: vendorUid).limit(1),
        )
        .map((rows) => rows.isEmpty ? null : Stall.fromJson(rows.first));
  }

  Future<Stall?> getMyStall(String vendorUid) async {
    final rows = await _firestore.getCollection(
      AppConstants.stallsCollection,
      query: (q) => q.where('vendorUid', isEqualTo: vendorUid).limit(1),
    );
    return rows.isEmpty ? null : Stall.fromJson(rows.first);
  }

  /// Creates a new stall in `pending` status awaiting admin approval.
  Future<Stall> createStall({
    required String vendorUid,
    required String name,
    required String cuisine,
    required String description,
    int prepTimeMinutes = 15,
  }) async {
    final ref = _stalls.doc();
    final now = DateTime.now();
    final stall = Stall(
      stallId: ref.id,
      vendorUid: vendorUid,
      name: name,
      cuisine: cuisine,
      description: description,
      status: AppConstants.stallPending,
      prepTimeMinutes: prepTimeMinutes,
      commissionRate: AppConstants.defaultCommissionRate,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(stall.toJson());
    return stall;
  }

  Future<void> updateStall(String stallId, Map<String, dynamic> data) {
    return _stalls.doc(stallId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> setOpen(String stallId, bool open) {
    return updateStall(stallId, {
      'status': open ? AppConstants.stallOpen : AppConstants.stallClosed,
    });
  }

  Future<void> setPrepTime(String stallId, int minutes) {
    return updateStall(stallId, {'prepTimeMinutes': minutes});
  }

  // --- Orders ---

  Stream<List<FoodOrder>> watchActiveOrders(String vendorUid) {
    return _orderRepository.watchVendorOrders(
      vendorUid,
      statuses: const [AppConstants.orderPreparing, AppConstants.orderReady],
    );
  }

  Stream<List<FoodOrder>> watchAllOrders(String vendorUid) {
    return _orderRepository.watchVendorOrders(vendorUid);
  }

  Stream<FoodOrder?> listenToOrder(String orderId) =>
      _orderRepository.listenToOrder(orderId);

  Future<void> markReady(String orderId) =>
      _orderRepository.updateStatus(orderId, AppConstants.orderReady);

  Future<void> markCollected(String orderId) =>
      _orderRepository.updateStatus(orderId, AppConstants.orderCollected);

  Future<void> cancelOrder(FoodOrder order) =>
      _orderRepository.cancelAndRefund(order);
}
