import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../../customer/repository/order_repository.dart';

/// Vendor-facing data access: the vendor's own stall (create/read/update) and
/// the order queue. Order status changes and refunds delegate to the shared
/// [OrderRepository] so the transactional wallet logic stays in one place.
class VendorOrderRepository {
  final FirebaseFirestore _db;
  final OrderRepository _orderRepository;

  VendorOrderRepository({
    FirebaseFirestore? db,
    OrderRepository? orderRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _orderRepository = orderRepository ?? OrderRepository(db: db);

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  // --- Stall ---

  Query<Map<String, dynamic>> _myStallQuery(String vendorUid) =>
      _stalls.where('vendorUid', isEqualTo: vendorUid).limit(1);

  Stream<Stall?> watchMyStall(String vendorUid) {
    return _myStallQuery(vendorUid).snapshots().map(
          (snap) => snap.docs.isEmpty
              ? null
              : Stall.fromJson(snap.docs.first.data()),
        );
  }

  Future<Stall?> getMyStall(String vendorUid) async {
    final snap = await _myStallQuery(vendorUid).get();
    return snap.docs.isEmpty ? null : Stall.fromJson(snap.docs.first.data());
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
