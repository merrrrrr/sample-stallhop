# StallHop — CT124-3-2 System Report Source

Extracted from the codebase at commit `95102c5` (branch `main`). Everything below is
derived from the actual code in `lib/`, `test/`, `integration_test/`, `android/`, `ios/`
and `pubspec.yaml`. Where a feature does not exist in the code it is written as
**not implemented** rather than guessed.

---

## 1. Functionalities per role

### General / Shared (all roles)

- Any visitor can create an account with full name, email, phone, password and a chosen role (Customer / Vendor / Admin). — `lib/features/auth/view/register_page.dart`
- Any visitor can log in with email and password. — `lib/features/auth/view/login_page.dart`
- Any visitor can sign in with a Google account ("Continue with Google"). — `lib/features/auth/view/login_page.dart`
- A first-time Google user can choose their role (Customer / Vendor / Admin) and optionally enter a phone number before their account document is created. — `lib/features/auth/view/choose_role_page.dart`
- Any user can be routed automatically to the home screen matching their role after login (splash screen while auth state resolves). — `lib/main.dart` (`AuthGate`), `lib/core/routing/app_router.dart` (`getHomeForRole`)
- Any signed-in user can log out. — Customer: `customer_profile_page.dart`; Vendor: `vendor_dashboard_page.dart` (app-bar icon); Admin: `admin_settings_page.dart` (app-bar icon); Role-selection: `choose_role_page.dart` ("Sign out")
- Any signed-in user can receive an in-app (local) notification when an admin publishes a venue announcement. — `lib/core/services/notification_coordinator.dart`
- **Password reset by email: not implemented as a user-facing feature.** `AuthService.sendPasswordResetEmail()` exists in `lib/core/services/auth_service.dart` but no screen calls it (there is no "Forgot password" link on the login page).

### Customer

- Customer can browse the list of stalls that are open or closed (pending / suspended / rejected stalls are hidden). — `stall_browsing_page.dart`
- Customer can search stalls by name. — `stall_browsing_page.dart`
- Customer can filter stalls by cuisine using filter chips. — `stall_browsing_page.dart`
- Customer can sort stalls by top rated, fastest prep time, or name A–Z. — `stall_browsing_page.dart` (`StallSort`)
- Customer can open a stall and view its menu grouped into category sections, with sold-out items greyed out and a banner when the stall is closed. — `stall_menu_page.dart`
- Customer can open an item's detail page and select one option per customization group (e.g. Size). — `item_detail_page.dart`
- Customer can tick optional add-ons, which increase the line price. — `item_detail_page.dart`
- Customer can type free-text special instructions for an item. — `item_detail_page.dart`
- Customer can set the quantity of an item with a stepper and see the live line total. — `item_detail_page.dart`
- Customer can add a configured item to the cart. — `item_detail_page.dart` → `CartViewModel.addItem`
- Customer can view the cart with lines grouped per stall. — `cart_page.dart`
- Customer can increase or decrease the quantity of a cart line (decrementing to zero removes it). — `cart_page.dart`
- Customer can see the cart subtotal, service fee, grand total, their wallet balance, and an "insufficient balance" warning. — `cart_page.dart`
- Customer can place an order paid from their wallet; the cart is split into one order per stall. — `cart_page.dart` → `OrderRepository.placeOrder`
- Customer can view the order-placed confirmation showing a QR code and pickup code for each order. — `order_placed_page.dart`
- Customer can track an order live through a status stepper (preparing → ready → collected). — `order_tracking_page.dart`
- Customer can display their QR code / pickup code for the vendor to scan at collection. — `order_tracking_page.dart` → `PickupCodeDisplay`
- Customer can view their orders split into "Active" and "Past" tabs. — `orders_list_page.dart`
- Customer can leave a 1–5 star rating and an optional comment on a collected order (once per order). — `review_page.dart`
- Customer can view their wallet balance and full transaction history. — `wallet_page.dart`
- Customer can top up their wallet by choosing a preset amount (RM 10 / 20 / 50 / 100) against a mock card. — `wallet_page.dart`
- Customer can view their profile (name, phone, email, avatar). — `customer_profile_page.dart`
- Customer can edit their name and phone number. — `customer_profile_page.dart`
- Customer can change their password. — `customer_profile_page.dart`
- Customer can receive in-app notifications when their order becomes ready, is collected, or is cancelled (with the refunded amount). — `notification_coordinator.dart`
- **Customer cannot cancel their own order** — no cancel action exists on any customer screen; cancellation is vendor-only (`order_detail_page.dart`).

### Stall Vendor

- Vendor can create their stall (name, cuisine, description, prep time); it is created in `pending` status awaiting admin approval. — `vendor_dashboard_page.dart` (`_CreateStallForm`)
- Vendor can see a banner telling them their stall is awaiting admin approval or has been suspended. — `vendor_dashboard_page.dart` (`_StallHeader`)
- Vendor can toggle their stall between Open and Closed (disabled while pending or suspended). — `vendor_dashboard_page.dart` → `VendorOrderRepository.setOpen`
- Vendor can edit their stall's prep time in minutes. — `vendor_dashboard_page.dart` → `VendorOrderRepository.setPrepTime`
- Vendor can view today's order count and today's earnings (subtotal minus commission). — `vendor_dashboard_page.dart` (`_StatsRow`)
- Vendor can see a preview of up to 5 active orders and tap through to their detail. — `vendor_dashboard_page.dart` (`_ActiveOrdersPreview`)
- Vendor can view the live order queue in two tabs, "Preparing" and "Ready", each showing a count. — `order_queue_page.dart`
- Vendor can mark a preparing order as ready, from the queue or from the order detail page. — `order_queue_page.dart`, `order_detail_page.dart`
- Vendor can open an order's detail to see the pickup code, customer name, status stepper, and every item with its customizations, add-ons and special instructions. — `order_detail_page.dart`
- Vendor can scan the customer's QR code with the device camera to verify the pickup code, with torch and camera-switch controls. — `order_detail_page.dart` → `QrScannerPage` (`lib/widgets/qr_scanner_widget.dart`)
- Vendor can complete an order (mark it collected) — the "Complete" button is only enabled after a successful QR code match. — `order_detail_page.dart`
- Vendor can cancel an order after a confirmation dialog; the customer is automatically refunded the full total and the vendor's earning is clawed back. — `order_detail_page.dart` → `OrderRepository.cancelAndRefund`
- Vendor can view their full menu item list with price and category. — `menu_management_page.dart`
- Vendor can toggle a menu item between Available and Sold out with a switch. — `menu_management_page.dart` → `MenuRepository.setAvailable`
- Vendor can delete a menu item from the overflow menu. — `menu_management_page.dart` → `MenuRepository.deleteItem`
- Vendor can add a new menu item with a photo, name, description, price (RM), and category. — `add_edit_item_page.dart` → `MenuRepository.addItem`
- Vendor can pick a menu-item photo from the device gallery, which is uploaded to Firebase Storage. — `add_edit_item_page.dart` → `StorageService.uploadImage`
- Vendor can define customization groups on an item (group name + comma-separated options). — `add_edit_item_page.dart`
- Vendor can define priced add-ons on an item (name + RM price). — `add_edit_item_page.dart`
- Vendor can edit any existing menu item, including its customizations and add-ons. — `add_edit_item_page.dart`
- Vendor can view their available earnings balance and a history of earnings, withdrawals and reversals. — `vendor_earnings_page.dart`
- Vendor can withdraw an amount of earnings (simulated payout; rejected if it exceeds the balance). — `vendor_earnings_page.dart` → `EarningsRepository.withdraw`
- Vendor can receive an in-app notification when a new order arrives for their stall. — `notification_coordinator.dart`

### Venue Admin

- Admin can view venue KPIs — total orders, revenue, active stalls (with a "N pending" badge), and average prep time. — `admin_dashboard_page.dart` (`_KpiGrid`)
- Admin can switch the dashboard date range between Today, Week and Month. — `admin_dashboard_page.dart` (`_RangeSelector`)
- Admin can view a peak-hours bar chart of order counts bucketed by hour of day (0–23). — `admin_dashboard_page.dart` (`_PeakHoursChart`, `fl_chart`)
- Admin can view the top 5 stalls ranked by order count. — `admin_dashboard_page.dart` (`_TopStalls`)
- Admin can view all stalls awaiting approval with their name, cuisine and description. — `vendor_management_page.dart`
- Admin can approve a pending stall (status becomes `open`). — `vendor_management_page.dart` → `AdminStallRepository.approve`
- Admin can reject a pending stall (status becomes `rejected`). — `vendor_management_page.dart` → `AdminStallRepository.reject`
- Admin can suspend an active stall. — `vendor_management_page.dart` → `AdminStallRepository.suspend`
- Admin can reactivate a suspended stall (status becomes `closed`, so the vendor must re-open it). — `vendor_management_page.dart` → `AdminStallRepository.reactivate`
- Admin can view disputes (cancelled orders) in "Open" and "Resolved" tabs with counts. — `disputes_page.dart`
- Admin can refund a disputed order, crediting the customer the full order total. — `disputes_page.dart` → `DisputeRepository.refund`
- Admin can dismiss a dispute without refunding. — `disputes_page.dart` → `DisputeRepository.dismiss`
- Admin can view the current commission rate and edit it as a percentage. — `admin_settings_page.dart` → `VenueConfigRepository.updateCommission`
- Admin can view the total value of all customer top-ups and refresh that figure. — `admin_settings_page.dart` → `VenueConfigRepository.totalTopUps`
- Admin can publish a venue-wide announcement with a title and message. — `announcements_page.dart` → `AnnouncementRepository.create`
- Admin can view the 50 most recent announcements and delete any of them. — `announcements_page.dart` → `AnnouncementRepository.delete`
- **Admin cannot search stalls by name** — no search bar exists on the vendor-management screen.
- **Admin cannot view a per-stall commission override** — only a single venue-wide rate exists.

---

## 2. File structure

Actual contents of `lib/` (83 Dart files):

```
lib/
├── core/
│   ├── routing/
│   │   └── app_router.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── notification_coordinator.dart
│   │   ├── notification_service.dart
│   │   └── storage_service.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   └── utils/
│       ├── app_exceptions.dart
│       ├── constants.dart
│       ├── formatters.dart
│       └── validators.dart
├── features/
│   ├── admin/
│   │   ├── repository/
│   │   │   ├── admin_stall_repository.dart
│   │   │   ├── announcement_repository.dart
│   │   │   ├── dispute_repository.dart
│   │   │   └── venue_config_repository.dart
│   │   ├── view/
│   │   │   ├── admin_dashboard_page.dart
│   │   │   ├── admin_settings_page.dart
│   │   │   ├── announcements_page.dart
│   │   │   ├── disputes_page.dart
│   │   │   └── vendor_management_page.dart
│   │   └── view_model/
│   │       ├── admin_dashboard_vm.dart
│   │       ├── announcements_vm.dart
│   │       ├── disputes_vm.dart
│   │       └── vendor_management_vm.dart
│   ├── auth/
│   │   ├── repository/
│   │   │   └── auth_repository.dart
│   │   ├── view/
│   │   │   ├── choose_role_page.dart
│   │   │   ├── login_page.dart
│   │   │   └── register_page.dart
│   │   └── view_model/
│   │       └── auth_view_model.dart
│   ├── customer/
│   │   ├── repository/
│   │   │   ├── order_repository.dart
│   │   │   ├── review_repository.dart
│   │   │   ├── stall_repository.dart
│   │   │   └── wallet_repository.dart
│   │   ├── view/
│   │   │   ├── cart_page.dart
│   │   │   ├── customer_home_page.dart
│   │   │   ├── customer_profile_page.dart
│   │   │   ├── item_detail_page.dart
│   │   │   ├── order_placed_page.dart
│   │   │   ├── order_tracking_page.dart
│   │   │   ├── orders_list_page.dart
│   │   │   ├── review_page.dart
│   │   │   ├── stall_browsing_page.dart
│   │   │   ├── stall_menu_page.dart
│   │   │   └── wallet_page.dart
│   │   └── view_model/
│   │       ├── cart_vm.dart
│   │       ├── order_tracking_vm.dart
│   │       ├── review_vm.dart
│   │       ├── stall_browsing_vm.dart
│   │       └── wallet_vm.dart
│   └── vendor/
│       ├── repository/
│       │   ├── earnings_repository.dart
│       │   ├── menu_repository.dart
│       │   └── vendor_order_repository.dart
│       ├── view/
│       │   ├── add_edit_item_page.dart
│       │   ├── menu_management_page.dart
│       │   ├── order_detail_page.dart
│       │   ├── order_queue_page.dart
│       │   ├── vendor_dashboard_page.dart
│       │   └── vendor_earnings_page.dart
│       └── view_model/
│           ├── earnings_vm.dart
│           ├── menu_management_vm.dart
│           ├── order_detail_vm.dart
│           ├── order_queue_vm.dart
│           └── vendor_dashboard_vm.dart
├── models/
│   ├── announcement.dart
│   ├── menu_item.dart
│   ├── order.dart
│   ├── order_item.dart
│   ├── review.dart
│   ├── stall.dart
│   ├── transaction.dart
│   ├── user.dart
│   └── venue_config.dart
├── widgets/
│   ├── empty_state.dart
│   ├── loading_indicator.dart
│   ├── order_status_stepper.dart
│   ├── pickup_code_display.dart
│   ├── qr_scanner_widget.dart
│   ├── stall_card.dart
│   └── wallet_balance_card.dart
├── firebase_options.dart
└── main.dart
```

Notes on the structure, for the report's narrative:

- The project is **feature-first**: each of `admin/`, `auth/`, `customer/`, `vendor/` contains its own `view/`, `view_model/` and `repository/` folders.
- There is **no top-level `views/`, `view_models/` or `repository/` folder** — those layers live inside each feature. `models/` and `core/` are the only shared top-level layers, plus `widgets/` for reusable UI.
- `core/services/` holds the four infrastructure wrappers (Firebase Auth, Firestore, Storage, local notifications) plus `notification_coordinator.dart`, which is the client-side replacement for the planned Cloud Functions.

Test folders:

```
test/
├── models/models_test.dart
├── repositories/order_repository_test.dart
├── services/notification_coordinator_test.dart
├── utils/formatters_test.dart
├── utils/validators_test.dart
├── view_models/cart_vm_test.dart
├── view_models/wallet_vm_test.dart
├── widgets/order_status_stepper_test.dart
├── widgets/stall_card_test.dart
└── widgets/wallet_balance_card_test.dart

integration_test/
└── app_test.dart
```

---

## 3. Data management (CRUD per entity)

Firestore collections in use (from `lib/core/utils/constants.dart`):

| Collection path | Entity | Model file |
| --- | --- | --- |
| `users/{uid}` | AppUser | `lib/models/user.dart` |
| `stalls/{stallId}` | Stall | `lib/models/stall.dart` |
| `stalls/{stallId}/menuItems/{itemId}` | MenuItem | `lib/models/menu_item.dart` |
| `orders/{orderId}` | FoodOrder | `lib/models/order.dart` |
| *(embedded in `orders.items[]`)* | OrderItem | `lib/models/order_item.dart` |
| `transactions/{txnId}` | WalletTransaction | `lib/models/transaction.dart` |
| `reviews/{reviewId}` | Review | `lib/models/review.dart` |
| `announcements/{announcementId}` | Announcement | `lib/models/announcement.dart` |
| `config/venue` (singleton doc) | VenueConfig | `lib/models/venue_config.dart` |

All money is stored as **integer cents**. Every document embeds its own id field, which is
why `FirestoreService` can return raw data maps without carrying the `DocumentSnapshot` id.

### 3.0 Shared data-access layer — `FirestoreService`

Every repository is built on this generic helper, so the CRUD primitives below are shared.

**File:** `lib/core/services/firestore_service.dart`

```dart
typedef JsonMap = Map<String, dynamic>;
typedef QueryBuilder = Query<JsonMap> Function(Query<JsonMap> query);

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Generates an id for a new document in [collectionPath] without writing.
  String newDocId(String collectionPath) =>
      _db.collection(collectionPath).doc().id;

  Future<JsonMap?> getDocument(String path) async {
    final snap = await _db.doc(path).get();
    return snap.data();
  }

  Stream<JsonMap?> documentStream(String path) {
    return _db.doc(path).snapshots().map((snap) => snap.data());
  }

  Future<void> setDocument(String path, JsonMap data, {bool merge = false}) {
    return _db.doc(path).set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(String path, JsonMap data) {
    return _db.doc(path).update(data);
  }

  Future<void> deleteDocument(String path) {
    return _db.doc(path).delete();
  }

  Future<List<JsonMap>> getCollection(
    String path, {
    QueryBuilder? query,
  }) async {
    Query<JsonMap> ref = _db.collection(path);
    if (query != null) ref = query(ref);
    final snap = await ref.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<List<JsonMap>> collectionStream(
    String path, {
    QueryBuilder? query,
  }) {
    Query<JsonMap> ref = _db.collection(path);
    if (query != null) ref = query(ref);
    return ref.snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
  }
}
```

*What it does:* one thin wrapper around Firestore providing get / stream / set / update /
delete for a single document and get / stream (with an optional query builder) for a
collection. Every repository composes these instead of touching `FirebaseFirestore` directly
for plain reads and writes. (Transactional writes still use `FirebaseFirestore.runTransaction`
directly — see `OrderRepository` and `WalletRepository`.)

---

### 3.1 Entity: AppUser — `users/{uid}`

**Model:** `lib/models/user.dart` (class `AppUser`)
**Primary repository:** `lib/features/auth/repository/auth_repository.dart`

#### CREATE — `AuthRepository.createUser`

**File:** `lib/features/auth/repository/auth_repository.dart`

```dart
Future<void> createUser(AppUser user) {
  return _firestore.setDocument('$_col/${user.uid}', user.toJson());
}
```

*Writes the StallHop user document at `users/{uid}` after Firebase Auth has created the
credential — called on email registration and after a new Google user picks a role.*

#### READ (one-shot) — `AuthRepository.getUser`

```dart
Future<AppUser?> getUser(String uid) async {
  final data = await _firestore.getDocument('$_col/$uid');
  return data == null ? null : AppUser.fromJson(data);
}
```

*Fetches a single user document once and decodes it into an `AppUser`, or `null` if it does not exist.*

#### READ (live) — `AuthRepository.watchUser`

```dart
Stream<AppUser?> watchUser(String uid) {
  return _firestore
      .documentStream('$_col/$uid')
      .map((data) => data == null ? null : AppUser.fromJson(data));
}
```

*Streams the signed-in user's document so the whole app (wallet balance, name, role) updates
live. This is the stream `AuthViewModel` subscribes to.*

#### UPDATE — `AuthRepository.updateUser`

```dart
Future<void> updateUser(String uid, Map<String, dynamic> data) {
  return _firestore.updateDocument('$_col/$uid', data);
}
```

*Patches arbitrary fields on a user document. Used by the customer profile screen to save an
edited name and phone.*

#### UPDATE (wallet balance) — `WalletRepository._applyDelta`

**File:** `lib/features/customer/repository/wallet_repository.dart`

```dart
Future<void> _applyDelta({
  required String uid,
  required int delta,
  required String type,
  required String description,
  String? relatedOrderId,
  bool requireFunds = false,
}) async {
  await _db.runTransaction((txn) async {
    final ref = _userRef(uid);
    final snap = await txn.get(ref);
    if (!snap.exists) throw const NotFoundException('User not found');
    final before = (snap.data()!['walletBalance'] ?? 0) as int;
    final after = before + delta;
    if (requireFunds && after < 0) {
      throw const InsufficientBalanceException();
    }
    txn.update(ref, {
      'walletBalance': after,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    final txnRef = _txns.doc();
    txn.set(
      txnRef,
      WalletTransaction(
        txnId: txnRef.id,
        userId: uid,
        type: type,
        amount: delta.abs(),
        balanceBefore: before,
        balanceAfter: after,
        description: description,
        relatedOrderId: relatedOrderId,
        createdAt: DateTime.now(),
      ).toJson(),
    );
  });
}
```

*The single entry point for every balance change outside of ordering. Inside one Firestore
transaction it reads the current balance, applies the delta (rejecting the write if
`requireFunds` is set and the result would go negative), and writes both the new
`walletBalance` and a matching ledger entry, so a balance can never move without a
transaction record.*

**DELETE — not implemented.** No code path deletes a `users/{uid}` document.

---

### 3.2 Entity: Stall — `stalls/{stallId}`

**Model:** `lib/models/stall.dart` (class `Stall`)
**Repositories:** `vendor/repository/vendor_order_repository.dart` (vendor side),
`customer/repository/stall_repository.dart` (customer reads),
`admin/repository/admin_stall_repository.dart` (admin lifecycle)

#### CREATE — `VendorOrderRepository.createStall`

**File:** `lib/features/vendor/repository/vendor_order_repository.dart`

```dart
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
```

*Creates the vendor's stall document with a generated id, stamps it `pending` and applies the
default 10% commission rate, so it stays invisible to customers until an admin approves it.*

#### READ (customer, live list) — `StallRepository.watchVisibleStalls`

**File:** `lib/features/customer/repository/stall_repository.dart`

```dart
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
```

*Streams only the stalls a customer is allowed to see — `open` or `closed` — filtering out
pending, suspended and rejected ones at the query level.*

#### READ (customer, one-shot list) — `StallRepository.getVisibleStalls`

```dart
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
```

*One-shot version of the same query.*

#### READ (single) — `StallRepository.getStall` / `StallRepository.watchStall`

```dart
Future<Stall?> getStall(String stallId) async {
  final data = await _firestore.getDocument('$_col/$stallId');
  return data == null ? null : Stall.fromJson(data);
}

Stream<Stall?> watchStall(String stallId) {
  return _firestore
      .documentStream('$_col/$stallId')
      .map((data) => data == null ? null : Stall.fromJson(data));
}
```

*Fetches, or live-streams, one stall document by id.*

#### READ (vendor's own stall) — `VendorOrderRepository.watchMyStall` / `getMyStall`

**File:** `lib/features/vendor/repository/vendor_order_repository.dart`

```dart
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
```

*Finds the one stall owned by this vendor (live or one-shot). Returns `null` when the vendor
has not created a stall yet, which is what drives the "Set up your stall" form.*

#### READ (admin, all stalls) — `AdminStallRepository.watchAllStalls`

**File:** `lib/features/admin/repository/admin_stall_repository.dart`

```dart
Stream<List<Stall>> watchAllStalls() {
  return _firestore
      .collectionStream(AppConstants.stallsCollection)
      .map((rows) => rows.map(Stall.fromJson).toList());
}
```

*Streams every stall regardless of status, so the admin can see pending, open, closed,
suspended and rejected ones.*

#### UPDATE (vendor) — `VendorOrderRepository.updateStall` / `setOpen` / `setPrepTime`

```dart
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
```

*`updateStall` patches any fields and always refreshes `updatedAt`; `setOpen` flips the stall
between `open` and `closed` for the dashboard toggle; `setPrepTime` saves the vendor's
estimated preparation time.*

#### UPDATE (admin lifecycle) — `AdminStallRepository._setStatus` + `approve` / `reject` / `suspend` / `reactivate`

**File:** `lib/features/admin/repository/admin_stall_repository.dart`

```dart
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
```

*The four admin lifecycle actions, all writing the same `status` field: approve makes a stall
live (`open`), reject kills the application, suspend takes a live stall down, and reactivate
returns a suspended stall to `closed` so the vendor must deliberately re-open it.*

#### UPDATE (rating aggregate) — inside `ReviewRepository.createReview`

See §3.7 — creating a review recomputes `averageRating` and `totalReviews` on the stall
inside the same transaction.

**DELETE — not implemented.** Stalls are rejected or suspended, never deleted.

---

### 3.3 Entity: MenuItem — `stalls/{stallId}/menuItems/{itemId}`

**Model:** `lib/models/menu_item.dart` (class `MenuItem`)
**Repository:** `lib/features/vendor/repository/menu_repository.dart` (writes),
`lib/features/customer/repository/stall_repository.dart` (customer reads)

#### CREATE — `MenuRepository.addItem`

**File:** `lib/features/vendor/repository/menu_repository.dart`

```dart
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
```

*Creates a new dish in the stall's `menuItems` sub-collection, including its customization
groups and priced add-ons, and returns the saved model.*

#### READ (live) — `MenuRepository.watchMenuItems` / `StallRepository.watchMenuItems`

```dart
// MenuRepository (vendor side)
Stream<List<MenuItem>> watchMenuItems(String stallId) {
  return _firestore
      .collectionStream(_path(stallId))
      .map((rows) => rows.map(MenuItem.fromJson).toList());
}
```

```dart
// StallRepository (customer side)
Stream<List<MenuItem>> watchMenuItems(String stallId) {
  return _firestore
      .collectionStream(_menuPath(stallId))
      .map((rows) => rows.map(MenuItem.fromJson).toList());
}
```

*Both stream the full menu of one stall live — the vendor's menu-management list and the
customer's stall menu page use the same underlying sub-collection.*

#### READ (one-shot) — `StallRepository.getMenuItems`

```dart
Future<List<MenuItem>> getMenuItems(String stallId) async {
  final rows = await _firestore.getCollection(_menuPath(stallId));
  return rows.map(MenuItem.fromJson).toList();
}
```

*Fetches a stall's menu once, without a listener.*

#### UPDATE — `MenuRepository.updateItem`

```dart
Future<void> updateItem(MenuItem item) {
  return _col(item.stallId).doc(item.itemId).set(
        item.copyWith(updatedAt: DateTime.now()).toJson(),
      );
}
```

*Overwrites a menu item with the edited version, refreshing `updatedAt`. Used by the
Edit-item screen.*

#### UPDATE (availability) — `MenuRepository.setAvailable`

```dart
Future<void> setAvailable(String stallId, String itemId, bool available) {
  return _col(stallId).doc(itemId).update({
    'available': available,
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}
```

*Flips a single item between Available and Sold out — the switch on the menu-management row.*

#### DELETE — `MenuRepository.deleteItem`

```dart
Future<void> deleteItem(String stallId, String itemId) {
  return _col(stallId).doc(itemId).delete();
}
```

*Permanently removes a menu item from the stall's sub-collection.*

---

### 3.4 Entity: FoodOrder — `orders/{orderId}`

**Model:** `lib/models/order.dart` (class `FoodOrder`)
**Repository:** `lib/features/customer/repository/order_repository.dart` (the single source of
truth for order writes; `VendorOrderRepository` and `DisputeRepository` delegate to it)

#### CREATE — `OrderRepository.placeOrder`

**File:** `lib/features/customer/repository/order_repository.dart`

```dart
/// Places one order for one stall. Atomically: validates the customer has
/// funds, generates a pickup code, deducts the customer, credits the vendor
/// (minus commission), and writes the order + two ledger entries.
Future<FoodOrder> placeOrder({
  required AppUser customer,
  required Stall stall,
  required List<OrderItem> items,
  int serviceFeeCents = AppConstants.serviceFeeCents,
}) async {
  final subtotal = items.fold<int>(0, (acc, i) => acc + i.subtotal);
  final total = subtotal + serviceFeeCents;
  final now = DateTime.now();
  late FoodOrder order;

  await _db.runTransaction((txn) async {
    final customerRef = _userRef(customer.uid);
    final vendorRef = _userRef(stall.vendorUid);

    // --- reads first (Firestore requires all reads before writes) ---
    final customerSnap = await txn.get(customerRef);
    final vendorSnap = await txn.get(vendorRef);
    final venueSnap = await txn.get(_venueRef);

    final custBefore = (customerSnap.data()?['walletBalance'] ?? 0) as int;
    if (custBefore < total) throw const InsufficientBalanceException();
    final vendBefore = (vendorSnap.data()?['walletBalance'] ?? 0) as int;

    // Pickup codes restart each day (replaces the plan's scheduled
    // resetPickupCodeDaily Cloud Function — automation is client-side).
    final todayKey = _dateKey(now);
    final storedDate = venueSnap.data()?['pickupCodeDate'] as String?;
    final isNewDay = storedDate != todayKey;
    final prefix = isNewDay
        ? 'A'
        : (venueSnap.data()?['pickupCodePrefix'] ?? 'A') as String;
    final counter = isNewDay
        ? 0
        : (venueSnap.data()?['pickupCodeCounter'] ?? 0) as int;
    final nextCounter = counter + 1;
    final pickupCode = '$prefix${nextCounter.toString().padLeft(3, '0')}';

    final vendorEarning =
        (subtotal * (1 - stall.commissionRate)).round();
    final custAfter = custBefore - total;
    final vendAfter = vendBefore + vendorEarning;

    final orderRef = _orders.doc();
    order = FoodOrder(
      orderId: orderRef.id,
      customerUid: customer.uid,
      customerName: customer.name,
      stallId: stall.stallId,
      vendorUid: stall.vendorUid,
      stallName: stall.name,
      items: items,
      subtotal: subtotal,
      serviceFee: serviceFeeCents,
      total: total,
      status: AppConstants.orderPreparing,
      pickupCode: pickupCode,
      createdAt: now,
      updatedAt: now,
    );

    // --- writes ---
    txn.set(orderRef, order.toJson());
    txn.update(customerRef, {
      'walletBalance': custAfter,
      'updatedAt': Timestamp.fromDate(now),
    });
    txn.update(vendorRef, {
      'walletBalance': vendAfter,
      'updatedAt': Timestamp.fromDate(now),
    });
    txn.set(_venueRef, {
      'pickupCodePrefix': prefix,
      'pickupCodeCounter': nextCounter,
      'pickupCodeDate': todayKey,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    _writeTxn(
      txn,
      userId: customer.uid,
      type: AppConstants.txnPayment,
      amount: total,
      before: custBefore,
      after: custAfter,
      description: 'Order ${order.pickupCode} • ${stall.name}',
      orderId: orderRef.id,
    );
    _writeTxn(
      txn,
      userId: stall.vendorUid,
      type: AppConstants.txnEarning,
      amount: vendorEarning,
      before: vendBefore,
      after: vendAfter,
      description: 'Earning • Order ${order.pickupCode}',
      orderId: orderRef.id,
    );
  });

  return order;
}
```

*The heart of the system. In one Firestore transaction it checks the customer can afford the
order, allocates the next daily pickup code (resetting the counter if the stored date is not
today), deducts the customer's wallet, credits the vendor their share after commission, writes
the order document, and appends both ledger entries — so an order can never exist without the
matching money movement.*

Supporting helpers used above:

```dart
/// Calendar-day key (`yyyy-MM-dd`) used to detect when the pickup-code
/// counter should reset.
static String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
```

```dart
void _writeTxn(
  Transaction txn, {
  required String userId,
  required String type,
  required int amount,
  required int before,
  required int after,
  required String description,
  String? orderId,
}) {
  final ref = _db.collection(AppConstants.transactionsCollection).doc();
  txn.set(
    ref,
    WalletTransaction(
      txnId: ref.id,
      userId: userId,
      type: type,
      amount: amount,
      balanceBefore: before,
      balanceAfter: after,
      description: description,
      relatedOrderId: orderId,
      createdAt: DateTime.now(),
    ).toJson(),
  );
}
```

*`_dateKey` produces the `yyyy-MM-dd` string that decides whether the pickup counter restarts;
`_writeTxn` appends one ledger entry inside an already-open transaction.*

#### READ (single, one-shot) — `OrderRepository.getOrder`

```dart
Future<FoodOrder?> getOrder(String orderId) async {
  final data = await _firestore
      .getDocument('${AppConstants.ordersCollection}/$orderId');
  return data == null ? null : FoodOrder.fromJson(data);
}
```

*Fetches one order by id.*

#### READ (single, live) — `OrderRepository.listenToOrder`

```dart
Stream<FoodOrder?> listenToOrder(String orderId) {
  return _firestore
      .documentStream('${AppConstants.ordersCollection}/$orderId')
      .map((data) => data == null ? null : FoodOrder.fromJson(data));
}
```

*Live-streams one order — this is what makes the customer's tracking stepper and the vendor's
order-detail screen update in real time.*

#### READ (customer's orders) — `OrderRepository.watchCustomerOrders`

```dart
Stream<List<FoodOrder>> watchCustomerOrders(String customerUid) {
  return _firestore
      .collectionStream(
        AppConstants.ordersCollection,
        query: (q) => q
            .where('customerUid', isEqualTo: customerUid)
            .orderBy('createdAt', descending: true),
      )
      .map((rows) => rows.map(FoodOrder.fromJson).toList());
}
```

*Streams every order belonging to one customer, newest first — the source for the Active/Past
tabs.*

#### READ (vendor's orders) — `OrderRepository.watchVendorOrders`

```dart
Stream<List<FoodOrder>> watchVendorOrders(
  String vendorUid, {
  List<String>? statuses,
}) {
  return _firestore
      .collectionStream(
        AppConstants.ordersCollection,
        query: (q) {
          var query = q.where('vendorUid', isEqualTo: vendorUid);
          if (statuses != null && statuses.isNotEmpty) {
            query = query.where('status', whereIn: statuses);
          }
          return query.orderBy('createdAt', descending: true);
        },
      )
      .map((rows) => rows.map(FoodOrder.fromJson).toList());
}
```

*Streams a vendor's orders, optionally narrowed to particular statuses — the order queue asks
for `preparing` + `ready` only.*

#### READ (admin, cancelled orders / disputes) — `DisputeRepository.watchCancelledOrders`

**File:** `lib/features/admin/repository/dispute_repository.dart`

```dart
/// All cancelled orders; the view model splits them into open/resolved.
Stream<List<FoodOrder>> watchCancelledOrders() {
  return _firestore
      .collectionStream(
        AppConstants.ordersCollection,
        query: (q) => q
            .where('status', isEqualTo: AppConstants.orderCancelled)
            .orderBy('createdAt', descending: true),
      )
      .map((rows) => rows.map(FoodOrder.fromJson).toList());
}
```

*Streams every cancelled order; `DisputesViewModel` then splits them into "open" (neither
refunded nor dismissed) and "resolved".*

#### UPDATE (status) — `OrderRepository.updateStatus`

```dart
Future<void> updateStatus(String orderId, String status) {
  final now = DateTime.now();
  final data = <String, dynamic>{
    'status': status,
    'updatedAt': Timestamp.fromDate(now),
  };
  if (status == AppConstants.orderReady) {
    data['readyAt'] = Timestamp.fromDate(now);
  } else if (status == AppConstants.orderCollected) {
    data['collectedAt'] = Timestamp.fromDate(now);
  }
  return _orders.doc(orderId).update(data);
}
```

*Moves an order along the lifecycle and stamps the matching timestamp (`readyAt` /
`collectedAt`), which the admin dashboard later uses to compute average prep time.*

Vendor-facing wrappers (`lib/features/vendor/repository/vendor_order_repository.dart`):

```dart
Future<void> markReady(String orderId) =>
    _orderRepository.updateStatus(orderId, AppConstants.orderReady);

Future<void> markCollected(String orderId) =>
    _orderRepository.updateStatus(orderId, AppConstants.orderCollected);

Future<void> cancelOrder(FoodOrder order) =>
    _orderRepository.cancelAndRefund(order);
```

*Thin delegations so all transactional wallet logic stays in one place.*

#### UPDATE (cancel + refund) — `OrderRepository.cancelAndRefund`

```dart
/// Cancels an order and refunds the customer the full total, clawing back
/// the vendor's earning. Sets status `cancelled` and `refunded = true`.
Future<void> cancelAndRefund(FoodOrder order) async {
  if (order.refunded) return;
  final now = DateTime.now();
  await _db.runTransaction((txn) async {
    final orderRef = _orders.doc(order.orderId);
    final customerRef = _userRef(order.customerUid);
    final vendorRef = _userRef(order.vendorUid);

    final customerSnap = await txn.get(customerRef);
    final vendorSnap = await txn.get(vendorRef);

    final custBefore = (customerSnap.data()?['walletBalance'] ?? 0) as int;
    final vendBefore = (vendorSnap.data()?['walletBalance'] ?? 0) as int;
    final vendorEarning =
        (order.subtotal * (1 - _commissionFor(order))).round();
    final custAfter = custBefore + order.total;
    final vendAfter = vendBefore - vendorEarning;

    txn.update(orderRef, {
      'status': AppConstants.orderCancelled,
      'refunded': true,
      'updatedAt': Timestamp.fromDate(now),
      'cancelledAt': Timestamp.fromDate(now),
    });
    txn.update(customerRef, {
      'walletBalance': custAfter,
      'updatedAt': Timestamp.fromDate(now),
    });
    txn.update(vendorRef, {
      'walletBalance': vendAfter,
      'updatedAt': Timestamp.fromDate(now),
    });
    _writeTxn(
      txn,
      userId: order.customerUid,
      type: AppConstants.txnRefund,
      amount: order.total,
      before: custBefore,
      after: custAfter,
      description: 'Refund • Order ${order.pickupCode}',
      orderId: order.orderId,
    );
    _writeTxn(
      txn,
      userId: order.vendorUid,
      type: AppConstants.txnRefund,
      amount: vendorEarning,
      before: vendBefore,
      after: vendAfter,
      description: 'Reversal • Order ${order.pickupCode}',
      orderId: order.orderId,
    );
  });
}
```

*The vendor's "Cancel order" action. In one transaction it marks the order cancelled and
refunded, credits the customer the full total back, debits the vendor the earning they were
originally paid, and writes both reversal ledger entries.*

Supporting helper:

```dart
// Commission isn't stored on the order; derive the vendor's earning share
// from total/subtotal so the reversal matches the original earning credit.
double _commissionFor(FoodOrder order) {
  if (order.subtotal == 0) return 0;
  return AppConstants.defaultCommissionRate;
}
```

*Supplies the commission rate used when reversing a vendor's earning.*

#### UPDATE (admin refund) — `DisputeRepository.refund`

**File:** `lib/features/admin/repository/dispute_repository.dart`

```dart
/// Credits the customer the full order total and marks the order refunded,
/// atomically with the ledger entry.
Future<void> refund(FoodOrder order) async {
  if (order.refunded) return;
  final now = DateTime.now();
  await _db.runTransaction((txn) async {
    final orderRef =
        _db.collection(AppConstants.ordersCollection).doc(order.orderId);
    final customerRef =
        _db.collection(AppConstants.usersCollection).doc(order.customerUid);

    final customerSnap = await txn.get(customerRef);
    final before = (customerSnap.data()?['walletBalance'] ?? 0) as int;
    final after = before + order.total;

    txn.update(customerRef, {
      'walletBalance': after,
      'updatedAt': Timestamp.fromDate(now),
    });
    txn.update(orderRef, {
      'refunded': true,
      'updatedAt': Timestamp.fromDate(now),
    });

    final txnRef =
        _db.collection(AppConstants.transactionsCollection).doc();
    txn.set(
      txnRef,
      WalletTransaction(
        txnId: txnRef.id,
        userId: order.customerUid,
        type: AppConstants.txnRefund,
        amount: order.total,
        balanceBefore: before,
        balanceAfter: after,
        description: 'Admin refund • Order ${order.pickupCode}',
        relatedOrderId: order.orderId,
        createdAt: now,
      ).toJson(),
    );
  });
}
```

*The admin's dispute resolution. Credits the customer the full order total, flags the order
`refunded`, and writes an "Admin refund" ledger entry — all atomically.*

#### UPDATE (admin dismiss) — `DisputeRepository.dismiss`

```dart
/// Resolves the dispute without refunding.
Future<void> dismiss(FoodOrder order) {
  return _db
      .collection(AppConstants.ordersCollection)
      .doc(order.orderId)
      .update({
    'dismissed': true,
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}
```

*Closes a dispute without paying out, by setting the `dismissed` flag.*

**DELETE — not implemented.** Orders are cancelled, never deleted.

---

### 3.5 Entity: OrderItem — *embedded*, no collection of its own

**Model:** `lib/models/order_item.dart` (class `OrderItem`)

`OrderItem` is **not a Firestore collection** — it is serialized into the `items` array on each
`orders/{orderId}` document, so it has no independent CRUD. It is created in the UI
(`item_detail_page.dart` builds one when the customer taps "Add to cart"), held in
`CartViewModel`, and written as part of `placeOrder`. Its computed fields are:

**File:** `lib/models/order_item.dart`

```dart
/// Sum of add-on prices for a single unit, in cents.
int get addOnsTotal =>
    addOns.fold(0, (sum, a) => sum + ((a['price'] ?? 0) as num).toInt());

/// Total for this line: (base + add-ons) × quantity, in cents.
int get subtotal => (unitPrice + addOnsTotal) * quantity;
```

*`addOnsTotal` sums the selected add-ons for one unit; `subtotal` is the full line price. Note
that `toJson()` writes `subtotal` into Firestore as a denormalized field.*

---

### 3.6 Entity: WalletTransaction — `transactions/{txnId}`

**Model:** `lib/models/transaction.dart` (class `WalletTransaction`)
**Repository:** `lib/features/customer/repository/wallet_repository.dart`
(plus `EarningsRepository`, which is a filtered view of the same ledger)

The ledger is **append-only**: entries are created by `_applyDelta` (§3.1), by
`OrderRepository._writeTxn` (§3.4) and by `DisputeRepository.refund` (§3.4). There is **no
update and no delete** path for a transaction anywhere in the codebase.

#### CREATE (top-up) — `WalletRepository.topUp`

```dart
/// Adds [amountCents] to a customer wallet and records a `topup` entry.
Future<void> topUp(String uid, int amountCents) {
  return _applyDelta(
    uid: uid,
    delta: amountCents,
    type: AppConstants.txnTopUp,
    description: 'Top up',
  );
}
```

*Credits the customer's wallet and records a `topup` ledger entry — the wallet page's mock-card
top-up.*

#### CREATE (refund) — `WalletRepository.refund`

```dart
/// Credits [amountCents] back to a wallet (used by refunds).
Future<void> refund(
  String uid,
  int amountCents, {
  String? orderId,
  String description = 'Refund',
}) {
  return _applyDelta(
    uid: uid,
    delta: amountCents,
    type: AppConstants.txnRefund,
    description: description,
    relatedOrderId: orderId,
  );
}
```

*Credits money back to a wallet and records a `refund` entry.*

#### CREATE (payment) — `WalletRepository.deductPayment`

```dart
/// Deducts [amountCents] from a wallet as a `payment` (used outside the
/// place-order transaction, e.g. manual adjustments).
Future<void> deductPayment(
  String uid,
  int amountCents, {
  String? orderId,
  String description = 'Payment',
}) {
  return _applyDelta(
    uid: uid,
    delta: -amountCents,
    type: AppConstants.txnPayment,
    description: description,
    relatedOrderId: orderId,
    requireFunds: true,
  );
}
```

*Debits a wallet as a payment, refusing to go negative. (The normal checkout path does its own
deduction inside `placeOrder`; this method exists for adjustments and is exercised by the unit
tests.)*

#### CREATE (withdrawal) — `WalletRepository.withdraw`

```dart
/// Vendor withdrawal: debits [amountCents] and records a `withdrawal` entry.
Future<void> withdraw(String uid, int amountCents) {
  return _applyDelta(
    uid: uid,
    delta: -amountCents,
    type: AppConstants.txnWithdrawal,
    description: 'Withdrawal',
    requireFunds: true,
  );
}
```

*The vendor's simulated payout: debits the earnings balance and records a `withdrawal` entry,
refusing to overdraw.*

#### READ (one-shot) — `WalletRepository.getTransactions`

```dart
Future<List<WalletTransaction>> getTransactions(
  String uid, {
  List<String>? types,
}) async {
  final rows = await _firestore.getCollection(
    AppConstants.transactionsCollection,
    query: (q) {
      var query = q.where('userId', isEqualTo: uid);
      if (types != null && types.isNotEmpty) {
        query = query.where('type', whereIn: types);
      }
      return query.orderBy('createdAt', descending: true);
    },
  );
  return rows.map(WalletTransaction.fromJson).toList();
}
```

*Fetches one user's ledger once, optionally filtered by transaction type.*

#### READ (live) — `WalletRepository.watchTransactions`

```dart
Stream<List<WalletTransaction>> watchTransactions(
  String uid, {
  List<String>? types,
}) {
  return _firestore
      .collectionStream(
        AppConstants.transactionsCollection,
        query: (q) {
          var query = q.where('userId', isEqualTo: uid);
          if (types != null && types.isNotEmpty) {
            query = query.where('type', whereIn: types);
          }
          return query.orderBy('createdAt', descending: true);
        },
      )
      .map((rows) => rows.map(WalletTransaction.fromJson).toList());
}
```

*Live-streams one user's ledger, newest first — used by the customer wallet page and (filtered)
by the vendor earnings page.*

#### READ (vendor earnings view) — `EarningsRepository`

**File:** `lib/features/vendor/repository/earnings_repository.dart`

```dart
static const _types = [
  AppConstants.txnEarning,
  AppConstants.txnWithdrawal,
  AppConstants.txnRefund,
];

Stream<List<WalletTransaction>> watchEarnings(String vendorUid) {
  return _wallet.watchTransactions(vendorUid, types: _types);
}

Future<void> withdraw(String vendorUid, int amountCents) {
  return _wallet.withdraw(vendorUid, amountCents);
}
```

*A narrow view over the shared ledger showing only what a vendor cares about — earnings,
withdrawals and reversals — plus a pass-through to the withdrawal write.*

#### READ (admin aggregate) — `VenueConfigRepository.totalTopUps`

**File:** `lib/features/admin/repository/venue_config_repository.dart`

```dart
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
```

*Reads every `topup` entry across all users and sums the amounts — the "Total customer
top-ups" figure on the admin settings screen.*

**UPDATE / DELETE — not implemented** (deliberately: the ledger is append-only).

---

### 3.7 Entity: Review — `reviews/{reviewId}`

**Model:** `lib/models/review.dart` (class `Review`)
**Repository:** `lib/features/customer/repository/review_repository.dart`

#### CREATE — `ReviewRepository.createReview`

```dart
Future<void> createReview(Review review) async {
  await _db.runTransaction((txn) async {
    final stallRef = _stallRef(review.stallId);
    final stallSnap = await txn.get(stallRef);

    final reviewRef = _reviews.doc();
    final saved = review.copyWith(reviewId: reviewRef.id);
    txn.set(reviewRef, saved.toJson());

    if (stallSnap.exists) {
      final data = stallSnap.data()!;
      final oldCount = (data['totalReviews'] ?? 0) as int;
      final oldAvg = (data['averageRating'] ?? 0).toDouble();
      final newCount = oldCount + 1;
      final newAvg =
          ((oldAvg * oldCount) + review.rating) / newCount;
      txn.update(stallRef, {
        'totalReviews': newCount,
        'averageRating': double.parse(newAvg.toStringAsFixed(2)),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  });
}
```

*Writes the review and, in the same transaction, recomputes the stall's running average rating
and review count — this is the client-side equivalent of the planned `onReviewCreated` Cloud
Function.*

#### READ (one-shot) — `ReviewRepository.getStallReviews`

```dart
Future<List<Review>> getStallReviews(String stallId) async {
  final rows = await _firestore.getCollection(
    AppConstants.reviewsCollection,
    query: (q) => q
        .where('stallId', isEqualTo: stallId)
        .orderBy('createdAt', descending: true),
  );
  return rows.map(Review.fromJson).toList();
}
```

*Fetches all reviews for one stall, newest first.*

#### READ (live) — `ReviewRepository.watchStallReviews`

```dart
Stream<List<Review>> watchStallReviews(String stallId) {
  return _firestore
      .collectionStream(
        AppConstants.reviewsCollection,
        query: (q) => q
            .where('stallId', isEqualTo: stallId)
            .orderBy('createdAt', descending: true),
      )
      .map((rows) => rows.map(Review.fromJson).toList());
}
```

*Live-streams a stall's reviews. **Note for the report:** this method exists but **no screen
currently calls it** — the app does not have a "read reviews" list; ratings surface only as the
star average on `StallCard`.*

#### READ (duplicate guard) — `ReviewRepository.hasReviewed`

```dart
/// True if a review already exists for [orderId] (one review per order).
Future<bool> hasReviewed(String orderId) async {
  final rows = await _firestore.getCollection(
    AppConstants.reviewsCollection,
    query: (q) => q.where('orderId', isEqualTo: orderId).limit(1),
  );
  return rows.isNotEmpty;
}
```

*Checks whether this order was already reviewed, so the review page can show "You have already
reviewed this order" instead of the form.*

**UPDATE / DELETE — not implemented.** A review cannot be edited or removed.

---

### 3.8 Entity: Announcement — `announcements/{announcementId}`

**Model:** `lib/models/announcement.dart` (class `Announcement`)
**Repository:** `lib/features/admin/repository/announcement_repository.dart`

#### CREATE — `AnnouncementRepository.create`

```dart
Future<void> create({
  required String title,
  required String message,
  required String createdBy,
}) async {
  final ref = _db.collection(AppConstants.announcementsCollection).doc();
  final announcement = Announcement(
    announcementId: ref.id,
    title: title,
    message: message,
    createdBy: createdBy,
    createdAt: DateTime.now(),
  );
  await ref.set(announcement.toJson());
}
```

*Publishes a venue-wide announcement, stamped with the admin's uid. Every signed-in client is
listening on this collection, so the write is what triggers their local notification.*

#### READ (live) — `AnnouncementRepository.watchAnnouncements`

```dart
Stream<List<Announcement>> watchAnnouncements() {
  return _firestore
      .collectionStream(
        AppConstants.announcementsCollection,
        query: (q) => q.orderBy('createdAt', descending: true).limit(50),
      )
      .map((rows) => rows.map(Announcement.fromJson).toList());
}
```

*Streams the 50 most recent announcements, newest first, for the admin's "Recent" list.*

#### DELETE — `AnnouncementRepository.delete`

```dart
Future<void> delete(String announcementId) {
  return _db
      .collection(AppConstants.announcementsCollection)
      .doc(announcementId)
      .delete();
}
```

*Removes an announcement.*

**UPDATE — not implemented.** An announcement cannot be edited, only deleted and re-posted.

---

### 3.9 Entity: VenueConfig — `config/venue` (singleton document)

**Model:** `lib/models/venue_config.dart` (class `VenueConfig`)
**Repository:** `lib/features/admin/repository/venue_config_repository.dart`

#### READ (live) — `VenueConfigRepository.watchConfig`

```dart
Stream<VenueConfig?> watchConfig() {
  return _firestore
      .documentStream(_path)
      .map((data) => data == null ? null : VenueConfig.fromJson(data));
}
```

*Streams the singleton venue configuration document (`config/venue`) for the admin settings
screen.*

#### UPDATE (commission) — `VenueConfigRepository.updateCommission`

```dart
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
```

*Saves a new venue-wide commission rate (as a fraction, e.g. `0.10`), merging so the pickup-code
fields on the same document are preserved.*

#### UPDATE (pickup-code counter) — inside `OrderRepository.placeOrder`

The same document also stores the daily pickup-code state. It is written transactionally on
every order (see the full `placeOrder` body in §3.4):

```dart
txn.set(_venueRef, {
  'pickupCodePrefix': prefix,
  'pickupCodeCounter': nextCounter,
  'pickupCodeDate': todayKey,
  'updatedAt': Timestamp.fromDate(now),
}, SetOptions(merge: true));
```

*Advances the daily pickup-code counter and stamps today's date key, so the next order gets the
next code and the counter restarts on a new calendar day.*

**CREATE / DELETE — not implemented.** The document is created implicitly the first time
`updateCommission` or `placeOrder` merges into it; there is no explicit create and no delete.

> **Important caveat for §3 in the report:** the commission rate the admin edits
> (`config/venue.defaultCommission`) is **not read back by the order pipeline**. `placeOrder`
> uses `stall.commissionRate` (set to `AppConstants.defaultCommissionRate` = 0.10 when the stall
> is created), and `cancelAndRefund` uses the constant `AppConstants.defaultCommissionRate`
> directly. Editing the venue commission therefore does not change what existing stalls are
> charged. This is a real limitation of the build, not an assumption.

---

## 4. User permissions

Only **two** runtime permissions are actually reachable in the app, plus one Android manifest
declaration.

| Permission | Requested by (package / API) | Where it is triggered | Declared in |
| --- | --- | --- | --- |
| **Notifications** (Android 13+ `POST_NOTIFICATIONS`; iOS alert/badge/sound) | `flutter_local_notifications` — `AndroidFlutterLocalNotificationsPlugin.requestNotificationsPermission()` and `IOSFlutterLocalNotificationsPlugin.requestPermissions(...)` | App start: `main()` calls `await notificationService.init()` before `runApp` — i.e. it is requested on first launch, before login | `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` |
| **Camera** | `mobile_scanner` (`MobileScannerController` / `MobileScanner` widget) | Vendor taps **Scan QR** on a *ready* order: `order_detail_page.dart` → pushes `QrScannerPage` (`lib/widgets/qr_scanner_widget.dart`), which opens the camera | **Not declared in the app's own manifest** — contributed by the `mobile_scanner` plugin's manifest at build time. **`NSCameraUsageDescription` is missing from `ios/Runner/Info.plist`** |
| **Photo library / gallery** | `image_picker` — `ImagePicker().pickImage(source: ImageSource.gallery, ...)` | Vendor taps the photo box on **Add / Edit menu item**: `add_edit_item_page.dart` → `_pickImage()` | Android 13+ media access is handled by the plugin's Photo Picker (no app-level declaration). **`NSPhotoLibraryUsageDescription` is missing from `ios/Runner/Info.plist`** |

Code that requests the notification permission — `lib/core/services/notification_service.dart`:

```dart
/// Initializes the plugin and requests notification permission
/// (Android 13+ / iOS). Safe to call more than once.
Future<void> init() async {
  if (_initialized) return;
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  try {
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  } catch (e) {
    // Notifications are a nice-to-have; never let them break app startup.
    debugPrint('NotificationService init failed: $e');
  }
}
```

Code that opens the camera — `lib/widgets/qr_scanner_widget.dart`:

```dart
class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }
  // ...
}
```

Code that opens the gallery — `lib/features/vendor/view/add_edit_item_page.dart`:

```dart
Future<void> _pickImage() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 80,
  );
  if (picked != null) {
    setState(() => _pickedImage = File(picked.path));
  }
}
```

### Permissions NOT used

- **Location — not implemented.** `geolocator: ^13.0.2` and `google_maps_flutter: ^2.10.0` are
  declared in `pubspec.yaml`, but there is **no import or usage of either package anywhere in
  `lib/`**. No `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` is declared in the Android
  manifest and no `NSLocationWhenInUseUsageDescription` is in `Info.plist`. The `latitude` /
  `longitude` fields exist on the `Stall` and `VenueConfig` models but are never populated or
  read by any screen.
- **Camera (photo capture) — not used.** `image_picker` is only ever called with
  `ImageSource.gallery`, never `ImageSource.camera`. The only camera use is the QR scanner.
- **Push notifications (FCM) — not implemented.** `firebase_messaging` is not a dependency. The
  `fcmToken` field exists on the `AppUser` model and is serialized, but nothing ever writes a
  token to it.

---

## 5. MVVM architecture mapping

State management is **`provider` (`ChangeNotifier`)**. There is no `MaterialApp.routes` table —
navigation is imperative (`Navigator.push` with `MaterialPageRoute`), and the top-level route is
chosen by `AuthGate` in `lib/main.dart` based on `AuthViewModel.status`.

### Layers and their actual class names

| Layer | Location | Actual classes |
| --- | --- | --- |
| **View** (Widgets) | `lib/features/*/view/`, `lib/widgets/` | `LoginPage`, `RegisterPage`, `ChooseRolePage`, `StallBrowsingPage`, `StallMenuPage`, `ItemDetailPage`, `CartPage`, `OrderPlacedPage`, `OrderTrackingPage`, `OrdersListPage`, `ReviewPage`, `WalletPage`, `CustomerProfilePage`, `CustomerHomePage`, `VendorDashboardPage`, `OrderQueuePage`, `VendorOrderDetailPage`, `MenuManagementPage`, `AddEditItemPage`, `VendorEarningsPage`, `AdminDashboardPage`, `VendorManagementPage`, `DisputesPage`, `AnnouncementsPage`, `AdminSettingsPage`; shared widgets: `StallCard`, `OrderStatusStepper`, `PickupCodeDisplay`, `QrScannerPage`, `WalletBalanceCard`, `EmptyState`, `LoadingIndicator` |
| **ViewModel** (`ChangeNotifier`) | `lib/features/*/view_model/` | `AuthViewModel`, `CartViewModel`, `StallBrowsingViewModel`, `OrderTrackingViewModel`, `ReviewViewModel`, `WalletViewModel`, `VendorDashboardViewModel`, `OrderQueueViewModel`, `VendorOrderDetailViewModel`, `MenuManagementViewModel`, `EarningsViewModel`, `AdminDashboardViewModel`, `VendorManagementViewModel`, `DisputesViewModel`, `AnnouncementsViewModel` |
| **Model** (plain Dart + JSON) | `lib/models/` | `AppUser`, `Stall`, `MenuItem`, `FoodOrder`, `OrderItem`, `WalletTransaction`, `Review`, `Announcement`, `VenueConfig` |
| **Repository** | `lib/features/*/repository/` | `AuthRepository`, `StallRepository`, `OrderRepository`, `WalletRepository`, `ReviewRepository`, `VendorOrderRepository`, `MenuRepository`, `EarningsRepository`, `AdminStallRepository`, `DisputeRepository`, `AnnouncementRepository`, `VenueConfigRepository` |
| **Service** (SDK wrappers) | `lib/core/services/` | `AuthService`, `FirestoreService`, `StorageService`, `NotificationService`, `NotificationCoordinator` |

### One example file per layer

- **View:** `lib/features/customer/view/wallet_page.dart` — class `WalletPage`
- **ViewModel:** `lib/features/customer/view_model/wallet_vm.dart` — class `WalletViewModel`
- **Model:** `lib/models/transaction.dart` — class `WalletTransaction`
- **Repository:** `lib/features/customer/repository/wallet_repository.dart` — class `WalletRepository`
- **Service:** `lib/core/services/firestore_service.dart` — class `FirestoreService`

### How the layers call each other

The dependency direction is strictly **View → ViewModel → Repository → Service → Firebase SDK**,
with **Models** flowing back up through every layer. No View talks to Firestore directly except
where a `StreamBuilder` reads a repository stream (`orders_list_page.dart`,
`stall_menu_page.dart`, `admin_settings_page.dart`) — those still go through the repository, never
the SDK.

Walking the **wallet top-up** vertical slice end to end:

1. **View** — `WalletPage` wraps itself in `ChangeNotifierProvider(create: (_) => WalletViewModel())`,
   then `context.watch<WalletViewModel>()` rebuilds it when the VM notifies. The button calls
   `vm.topUp(uid, _selectedAmount)`; the uid comes from `context.read<AuthViewModel>().currentUser`.
   The transaction list is a `StreamBuilder<List<WalletTransaction>>` over `vm.transactions(uid)`.
2. **ViewModel** — `WalletViewModel` owns UI state (`isProcessing`, `error`), delegates the write
   to `WalletRepository.topUp`, and calls `notifyListeners()` around it:

   ```dart
   Future<bool> topUp(String uid, int amountCents) async {
     _error = null;
     _processing = true;
     notifyListeners();
     try {
       await _repository.topUp(uid, amountCents);
       return true;
     } catch (e) {
       _error = 'Top-up failed. Please try again.';
       return false;
     } finally {
       _processing = false;
       notifyListeners();
     }
   }
   ```

3. **Repository** — `WalletRepository.topUp` runs a Firestore transaction (`_applyDelta`, §3.1)
   that updates `users/{uid}.walletBalance` and appends a `WalletTransaction` document.
4. **Service / SDK** — reads and streams go through `FirestoreService`; the transactional write
   uses `FirebaseFirestore.runTransaction` directly (a deliberate exception, since transactions
   cannot be expressed through the generic helper).
5. **Model back up** — the raw `Map<String, dynamic>` from Firestore is decoded by
   `WalletTransaction.fromJson` in the repository, so the ViewModel and View only ever see typed
   models.
6. **Live balance** — note the balance shown on `WalletPage` does **not** come from
   `WalletViewModel`; it comes from `AuthViewModel.currentUser.walletBalance`, because
   `AuthViewModel` subscribes to `AuthRepository.watchUser(uid)` and therefore already has a live
   `users/{uid}` stream. The wallet write updates that document, and the balance re-renders
   automatically.

**Dependency injection:** every repository and ViewModel takes optional constructor parameters
that default to a real instance (e.g. `WalletRepository({FirebaseFirestore? db, FirestoreService? firestore})`,
`WalletViewModel({WalletRepository? repository})`). This is what lets the unit tests inject
`FakeFirebaseFirestore` without any mocking framework.

**Provider registration** — `lib/main.dart` registers only the two app-wide ViewModels; every
other ViewModel is scoped to its screen via a local `ChangeNotifierProvider`:

```dart
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: authViewModel),
      ChangeNotifierProvider(create: (_) => CartViewModel()),
    ],
    child: const StallHopApp(),
  ),
);
```

**Role routing** — `lib/core/routing/app_router.dart`:

```dart
/// Maps a user role to its home screen.
Widget getHomeForRole(String role) {
  switch (role) {
    case AppConstants.roleCustomer:
      return const CustomerHomePage();
    case AppConstants.roleVendor:
      return const VendorDashboardPage();
    case AppConstants.roleAdmin:
      return const AdminDashboardPage();
    default:
      return const LoginPage();
  }
}
```

---

## 6. Testing summary

### 6.1 Unit / widget tests

Run with `flutter test`. 10 test files, 72 individual tests. Firestore is faked with
`fake_cloud_firestore: ^3.1.0` (no emulator or network needed). `mockito` and `build_runner` are
listed in `dev_dependencies` but **no generated mocks or `@GenerateMocks` annotations exist** —
the tests rely on constructor injection and hand-written fakes instead.

| Test file | What it covers |
| --- | --- |
| `test/models/models_test.dart` | Serialization round-trips (`toJson` → `fromJson` → `toJson`) for all 9 models: `AppUser`, `Stall`, `MenuItem`, `OrderItem`, `FoodOrder` (incl. nested items and the `refunded`/`dismissed` dispute flags), `WalletTransaction`, `Review`, `Announcement`, `VenueConfig`. Also asserts `OrderItem.subtotal` = `(800 + 150) × 2 = 1900` and that `Timestamp` conversion preserves the exact instant. (11 tests) |
| `test/repositories/order_repository_test.dart` | `OrderRepository` against `FakeFirebaseFirestore`. Group **pickup codes**: codes increment within the same day (`A001`, `A002`); the counter resets to `A001` when the stored `pickupCodeDate` is a previous day; the counter continues when the stored date is today. Group **wallets**: `placeOrder` deducts the customer 750 cents (700 subtotal + 50 service fee) and credits the vendor 630 cents (subtotal minus 10% commission); `cancelAndRefund` restores the customer to 10000 and claws the vendor back to 0, setting `status: cancelled` and `refunded: true`. (5 tests) |
| `test/services/notification_coordinator_test.dart` | `NotificationCoordinator` with a `RecordingNotificationService` subclass that captures notifications instead of hitting the platform plugin. Group **customer**: notified when their order becomes ready; notified with the refund amount when cancelled; placing their own order does *not* notify. Group **vendor**: notified when a new order arrives; pre-existing orders present at login do *not* notify (the seeding guard); their own status updates do not notify. Group **announcements**: a new announcement notifies any signed-in user; the author is not notified of their own announcement. Plus `stop()` ends all listening. (9 tests) |
| `test/utils/formatters_test.dart` | `centsToRM` (zero, typical, negative with leading sign, large amounts), `rmToCents` (plain/decimal values, sub-cent rounding, `null` for garbage input), and `timeAgo` for recent moments. (8 tests) |
| `test/utils/validators_test.dart` | All six `Validators` methods: `email`, `password` (6+ chars), `confirmPassword`, `phone` (Malaysian mobile, local and `+60` country-code forms), `required` (names the field in the message), and `price` (rejects empty, non-numeric, zero and negative). (12 tests) |
| `test/view_models/cart_vm_test.dart` | `CartViewModel`: starts empty; adds an item and computes subtotal + service fee; merges identical lines by quantity; keeps distinct lines when add-ons differ; increment/decrement adjusts quantity; decrementing to zero removes the line and drops the empty stall group; groups items across multiple stalls; `clear()` empties everything. (8 tests) |
| `test/view_models/wallet_vm_test.dart` | `WalletViewModel.topUp` (adds to balance + records a `topup` entry; fails cleanly for an unknown user) and `WalletRepository` payments (`deductPayment` subtracts and records; `deductPayment` rejects insufficient balance and changes nothing; `withdraw` subtracts and records; `refund` credits). (6 tests) |
| `test/widgets/order_status_stepper_test.dart` | `OrderStatusStepper` widget: `preparing` highlights only the first step; `ready` fills the first two; `collected` fills all three; `cancelled` shows the cancelled banner instead of the steps. (4 tests) |
| `test/widgets/stall_card_test.dart` | `StallCard` widget: renders name, cuisine, rating and prep time; shows the Open badge for an open stall and the Closed badge for a closed one; shows "New" instead of a rating when unreviewed; falls back to "Food" when cuisine is empty; fires `onTap`. (6 tests) |
| `test/widgets/wallet_balance_card_test.dart` | `WalletBalanceCard` widget: displays the formatted balance; displays a zero balance; supports a custom label. (3 tests) |

### 6.2 Automated / integration testing

**Firebase Test Lab Robo test: not implemented.** There is no Robo test configuration, no Robo
script (`robo_script.json`), no `gcloud firebase test android run` invocation, and no CI config
anywhere in the repository. Nothing in the codebase records "which sections were tested" by a
Robo run.

**Hardcoded login credentials for bypassing the login screen: not implemented — and deliberately
so.** No hardcoded email/password exists anywhere in `lib/`, `test/` or `integration_test/`. The
one integration test that logs in reads its credentials from **compile-time environment
variables** (`--dart-define`) precisely so that no credentials live in the repo, and it **skips
itself** when those variables are absent.

What *does* exist is a Flutter integration test.

**File:** `integration_test/app_test.dart` (the entire file):

```dart
// Integration tests. Run on a real device/emulator with Firebase configured:
//
//   flutter test integration_test
//
// The login test needs a pre-created customer account, passed at run time so
// no credentials live in the repo:
//
//   flutter test integration_test --dart-define=TEST_EMAIL=you@test.com \
//       --dart-define=TEST_PASSWORD=secret123
//
// Without those defines the login test is skipped and only the boot smoke
// test runs. Vendor/admin flows (mark ready, QR scan, approve, refund) need
// camera hardware and seeded backend state, so they remain manual test cases.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stallhop/features/auth/view/login_page.dart';
import 'package:stallhop/main.dart' as app;

const testEmail = String.fromEnvironment('TEST_EMAIL');
const testPassword = String.fromEnvironment('TEST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to a stable first screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Signed out → login page; a remembered session → a role home. Either
    // way the app must get past the splash without crashing.
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'customer can log in and land on their home',
    skip: testEmail.isEmpty,
    (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      if (find.byType(LoginPage).evaluate().isEmpty) {
        // A previous session is still signed in; nothing to test here.
        return;
      }

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), testEmail);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Customer shell shows the four bottom-nav tabs.
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Wallet'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
    },
  );
}
```

Summary of what the integration test actually does:

- **Sections covered:** (1) app boot — the app must get past the splash to a stable `Scaffold`
  with no spinner left on screen; (2) the customer login flow — enter email + password, tap
  "Log in", and assert the customer shell's bottom-nav tabs (Orders / Wallet / Profile) appear.
- **How the login is supplied:** through `String.fromEnvironment('TEST_EMAIL')` /
  `String.fromEnvironment('TEST_PASSWORD')`, passed at run time with
  `--dart-define`. It is a **real login through the UI**, not a bypass — there is no injected
  fake auth state and no seeded session.
- **Skip behaviour:** `skip: testEmail.isEmpty` means that without the `--dart-define` flags only
  the boot smoke test runs.
- **Not covered by any automated test:** vendor and admin flows (mark ready, QR scan, complete,
  approve/reject/suspend a stall, refund/dismiss a dispute, publish an announcement). The file's
  own header comment states these "need camera hardware and seeded backend state, so they remain
  manual test cases."

> **If the report must describe a Robo test**, it has to be run and documented separately — the
> repository contains no evidence of one. Do not claim a hardcoded-login bypass exists; it does not.

---

## 7. Known deviations from the original proposal

Compared against `StallHop_Technical_Specification.html` and `StallHop_Implementation_Plan.html`
in the repository root.

| # | Planned | Built | Reason (where known) |
| --- | --- | --- | --- |
| 1 | **Firebase Cloud Functions** (Node/TypeScript) for `onOrderCreated`, `onOrderStatusChange`, `onAnnouncementCreated`, `onReviewCreated`, `resetPickupCodeDaily` (Plan Phase 8) | **No `functions/` directory; no Cloud Functions at all.** Every one of those behaviours is reimplemented client-side. | The plan itself allowed this: *"If Cloud Functions adds too much complexity for your team, implement the refund and notification logic client-side in the vendor/admin ViewModels… The key is that the automation behaviour exists."* |
| 2 | **`resetPickupCodeDaily`** — scheduled function resetting the pickup counter at midnight | Reset happens **lazily inside the `placeOrder` transaction**: a `pickupCodeDate` (`yyyy-MM-dd`) key is stored on `config/venue`; if it is not today's key, the counter restarts at 1. (`order_repository.dart`) | Same as #1 — no server. Side effect: the counter resets on the **first order of a new day**, not at midnight. |
| 3 | **Firebase Cloud Messaging (FCM)** push notifications — `firebase_messaging`, `messaging_service.dart`, device token stored in `users/{uid}.fcmToken`, topic broadcast for announcements (Plan Phase 8/9, Spec §13.2) | **No FCM.** `firebase_messaging` is not a dependency and `lib/core/services/messaging_service.dart` does not exist. Replaced by `flutter_local_notifications` + `NotificationCoordinator`, which watches Firestore on-device and raises **local** notifications. | Stated in `pubspec.yaml` (*"Notifications (in-app/local — no FCM; see Phase 8 decision)"*) and in the class doc for `NotificationCoordinator`. **Accepted limitation:** notifications only arrive while the app process is alive — a killed app receives nothing, because there is no server to push to it. |
| 4 | `users/{uid}.fcmToken` populated on login | The `fcmToken` field **exists on the `AppUser` model** and is serialized, but **nothing ever writes a token to it** — it is always `null`. | Follows from #3. |
| 5 | **Maps & Location** — `google_maps_flutter` to display stall locations in the venue, `geolocator` for location (Spec §13.3) | **Not implemented.** Both packages are still in `pubspec.yaml` but are **never imported anywhere in `lib/`**. `Stall.latitude` / `Stall.longitude` and `VenueConfig.latitude` / `longitude` exist on the models but are never written or read by any screen. No location permission is requested. | Not recorded in the code. Effectively dropped from scope. |
| 6 | Vendor order queue with **three** tabs: *New \| Preparing \| Ready* (Spec §11.2) | **Two** tabs: *Preparing \| Ready*. There is no `new` order status — an order is created directly as `preparing` (`AppConstants.orderPreparing`, set in `placeOrder`). | The order status enum in the code is `preparing / ready / collected / cancelled` — no `new` state exists. |
| 7 | Admin vendor-management **search bar** (Spec §12.2) | **Not implemented.** `vendor_management_page.dart` has no search field. | Not recorded. |
| 8 | Admin settings — optional **per-stall commission override** (Spec §12.5) | **Not implemented.** Only one venue-wide rate exists (`config/venue.defaultCommission`). Worse, that rate is **not read back by the pricing logic**: `placeOrder` uses `stall.commissionRate` (fixed at 0.10 when the stall is created) and `cancelAndRefund` uses the `AppConstants.defaultCommissionRate` constant. Editing the admin commission has no effect on existing orders. | Not recorded — appears to be an oversight rather than a decision. Worth flagging honestly in the report's limitations section. |
| 9 | Admin wallet monitoring — "Total top-ups **today/month**, transaction volume, recent top-up list" (Spec §12.6) | Only a single **all-time total** of customer top-ups (`VenueConfigRepository.totalTopUps`), with a manual refresh button. No per-period breakdown, no recent-top-up list. | Not recorded. |
| 10 | Dispute cards showing the **reason** and a "View order record" link (Spec §12.3) | Dispute cards show pickup code, amount, stall, customer and time-since-cancellation. There is **no reason field on the order model** and no "view order record" navigation. | `FoodOrder` has no `cancellationReason` field. |
| 11 | Vendor menu list — "**Swipe to delete**" (Spec §11.4) | Delete is in an **overflow (⋯) popup menu** instead of a swipe gesture. | Not recorded. |
| 12 | Firestore **security rules** | **Not implemented.** `firebase.json` references only `firestore.indexes.json`; there is no `firestore.rules` file in the repository. All access control is client-side (queries filter by uid/role). | Not recorded. A genuine security limitation to state in the report. |
| 13 | Password reset by email | `AuthService.sendPasswordResetEmail()` is implemented, but **no screen calls it** — there is no "Forgot password?" link on the login page. Dead code. | Not recorded. |
| 14 | Reviews visible on the stall page | `ReviewRepository.watchStallReviews()` and `getStallReviews()` exist but **no screen calls them**. Customers can *write* a review, but there is **no screen that lists reviews** — a stall's rating surfaces only as the star average on `StallCard`. | Not recorded. |

### Deviations that are additions (built, not in the plan)

- **`NotificationCoordinator`** (`lib/core/services/notification_coordinator.dart`) — a client-side
  Firestore-listener service with no counterpart in the plan, created to replace the notification
  Cloud Functions. It seeds itself from the first snapshot so pre-existing orders don't fire
  notifications at login, and it starts/stops with the signed-in user.
- **Dispute `dismissed` flag** — `FoodOrder.dismissed` was added so a cancelled order can be
  resolved without a refund; the plan only described "Refund / Dismiss" buttons without a data model.
- **`ChooseRolePage`** — needed because a new Google sign-in has no role yet; the plan's auth flow
  did not describe this state (`AuthStatus.needsRoleSelection`).
