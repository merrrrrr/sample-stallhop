/// App-wide constants for StallHop.
class AppConstants {
  AppConstants._();

  static const String appName = 'StallHop';

  // Money is stored everywhere as integer cents.
  /// Default platform commission rate taken from each vendor's earnings.
  static const double defaultCommissionRate = 0.10; // 10%

  /// Flat service fee charged to the customer per order, in cents.
  static const int serviceFeeCents = 50; // RM 0.50

  /// Quick top-up amounts shown on the wallet page, in cents.
  static const List<int> topUpPresetsCents = [1000, 2000, 5000, 10000];

  // Firestore collection paths.
  static const String usersCollection = 'users';
  static const String stallsCollection = 'stalls';
  static const String menuItemsSubcollection = 'menuItems';
  static const String ordersCollection = 'orders';
  static const String transactionsCollection = 'transactions';
  static const String reviewsCollection = 'reviews';
  static const String announcementsCollection = 'announcements';
  static const String configCollection = 'config';
  static const String venueConfigDoc = 'venue';

  // Roles.
  static const String roleCustomer = 'customer';
  static const String roleVendor = 'vendor';
  static const String roleAdmin = 'admin';

  // Order statuses.
  static const String orderPreparing = 'preparing';
  static const String orderReady = 'ready';
  static const String orderCollected = 'collected';
  static const String orderCancelled = 'cancelled';

  // Stall statuses.
  static const String stallPending = 'pending';
  static const String stallOpen = 'open';
  static const String stallClosed = 'closed';
  static const String stallSuspended = 'suspended';
  static const String stallRejected = 'rejected';

  // Transaction types.
  static const String txnTopUp = 'topup';
  static const String txnPayment = 'payment';
  static const String txnRefund = 'refund';
  static const String txnEarning = 'earning';
  static const String txnWithdrawal = 'withdrawal';

  // FCM topic for broadcast announcements.
  static const String announcementsTopic = 'announcements';
}
