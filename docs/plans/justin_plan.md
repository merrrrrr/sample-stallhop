# Justin — Build Plan (Venue Admin role)

**Total estimate: ~50 h** (plus ~5 h paired with Mervin on the commission fix).

Work strictly top to bottom — every step only uses things built in earlier
steps. Phase 0 must be merged and you must have completed Mervin's teaching
session (the menu-management walkthrough) before you start step 1.

**The rule:** never copy-paste from the reference repo. Read a file, close it,
type your own. If you can't explain a line in the Q&A, it shouldn't be in your
submission. When stuck for more than ~30 minutes, ask for help — but ask
someone to **pair with you while you type**, not to write it for you.

---

## What "the venue admin" is

The admin runs the food court itself. They can:

1. see venue-wide analytics — orders, revenue, peak hours, top stalls
2. approve or reject new stall applications, and suspend/reactivate existing ones
3. publish announcements to everyone in the venue
4. resolve disputes — refund or dismiss cancelled orders
5. configure the venue — commission rate, service fee

**Your role has the most interesting logic and the least tricky UI.**
`AdminDashboardViewModel` is pure data aggregation with no Firestore mocking
needed for its getters, which makes it both the best file in the app to write
unit tests for and the easiest to explain in a Q&A. Lean into that.

## Your files

```
lib/features/admin/
├── repository/
│   ├── admin_stall_repository.dart
│   ├── announcement_repository.dart
│   └── dispute_repository.dart
│   (venue_config_repository.dart moves to lib/core/repository/ in step 12)
├── view_model/
│   ├── admin_dashboard_vm.dart      ⚠ most logic — and your best test target
│   ├── vendor_management_vm.dart
│   ├── announcements_vm.dart
│   └── disputes_vm.dart
└── view/
    ├── admin_dashboard_page.dart    ⚠ hardest file you own (charts)
    ├── vendor_management_page.dart
    ├── announcements_page.dart
    ├── disputes_page.dart
    └── admin_settings_page.dart
```

## Things Mervin built that you use (don't rebuild these)

| What | Where | What you call |
|---|---|---|
| `Stall`, `FoodOrder`, `Announcement`, `VenueConfig`, `WalletTransaction` | `lib/models/` | `fromJson` / `toJson` |
| `FirestoreService` | `core/services/` | `collectionStream`, `getCollection`, `setDocument` |
| `EmptyState`, `LoadingIndicator` | `widgets/` | every list screen |
| `centsToRM`, `formatDate`, `timeAgo` | `core/utils/formatters.dart` | all money and dates |
| `AppConstants` | `core/utils/constants.dart` | never type a collection name yourself |

Note you are the **only** role that reads across *all* orders and *all* stalls
rather than filtering to one user — the admin's queries are unscoped. That has a
security-rules consequence (only an admin may run them), which Mervin handles in
`firestore.rules`.

---

# STEP 1 — `AdminStallRepository` (2 h)

`lib/features/admin/repository/admin_stall_repository.dart`

**What it does:** the admin's control over the stall lifecycle. It reads every
stall in the venue and changes their `status` field. It's small — five short
methods — so it's a good first file.

**The stall lifecycle** (memorise this; it's the heart of your role):

```
  vendor creates  →  pending  ──approve──►  open  ⇄  closed   (vendor toggles)
                        │                    │
                     reject               suspend
                        ▼                    ▼
                    rejected             suspended ──reactivate──► closed
```

Reactivate goes to `closed`, **not** `open` — the stall comes back off-suspension
but the vendor decides when to actually open for business. Be ready to explain
that choice; it's a deliberate design decision, not an oversight.

- [ ] Constructor takes optional `FirebaseFirestore? db` and
      `FirestoreService? firestore`, each falling back to a real instance.
      **This is what makes your tests possible in step 13** — don't skip it.
- [ ] `Stream<List<Stall>> watchAllStalls()` —
      `_firestore.collectionStream(AppConstants.stallsCollection)
      .map((rows) => rows.map(Stall.fromJson).toList())`. Unfiltered: the admin
      sees every stall in every state.
- [ ] A private `Future<void> _setStatus(String stallId, String status)` doing
      the `update` with `status` and `updatedAt`.
- [ ] Four one-line public methods over it: `approve` → `stallOpen`,
      `reject` → `stallRejected`, `suspend` → `stallSuspended`,
      `reactivate` → `stallClosed`. *Why four named methods instead of one
      `setStatus`?* Because the call sites then read as intent
      (`repo.approve(id)`) and you can't accidentally pass an invalid status
      string.

**`lib/features/admin/repository/admin_stall_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';

/// Admin control over stall lifecycle: approve, reject, suspend, reactivate.
class AdminStallRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  AdminStallRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService(db: db);

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  Stream<List<Stall>> watchAllStalls() {
    return _firestore
        .collectionStream(AppConstants.stallsCollection)
        .map((rows) => rows.map(Stall.fromJson).toList());
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
```

# STEP 2 — `VendorManagementViewModel` (2 h)

`lib/features/admin/view_model/vendor_management_vm.dart`

- [ ] Subscribes to `watchAllStalls()` in the constructor. Holds
      `List<Stall> _stalls` and `bool _loading`.
- [ ] **`onError` handler on the `.listen()`** — `debugPrint`, set
      `_loading = false`, `notifyListeners()`. Without it a permission error
      leaves the screen spinning forever with no clue why. This is the most
      common bug you will hit.
- [ ] Two computed getters splitting the one list:
      - `pending` — status `pending`. These need an approve/reject decision.
      - `managed` — status in `[open, closed, suspended]`. Already-approved
        stalls the admin can suspend or restore.
      Note `rejected` stalls appear in **neither** — they're archived.
- [ ] Passthroughs: `approve(stall)`, `reject(stall)`, `suspend(stall)`,
      `reactivate(stall)`.
- [ ] `dispose()` → `_sub?.cancel()`.

**`lib/features/admin/view_model/vendor_management_vm.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';
import '../repository/admin_stall_repository.dart';

/// Splits stalls into pending-approval and active/managed buckets.
class VendorManagementViewModel extends ChangeNotifier {
  final AdminStallRepository _repository;
  StreamSubscription<List<Stall>>? _sub;

  List<Stall> _stalls = [];
  bool _loading = true;

  VendorManagementViewModel({AdminStallRepository? repository})
      : _repository = repository ?? AdminStallRepository() {
    _sub = _repository.watchAllStalls().listen(
      (stalls) {
        _stalls = stalls;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('VendorManagementViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _loading;

  List<Stall> get pending => _stalls
      .where((s) => s.status == AppConstants.stallPending)
      .toList();

  /// Approved stalls (open/closed) plus suspended ones the admin can restore.
  List<Stall> get managed => _stalls
      .where((s) => const [
            AppConstants.stallOpen,
            AppConstants.stallClosed,
            AppConstants.stallSuspended,
          ].contains(s.status))
      .toList();

  Future<void> approve(Stall stall) => _repository.approve(stall.stallId);
  Future<void> reject(Stall stall) => _repository.reject(stall.stallId);
  Future<void> suspend(Stall stall) => _repository.suspend(stall.stallId);
  Future<void> reactivate(Stall stall) =>
      _repository.reactivate(stall.stallId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

# STEP 3 — `vendor_management_page.dart` (6 h)

`lib/features/admin/view/vendor_management_page.dart`

- [ ] `DefaultTabController` with two tabs: "Pending" (with a badge showing
      `vm.pending.length` — this is an action queue) and "All stalls".
- [ ] Pending card: stall name, cuisine, description, vendor, submitted date
      via `formatDate(stall.createdAt)`. Two buttons — **Approve** (green) and
      **Reject** (red, behind an `AlertDialog` because rejection is
      effectively final).
- [ ] Managed card: name, cuisine, a status chip colour-coded per status,
      rating and review count. Action depends on status — `open`/`closed` →
      Suspend (confirm first); `suspended` → Reactivate.
- [ ] `EmptyState` per tab.
- [ ] **Test the real effect with your teammates:** approve Yong Jun's pending
      stall and confirm it appears in Mervin's customer browse; suspend it and
      confirm it disappears. That link — your `status` write driving the
      customer's `whereIn ['open','closed']` query — is the thing to demo.

**`lib/features/admin/view/vendor_management_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../view_model/vendor_management_vm.dart';

class VendorManagementPage extends StatelessWidget {
  const VendorManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VendorManagementViewModel(),
      child: const _VendorManagementView(),
    );
  }
}

class _VendorManagementView extends StatelessWidget {
  const _VendorManagementView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorManagementViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : (vm.pending.isEmpty && vm.managed.isEmpty)
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No stalls yet',
                  subtitle: 'Vendor stalls will appear here for approval.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Pending approval (${vm.pending.length})',
                        style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    if (vm.pending.isEmpty)
                      Text('Nothing awaiting approval.',
                          style: AppTextStyles.bodySecondary)
                    else
                      for (final stall in vm.pending)
                        _PendingCard(stall: stall, vm: vm),
                    const SizedBox(height: 24),
                    Text('Active stalls (${vm.managed.length})',
                        style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    if (vm.managed.isEmpty)
                      Text('No active stalls.',
                          style: AppTextStyles.bodySecondary)
                    else
                      for (final stall in vm.managed)
                        _ManagedTile(stall: stall, vm: vm),
                  ],
                ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Stall stall;
  final VendorManagementViewModel vm;
  const _PendingCard({required this.stall, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stall.name, style: AppTextStyles.title),
            Text(stall.cuisine, style: AppTextStyles.bodySecondary),
            if (stall.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(stall.description, style: AppTextStyles.caption),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => vm.reject(stall),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal),
                    onPressed: () => vm.approve(stall),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagedTile extends StatelessWidget {
  final Stall stall;
  final VendorManagementViewModel vm;
  const _ManagedTile({required this.stall, required this.vm});

  Color get _color {
    switch (stall.status) {
      case AppConstants.stallOpen:
        return AppColors.teal;
      case AppConstants.stallSuspended:
        return AppColors.error;
      default:
        return AppColors.warmGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = stall.status == AppConstants.stallSuspended;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(stall.name, style: AppTextStyles.title),
        subtitle: Text(
          '${stall.cuisine} • ${stall.totalReviews} reviews',
          style: AppTextStyles.caption,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                stall.status,
                style: AppTextStyles.caption.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'suspend') vm.suspend(stall);
                if (value == 'reactivate') vm.reactivate(stall);
              },
              itemBuilder: (_) => [
                if (suspended)
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Text('Reactivate'),
                  )
                else
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspend',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

# STEP 4 — `AnnouncementRepository` (2 h)

`lib/features/admin/repository/announcement_repository.dart`

- [ ] `watchAnnouncements()` — `announcements` ordered by `createdAt`
      descending, `.limit(50)`. The limit matters: without it the query grows
      unbounded over the venue's lifetime.
- [ ] `create({title, message, createdBy})` — generate the doc id first, build
      an `Announcement` with `createdAt: DateTime.now()`, then `set`.
      `createdBy` is the admin's uid, which Mervin's `NotificationCoordinator`
      uses to avoid notifying the author about their own announcement.
- [ ] `delete(announcementId)`

**`lib/features/admin/repository/announcement_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  AnnouncementRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService(db: db);

  Stream<List<Announcement>> watchAnnouncements() {
    return _firestore
        .collectionStream(
          AppConstants.announcementsCollection,
          query: (q) => q.orderBy('createdAt', descending: true).limit(50),
        )
        .map((rows) => rows.map(Announcement.fromJson).toList());
  }

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

  Future<void> delete(String announcementId) {
    return _db
        .collection(AppConstants.announcementsCollection)
        .doc(announcementId)
        .delete();
  }
}
```

# STEP 5 — `AnnouncementsViewModel` (1.5 h)

`lib/features/admin/view_model/announcements_vm.dart`

- [ ] Exposes `Stream<List<Announcement>> get announcements` directly from the
      repository (a `StreamBuilder` in the view consumes it) — note this VM
      does **not** hold a subscription, unlike your others. Simpler is fine
      here because there's no derived state; be able to say why the two
      patterns differ.
- [ ] `publish({title, message, createdBy})` with `_sending` and `_error`
      state; trims the inputs; returns `bool`. Catch the exception and set a
      friendly message rather than letting it reach the UI.
- [ ] `delete(id)`.

**`lib/features/admin/view_model/announcements_vm.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../../models/announcement.dart';
import '../repository/announcement_repository.dart';

class AnnouncementsViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;

  AnnouncementsViewModel({AnnouncementRepository? repository})
      : _repository = repository ?? AnnouncementRepository();

  bool _sending = false;
  String? _error;

  bool get isSending => _sending;
  String? get error => _error;

  Stream<List<Announcement>> get announcements =>
      _repository.watchAnnouncements();

  Future<bool> publish({
    required String title,
    required String message,
    required String createdBy,
  }) async {
    _error = null;
    _sending = true;
    notifyListeners();
    try {
      await _repository.create(
        title: title.trim(),
        message: message.trim(),
        createdBy: createdBy,
      );
      return true;
    } catch (e) {
      _error = 'Could not publish announcement.';
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) => _repository.delete(id);
}
```

# STEP 6 — `announcements_page.dart` (5 h)

`lib/features/admin/view/announcements_page.dart`

- [ ] `StreamBuilder<List<Announcement>>` over `vm.announcements` with the
      three states: loading → `LoadingIndicator`, empty → `EmptyState`,
      data → list.
- [ ] Each card: title, message, `timeAgo(createdAt)`, delete action behind a
      confirmation.
- [ ] `FloatingActionButton` → a compose dialog or sheet with title and message
      fields (`Validators.required` on both) → `vm.publish(...)` using
      `context.read<AuthViewModel>().currentUser!.uid` as `createdBy`.
- [ ] Disable the send button while `vm.isSending` so a double-tap can't publish
      twice.
- [ ] **Demo-worthy:** publish an announcement with a teammate's device signed
      in and watch the local notification fire on their device. That's Mervin's
      `NotificationCoordinator` reacting to your write.

**`lib/features/admin/view/announcements_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/announcement.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/announcements_vm.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnnouncementsViewModel(),
      child: const _AnnouncementsView(),
    );
  }
}

class _AnnouncementsView extends StatefulWidget {
  const _AnnouncementsView();

  @override
  State<_AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends State<_AnnouncementsView> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AnnouncementsViewModel>();
    final uid = context.read<AuthViewModel>().currentUser?.uid ?? '';
    final ok = await vm.publish(
      title: _title.text,
      message: _message.text,
      createdBy: uid,
    );
    if (!mounted) return;
    if (ok) {
      _title.clear();
      _message.clear();
      FocusScope.of(context).unfocus();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Announcement published' : (vm.error ?? 'Failed')),
        backgroundColor: ok ? null : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnnouncementsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => Validators.required(v, 'Title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _message,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: (v) => Validators.required(v, 'Message'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Publish'),
                  onPressed: vm.isSending ? null : _publish,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          StreamBuilder<List<Announcement>>(
            stream: vm.announcements,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                );
              }
              return Column(
                children: [
                  for (final a in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a.title, style: AppTextStyles.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.message),
                            const SizedBox(height: 4),
                            Text(formatDateTime(a.createdAt),
                                style: AppTextStyles.caption),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                          onPressed: () => vm.delete(a.announcementId),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

# STEP 7 — `DisputeRepository` (4 h) — ⚠ the only place you write money

`repository/dispute_repository.dart`

**The concept: a dispute is a cancelled order.** There is no separate disputes
collection. A cancelled order is an **open dispute** while it has been
**neither refunded nor dismissed**; setting either flag resolves it.

```
order cancelled  →  refunded == false && dismissed == false  →  OPEN
                 →  refunded == true                          →  resolved (customer paid back)
                 →  dismissed == true                         →  resolved (no refund)
```

- [ ] `Stream<List<FoodOrder>> watchCancelledOrders()` — `orders` where
      `status == cancelled`, ordered `createdAt` descending. The view model
      splits open from resolved; the query doesn't.
- [ ] **`Future<void> refund(FoodOrder order)`** — this is the one method in
      your whole role that touches a wallet, so take it slowly.
      - Guard first: `if (order.refunded) return;` — idempotence, so a
        double-tap can't pay twice.
      - Inside `_db.runTransaction((txn) async { ... })`:
        - **Read before write** — `txn.get(customerRef)` first. Firestore
          requires *all* reads before *any* write in a transaction, and
          violating it throws at runtime, not compile time.
        - `before = data['walletBalance'] ?? 0`; `after = before + order.total`.
        - `txn.update(customerRef, {'walletBalance': after, 'updatedAt': ...})`
        - `txn.update(orderRef, {'refunded': true, 'updatedAt': ...})`
        - `txn.set(txnRef, WalletTransaction(...).toJson())` with
          `type: txnRefund`, `amount: order.total`, `balanceBefore: before`,
          `balanceAfter: after`, `relatedOrderId: order.orderId`, and a
          description like `'Admin refund • Order ${order.pickupCode}'`.
      - The whole point of the transaction is that the balance change and its
        ledger entry either both happen or neither does. **Be ready to explain
        what would go wrong without it** (a credited balance with no ledger row
        — an unauditable wallet).
      - Note this refunds `order.total` (what the customer paid, including the
        service fee) and does **not** claw back from the vendor — an admin
        refund is the venue absorbing the cost. That's a deliberate difference
        from the vendor's own `cancelAndRefund`, which does reverse the vendor's
        earning. Know the difference.
- [ ] `Future<void> dismiss(FoodOrder order)` — a plain update setting
      `dismissed: true`. No money moves.

**`lib/features/admin/repository/dispute_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/transaction.dart';

/// Disputes are cancelled orders. One is *open* while it has been neither
/// refunded nor dismissed by an admin.
class DisputeRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  DisputeRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService(db: db);

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
}
```

# STEP 8 — `DisputesViewModel` (1.5 h)

`lib/features/admin/view_model/disputes_vm.dart`

- [ ] Subscribes to `watchCancelledOrders()` (`onError` handler as always).
- [ ] `open` → `!o.refunded && !o.dismissed`; `resolved` → `o.refunded || o.dismissed`.
- [ ] `refund(order)` and `dismiss(order)` wrapped in a `_busy` flag set before
      the await and cleared in a `finally` — the UI disables buttons while busy
      so a double-tap can't fire two refunds.
- [ ] `dispose()` cancels.

**`lib/features/admin/view_model/disputes_vm.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/order.dart';
import '../repository/dispute_repository.dart';

class DisputesViewModel extends ChangeNotifier {
  final DisputeRepository _repository;
  StreamSubscription<List<FoodOrder>>? _sub;

  List<FoodOrder> _cancelled = [];
  bool _loading = true;
  bool _busy = false;

  DisputesViewModel({DisputeRepository? repository})
      : _repository = repository ?? DisputeRepository() {
    _sub = _repository.watchCancelledOrders().listen(
      (orders) {
        _cancelled = orders;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('DisputesViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _loading;
  bool get isBusy => _busy;

  /// Cancelled orders neither refunded nor dismissed.
  List<FoodOrder> get open =>
      _cancelled.where((o) => !o.refunded && !o.dismissed).toList();

  List<FoodOrder> get resolved =>
      _cancelled.where((o) => o.refunded || o.dismissed).toList();

  Future<void> refund(FoodOrder order) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.refund(order);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> dismiss(FoodOrder order) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.dismiss(order);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

# STEP 9 — `disputes_page.dart` (6 h)

`lib/features/admin/view/disputes_page.dart`

> Note the optional `viewModel` constructor parameter. Production leaves it
> null and the page builds its own VM; your step-13 widget test passes one
> backed by `FakeFirebaseFirestore`. Without that hook the page cannot be
> tested without a live Firebase — be ready to explain why the test uses
> `.value` rather than `create:` (the test owns and disposes the VM).

- [ ] Two tabs: "Open" (count badge) and "Resolved".
- [ ] Dispute card: pickup code, customer name, stall name,
      `centsToRM(order.total)`, cancellation time, and the item list.
- [ ] Open cards get **Refund** and **Dismiss**, both behind `AlertDialog`
      confirmations — refund moves real money and must not be a single tap.
- [ ] Resolved cards show which resolution was applied ("Refunded" vs
      "Dismissed"), derived from the two flags.
- [ ] Disable both buttons while `vm.isBusy`.
- [ ] `EmptyState` per tab — "No open disputes" is a good outcome, so word it
      positively.

**`lib/features/admin/view/disputes_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../view_model/disputes_vm.dart';

class DisputesPage extends StatelessWidget {
  /// Optional injected view model. Production leaves this null and the page
  /// builds its own; widget tests pass one backed by FakeFirebaseFirestore,
  /// which is the only reason this page is testable without a live Firebase.
  final DisputesViewModel? viewModel;

  const DisputesPage({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final injected = viewModel;
    if (injected != null) {
      // .value, not create: the test owns this VM's lifecycle and disposes it.
      return ChangeNotifierProvider<DisputesViewModel>.value(
        value: injected,
        child: const _DisputesView(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => DisputesViewModel(),
      child: const _DisputesView(),
    );
  }
}

class _DisputesView extends StatelessWidget {
  const _DisputesView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DisputesViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Disputes'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Open (${vm.open.length})'),
              Tab(text: 'Resolved (${vm.resolved.length})'),
            ],
          ),
        ),
        body: vm.isLoading
            ? const LoadingIndicator()
            : TabBarView(
                children: [
                  _DisputeList(orders: vm.open, vm: vm, isOpen: true),
                  _DisputeList(orders: vm.resolved, vm: vm, isOpen: false),
                ],
              ),
      ),
    );
  }
}

class _DisputeList extends StatelessWidget {
  final List<FoodOrder> orders;
  final DisputesViewModel vm;
  final bool isOpen;

  const _DisputeList({
    required this.orders,
    required this.vm,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: isOpen ? Icons.gavel_outlined : Icons.check_circle_outline,
        title: isOpen ? 'No open disputes' : 'No resolved disputes',
        subtitle: isOpen
            ? 'Cancelled orders awaiting a refund decision appear here.'
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) =>
          _DisputeCard(order: orders[i], vm: vm, isOpen: isOpen),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final FoodOrder order;
  final DisputesViewModel vm;
  final bool isOpen;

  const _DisputeCard({
    required this.order,
    required this.vm,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${order.pickupCode}',
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.orange)),
                Text(centsToRM(order.total), style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 4),
            Text('${order.stallName} • ${order.customerName}',
                style: AppTextStyles.bodySecondary),
            Text('Cancelled ${timeAgo(order.cancelledAt ?? order.updatedAt)}',
                style: AppTextStyles.caption),
            if (!isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    order.refunded ? Icons.payments : Icons.block,
                    size: 16,
                    color: order.refunded
                        ? AppColors.teal
                        : AppColors.warmGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.refunded ? 'Refunded' : 'Dismissed',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
            if (isOpen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          vm.isBusy ? null : () => vm.dismiss(order),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal),
                      onPressed: vm.isBusy ? null : () => vm.refund(order),
                      child: Text('Refund ${centsToRM(order.total)}'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

# STEP 10 — `AdminDashboardViewModel` (5 h) — ⚠ most logic in your role

`view_model/admin_dashboard_vm.dart`. Pure aggregation over two streams. Every
getter below is a plain function of already-loaded lists, which means **you can
unit-test all of them with no Firestore at all** — construct `FoodOrder`
objects directly. This is your best source of testing marks; step 13 depends on
writing this cleanly.

- [ ] `enum DateRange { today, week, month }` declared at the top of the file.
- [ ] Constructor opens **two** subscriptions — all orders (via
      `FirestoreService.collectionStream(ordersCollection)` directly, since
      there's no admin order repository) and `watchAllStalls()`. Two separate
      `StreamSubscription` fields, both cancelled in `dispose()`. `onError` on
      both.
- [ ] `setRange(DateRange)` sets `_range` and notifies — every getter below
      recomputes off it.
- [ ] `_rangeStart` — `today` → midnight today (`DateTime(now.year, now.month,
      now.day)`); `week` → `now.subtract(Duration(days: 7))`; `month` →
      30 days back.
- [ ] `_rangeOrders` — private: orders after `_rangeStart` **excluding
      cancelled**. Every KPI builds on this, so getting the exclusion right
      here fixes it everywhere.
- [ ] `totalOrders` → `_rangeOrders.length`
- [ ] `revenue` → fold of `o.total` in cents (gross order value).
- [ ] `activeStalls` → stalls with status `open`; `pendingStalls` → status
      `pending` (drives the badge on your vendor-management tab).
- [ ] `avgPrepMinutes` → mean of `readyAt.difference(createdAt).inMinutes` over
      orders that actually reached ready. **Guard the empty case** — return 0,
      don't divide by zero.
- [ ] `ordersByHour` → `List<int>` of length 24; bucket each order by
      `createdAt.hour`. Feeds the peak-hours chart.
- [ ] `topStalls` → `List<(String, int)>` (a Dart record) of stall name and
      order count, sorted descending, **capped at 5** via `.take(5)`.
- [ ] `dispose()` cancels both.

**`lib/features/admin/view_model/admin_dashboard_vm.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../repository/admin_stall_repository.dart';

enum DateRange { today, week, month }

/// Aggregates orders and stalls into the admin KPI tiles, peak-hours chart,
/// and top-stalls list, filtered by [DateRange].
class AdminDashboardViewModel extends ChangeNotifier {
  final FirestoreService _firestore;
  final AdminStallRepository _stallRepository;

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<List<Stall>>? _stallsSub;

  List<FoodOrder> _orders = [];
  List<Stall> _stalls = [];
  bool _loading = true;
  DateRange _range = DateRange.today;

  AdminDashboardViewModel({
    FirestoreService? firestore,
    AdminStallRepository? stallRepository,
  })  : _firestore = firestore ?? FirestoreService(),
        _stallRepository = stallRepository ?? AdminStallRepository() {
    _ordersSub = _firestore
        .collectionStream(AppConstants.ordersCollection)
        .listen(
      (rows) {
        _orders = rows.map(FoodOrder.fromJson).toList();
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('AdminDashboardViewModel orders stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
    _stallsSub = _stallRepository.watchAllStalls().listen(
      (stalls) {
        _stalls = stalls;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('AdminDashboardViewModel stalls stream error: $e');
      },
    );
  }

  bool get isLoading => _loading;
  DateRange get range => _range;

  void setRange(DateRange range) {
    _range = range;
    notifyListeners();
  }

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_range) {
      case DateRange.today:
        return DateTime(now.year, now.month, now.day);
      case DateRange.week:
        return now.subtract(const Duration(days: 7));
      case DateRange.month:
        return now.subtract(const Duration(days: 30));
    }
  }

  /// Orders within the selected range, excluding cancelled ones.
  List<FoodOrder> get _rangeOrders {
    final start = _rangeStart;
    return _orders
        .where((o) =>
            o.createdAt.isAfter(start) &&
            o.status != AppConstants.orderCancelled)
        .toList();
  }

  int get totalOrders => _rangeOrders.length;

  /// Gross value of orders in range, in cents.
  int get revenue => _rangeOrders.fold(0, (acc, o) => acc + o.total);

  int get activeStalls =>
      _stalls.where((s) => s.status == AppConstants.stallOpen).length;

  int get pendingStalls =>
      _stalls.where((s) => s.status == AppConstants.stallPending).length;

  /// Mean minutes from order creation to ready, over orders that reached ready.
  double get avgPrepMinutes {
    final withReady =
        _rangeOrders.where((o) => o.readyAt != null).toList();
    if (withReady.isEmpty) return 0;
    final total = withReady.fold<int>(
      0,
      (acc, o) => acc + o.readyAt!.difference(o.createdAt).inMinutes,
    );
    return total / withReady.length;
  }

  /// Order counts bucketed by hour of day (index 0–23).
  List<int> get ordersByHour {
    final buckets = List<int>.filled(24, 0);
    for (final order in _rangeOrders) {
      buckets[order.createdAt.hour]++;
    }
    return buckets;
  }

  /// Top stalls by order count, as (stallName, orderCount), max 5.
  List<(String, int)> get topStalls {
    final counts = <String, int>{};
    for (final order in _rangeOrders) {
      counts[order.stallName] = (counts[order.stallName] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => (e.key, e.value)).toList();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _stallsSub?.cancel();
    super.dispose();
  }
}
```

# STEP 11 — ⚠ `admin_dashboard_page.dart` (12 h) — hardest file you own

324 lines. The difficulty is `fl_chart`, which has a fiddly API — budget real
time for it and build the page in three passes.

**11a — shell and KPI tiles (4 h)**
- [ ] `ChangeNotifierProvider` creating the VM; loading state first.
- [ ] A `SegmentedButton` or `ChoiceChip` row for Today / Week / Month calling
      `vm.setRange(...)`. Every tile below must visibly change when you switch
      — that's your proof the range filtering works.
- [ ] KPI tiles in a `GridView` or `Wrap`: total orders, `centsToRM(vm.revenue)`,
      active stalls, pending approvals, `vm.avgPrepMinutes.toStringAsFixed(1)`
      minutes.

**11b — peak hours chart (5 h)**
- [ ] `fl_chart` `BarChart` over `vm.ordersByHour`. 24 bars is too many to
      label — label every third hour and format as `09:00`.
- [ ] Get a static chart rendering with dummy data **first**, then wire the real
      getter. Debugging chart layout and data plumbing at the same time is
      where the hours disappear.
- [ ] Handle the all-zeros case so an empty venue doesn't render a broken axis.

**11c — top stalls (3 h)**
- [ ] A ranked list from `vm.topStalls` — position, stall name, order count,
      and a proportional bar (a `LinearProgressIndicator` against the top
      stall's count is enough; no chart library needed).
- [ ] Navigation into your other four screens, plus sign out via
      `context.read<AuthViewModel>().logout()`.

**The finished file.** Build it in the three passes above — do not type this
top to bottom in one go, or a chart layout problem and a data problem will
arrive at the same time and you won't know which is which.

Note `AdminKpiGrid` is **public** while every other section widget is private.
That is deliberate: the full page also reads `AuthViewModel` (and therefore
needs a live FirebaseAuth), which a widget test cannot construct, so the KPI
row is pulled out where step 13 can test it in isolation.

**`lib/features/admin/view/admin_dashboard_page.dart`**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/admin_dashboard_vm.dart';
import 'admin_settings_page.dart';
import 'disputes_page.dart';
import 'vendor_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _index = 0;

  static const _pages = [
    _DashboardTab(),
    VendorManagementPage(),
    DisputesPage(),
    AdminSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: 'Disputes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminDashboardViewModel(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminDashboardViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Hi, ${user?.name ?? 'Admin'}',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 12),
                _RangeSelector(vm: vm),
                const SizedBox(height: 16),
                AdminKpiGrid(vm: vm),
                const SizedBox(height: 24),
                Text('Peak hours', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                _PeakHoursChart(data: vm.ordersByHour),
                const SizedBox(height: 24),
                Text('Top stalls', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                _TopStalls(stalls: vm.topStalls),
              ],
            ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final AdminDashboardViewModel vm;
  const _RangeSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DateRange>(
      segments: const [
        ButtonSegment(value: DateRange.today, label: Text('Today')),
        ButtonSegment(value: DateRange.week, label: Text('Week')),
        ButtonSegment(value: DateRange.month, label: Text('Month')),
      ],
      selected: {vm.range},
      onSelectionChanged: (s) => vm.setRange(s.first),
    );
  }
}

/// Public on purpose: the full dashboard also needs an [AuthViewModel] (and so
/// a live FirebaseAuth), which a widget test cannot build. Keeping the KPI row
/// as its own public widget is what makes the numbers testable in isolation.
class AdminKpiGrid extends StatelessWidget {
  final AdminDashboardViewModel vm;
  const AdminKpiGrid({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _KpiTile(
          icon: Icons.receipt_long,
          label: 'Total orders',
          value: '${vm.totalOrders}',
        ),
        _KpiTile(
          icon: Icons.payments,
          label: 'Revenue',
          value: centsToRM(vm.revenue),
        ),
        _KpiTile(
          icon: Icons.storefront,
          label: 'Active stalls',
          value: '${vm.activeStalls}',
          badge: vm.pendingStalls > 0 ? '${vm.pendingStalls} pending' : null,
        ),
        _KpiTile(
          icon: Icons.schedule,
          label: 'Avg prep',
          value: vm.avgPrepMinutes == 0
              ? '—'
              : '${vm.avgPrepMinutes.toStringAsFixed(0)} min',
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.h3),
            ),
            Text(label, style: AppTextStyles.caption),
            if (badge != null)
              Text(badge!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.orange)),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of order counts by hour of day.
class _PeakHoursChart extends StatelessWidget {
  final List<int> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.isEmpty
        ? 1.0
        : (data.reduce((a, b) => a > b ? a : b)).toDouble();
    if (maxY == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'No orders in this range',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour % 4 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('$hour',
                            style: AppTextStyles.caption),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var hour = 0; hour < data.length; hour++)
                  BarChartGroupData(
                    x: hour,
                    barRods: [
                      BarChartRodData(
                        toY: data[hour].toDouble(),
                        color: AppColors.orange,
                        width: 6,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStalls extends StatelessWidget {
  final List<(String, int)> stalls;
  const _TopStalls({required this.stalls});

  @override
  Widget build(BuildContext context) {
    if (stalls.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 120,
          child: EmptyState(icon: Icons.storefront, title: 'No data yet'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < stalls.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.orangeLight,
                child: Text('${i + 1}',
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.orange)),
              ),
              title: Text(stalls[i].$1),
              trailing: Text('${stalls[i].$2} orders',
                  style: AppTextStyles.caption),
            ),
        ],
      ),
    );
  }
}
```

# STEP 12 — `VenueConfigRepository` + `admin_settings_page.dart` (5 h)

⚠ **Read `foundation_and_integration.md` §6.1 before starting this step.** The
reference repo's version of this screen writes a setting that **nothing ever
reads** — the commission control is decorative. You are building the wired
version, and the wiring itself is step 14 (paired with Mervin).

- [ ] **Create the repository at `lib/core/repository/venue_config_repository.dart`**,
      not under `features/admin/`. All three roles read the venue config now, so
      it belongs in core. You still own the writes.
- [ ] `watchConfig()` → `Stream<VenueConfig?>` from
      `documentStream('config/venue')`.
- [ ] `updateCommission(double rate)` — `setDocument` with **`merge: true`**.
      Merge is essential: the same document holds the pickup-code counter that
      Mervin's `placeOrder` bumps on every order, and a non-merged write would
      wipe it.
- [ ] `updateServiceFee(int cents)` — same pattern. *(New — the reference has
      no way to edit the service fee at all.)*
- [ ] `totalTopUps()` → sum of `amount` over transactions where
      `type == 'topup'`, for the wallet-monitoring tile.
- [ ] **`admin_settings_page.dart`** — `StreamBuilder<VenueConfig?>` showing
      venue name, commission rate as a percentage, and service fee, each with
      an edit dialog. Commission is entered as a percentage (e.g. `15`) and
      **stored as a fraction** (`0.15`) — divide by 100 on save, multiply by
      100 on display. Getting this backwards is the obvious bug here; check it
      against Firestore directly.
- [ ] Guard the input: commission between 0 and 100, service fee ≥ 0.
- [ ] Wallet monitoring tile using `totalTopUps()`.

**`lib/core/repository/venue_config_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// NOTE: this file lives at lib/core/repository/venue_config_repository.dart,
// not under features/admin/. All three roles read the venue config now, so it
// is core code. The admin still owns the *writes*.
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../../models/transaction.dart';
import '../../models/venue_config.dart';

/// Reads/writes the singleton `config/venue` document and provides wallet
/// monitoring totals for the admin settings screen.
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

  /// One-shot read, for callers that need the config once rather than as a
  /// stream (e.g. seeding the cart's service fee at checkout).
  Future<VenueConfig?> getConfig() async {
    final data = await _firestore.getDocument(_path);
    return data == null ? null : VenueConfig.fromJson(data);
  }

  /// [rate] is a FRACTION (0.15 = 15%), not a percentage. The settings page
  /// divides the typed percentage by 100 before calling this.
  ///
  /// `merge: true` is essential: this same document holds the pickup-code
  /// counter that `OrderRepository.placeOrder` bumps on every order. A
  /// non-merged write would wipe it and restart every pickup code at A001.
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

  /// Flat per-order service fee in CENTS. Same merge rule as above.
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
```

**`lib/features/admin/view/admin_settings_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/repository/venue_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/venue_config.dart';
import '../../auth/view_model/auth_view_model.dart';
import 'announcements_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _repository = VenueConfigRepository();
  late Future<int> _topUpTotal;

  @override
  void initState() {
    super.initState();
    _topUpTotal = _repository.totalTopUps();
  }

  /// Commission is TYPED as a percentage (15) and STORED as a fraction (0.15).
  /// Divide by 100 on the way in, multiply by 100 on the way out. Getting this
  /// backwards is the obvious bug on this screen — verify against Firestore.
  Future<void> _editCommission(double current) async {
    final controller = TextEditingController(
      text: (current * 100).toStringAsFixed(0),
    );
    final percent = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Commission rate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Percent',
            suffixText: '%',
            helperText: 'Applies to stalls with no override',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (percent == null) return;
    if (percent < 0 || percent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a percentage between 0 and 100')),
      );
      return;
    }
    await _repository.updateCommission(percent / 100); // <- fraction
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Commission set to ${percent.toStringAsFixed(0)}%'),
      ),
    );
  }

  /// Service fee is TYPED in Ringgit ("0.50") and STORED in cents (50).
  Future<void> _editServiceFee(int currentCents) async {
    final controller = TextEditingController(
      text: (currentCents / 100).toStringAsFixed(2),
    );
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Service fee'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'RM ',
            helperText: 'Charged once per stall order',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, rmToCents(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (cents == null) return;
    if (cents < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service fee cannot be negative')),
      );
      return;
    }
    await _repository.updateServiceFee(cents);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Service fee set to ${centsToRM(cents)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthViewModel>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Venue', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          StreamBuilder<VenueConfig?>(
            stream: _repository.watchConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data;
              final rate = config?.defaultCommission ?? 0.10;
              final fee = config?.serviceFee ?? 50;
              return Column(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront,
                          color: AppColors.orange),
                      title: const Text('Venue name'),
                      subtitle: Text(config?.venueName ?? '—'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.percent, color: AppColors.orange),
                      title: const Text('Default commission rate'),
                      subtitle: Text('${(rate * 100).toStringAsFixed(0)}% '
                          'of each order subtotal'),
                      trailing: TextButton(
                        onPressed: () => _editCommission(rate),
                        child: const Text('Edit'),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long,
                          color: AppColors.teal),
                      title: const Text('Service fee'),
                      subtitle: Text('${centsToRM(fee)} per stall order'),
                      trailing: TextButton(
                        onPressed: () => _editServiceFee(fee),
                        child: const Text('Edit'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Wallet monitoring', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Card(
            child: FutureBuilder<int>(
              future: _topUpTotal,
              builder: (context, snapshot) {
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: AppColors.teal),
                  title: const Text('Total customer top-ups'),
                  subtitle: Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Calculating…'
                        : centsToRM(snapshot.data ?? 0),
                    style: AppTextStyles.title,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {
                      _topUpTotal = _repository.totalTopUps();
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('Communication', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.campaign_outlined, color: AppColors.orange),
              title: const Text('Announcements'),
              subtitle: const Text('Broadcast a message to all users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

> ⚠ After creating the repository under `lib/core/repository/`, **delete**
> `lib/features/admin/repository/venue_config_repository.dart` and update the
> import in any file that referenced it. Leaving both copies in the tree is the
> classic way to end up editing one and running the other.

# STEP 13 — Your tests (5 h)

**Test only your own files.** Testing marks are per person.

> Code snippets for this step are not included yet — they will be added
> separately once the implementation steps above are built.

`AdminDashboardViewModel`'s getters need **no Firestore mocking** — build a
`List<FoodOrder>` in the test and assert. Easiest high-value tests in the app:

- [ ] `test/admin/admin_dashboard_vm_test.dart`
      - `revenue` sums `total` across in-range orders
      - **cancelled orders are excluded** from every KPI
      - `ordersByHour` buckets correctly and returns exactly 24 entries
      - `topStalls` sorts descending and **caps at 5**
      - `avgPrepMinutes` ignores orders with a null `readyAt`, and returns 0
        when none qualify (the divide-by-zero guard)
      - `setRange` changes which orders are counted
- [ ] `test/admin/vendor_management_vm_test.dart` — `pending` and `managed`
      bucket correctly; a `rejected` stall appears in neither.
- [ ] `test/admin/disputes_vm_test.dart` — `open` vs `resolved` splitting across
      all four flag combinations.
- [ ] `test/admin/dispute_repository_test.dart` — with `FakeFirebaseFirestore`:
      `refund` credits the exact `order.total`, sets `refunded: true`, and
      writes exactly one ledger row with matching
      `balanceBefore`/`balanceAfter`; calling `refund` twice on the same order
      credits **only once** (the idempotence guard).

Widget tests:
- [ ] `test/admin/admin_dashboard_page_test.dart` — KPI tiles render formatted
      currency from an injected fake VM.
- [ ] `test/admin/disputes_page_test.dart` — `EmptyState` with no disputes, and
      a card per open dispute.


# STEP 14 — ⚠ Commission fix, **paired with Mervin** (5 h)

This is the assignment's known defect #1 and it is jointly assigned. Sit
together for one session. **Read `foundation_and_integration.md` §6.1 in full
first** — it explains both bugs and the exact fix. Summary of who does what:

- **You drive:** the `VenueConfigRepository` move into `core/`, the
  `updateServiceFee` addition, and a new per-stall commission override control
  on `vendor_management_page.dart` (so the nullable `Stall.commissionRate` is
  actually reachable from the UI and demonstrable in the Q&A).

## 14a — the per-stall override control (your part, in code)

The repository move and `updateServiceFee` are already in step 12. What's left
is making `Stall.commissionRate` reachable from the UI. Three small additions:

**1. `lib/features/admin/repository/admin_stall_repository.dart`** — add one
method. Passing `null` clears the override and returns the stall to inheriting
the venue default, which is why the parameter is `double?` and why this uses
`update` (a field set to `null` is written as null, not dropped):

```dart
  /// Sets a per-stall commission override, or clears it with `null` so the
  /// stall inherits `config/venue.defaultCommission` again.
  ///
  /// Only an admin may write this field — enforced in `firestore.rules`.
  Future<void> setCommissionRate(String stallId, double? rate) {
    return _stalls.doc(stallId).update({
      'commissionRate': rate,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
```

**2. `lib/features/admin/view_model/vendor_management_vm.dart`** — one
passthrough, alongside `approve` / `reject` / `suspend` / `reactivate`:

```dart
  /// [rate] is a FRACTION (0.15 = 15%). Pass null to inherit the venue default.
  Future<void> setCommission(Stall stall, double? rate) =>
      _repository.setCommissionRate(stall.stallId, rate);
```

**3. `lib/features/admin/view/vendor_management_page.dart`** — surface it on
`_ManagedTile`. Add a `commission` entry to the existing `PopupMenuButton` and
the dialog it opens. Note the tile now needs a `BuildContext` to show the
dialog, so the handler takes one:

```dart
  /// Percentage in, fraction out — the same conversion as the settings page.
  /// An empty field means "inherit the venue default" and writes null.
  Future<void> _editCommission(BuildContext context) async {
    final current = stall.commissionRate;
    final controller = TextEditingController(
      text: current == null ? '' : (current * 100).toStringAsFixed(0),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commission • ${stall.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Percent',
                suffixText: '%',
                helperText: 'Leave blank to inherit the venue default',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return; // dismissed

    if (result.isEmpty) {
      await vm.setCommission(stall, null); // back to inheriting
      return;
    }
    final percent = double.tryParse(result);
    if (percent == null || percent < 0 || percent > 100) return;
    await vm.setCommission(stall, percent / 100);
  }
```

Wire it into the menu, and show the current state in the subtitle so the
override is visible without opening anything:

```dart
        subtitle: Text(
          '${stall.cuisine} • ${stall.totalReviews} reviews • '
          '${stall.commissionRate == null
              ? 'default commission'
              : '${(stall.commissionRate! * 100).toStringAsFixed(0)}% override'}',
          style: AppTextStyles.caption,
        ),
```

```dart
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'suspend') vm.suspend(stall);
                if (value == 'reactivate') vm.reactivate(stall);
                if (value == 'commission') _editCommission(context);
              },
              itemBuilder: (_) => [
                if (suspended)
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Text('Reactivate'),
                  )
                else
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspend',
                        style: TextStyle(color: AppColors.error)),
                  ),
                const PopupMenuItem(
                  value: 'commission',
                  child: Text('Set commission…'),
                ),
              ],
            ),
```
- **Mervin drives:** `OrderRepository.placeOrder` resolving the rate
  (`stall.commissionRate ?? venueConfig.defaultCommission`), storing
  `commissionRate` and `vendorEarning` on the order, and deleting the buggy
  `_commissionFor()` from the refund path.
- **Both:** the on-device verification — set venue commission to 20%, place a
  RM 10.00 order from a stall with no override, confirm the vendor's wallet
  gains exactly RM 8.00 and the order document shows `commissionRate: 0.2`,
  `vendorEarning: 800`. Then cancel it and confirm both wallets return to their
  exact prior balances.

You should come out of this able to explain, unprompted: *why* the admin
setting did nothing before, *why* the stall rate had to become nullable for the
venue default to ever apply, and *why* storing the earned amount on the order
is safer than recomputing it at refund time.

# STEP 15 — Report deliverables (4 h)

- [ ] ~10 screenshots: admin dashboard (×3 date ranges), vendor management,
      stall approval, disputes list, dispute detail, announcements, create
      announcement, admin settings. Consistent device size, light theme, seeded
      data so nothing looks empty. Name them `NN_admin_screenname.png`.
- [ ] Admin-flow wireframes.
- [ ] Admin section of the user manual.
- [ ] Your test evidence (screenshots of your suite passing).

---

## Effort summary

| Step | File | Hours |
|---|---|---|
| 1 | `admin_stall_repository.dart` | 2 |
| 2 | `vendor_management_vm.dart` | 2 |
| 3 | `vendor_management_page.dart` | 6 |
| 4 | `announcement_repository.dart` | 2 |
| 5 | `announcements_vm.dart` | 1.5 |
| 6 | `announcements_page.dart` | 5 |
| 7 | ⚠ `dispute_repository.dart` (transaction) | 4 |
| 8 | `disputes_vm.dart` | 1.5 |
| 9 | `disputes_page.dart` | 6 |
| 10 | ⚠ `admin_dashboard_vm.dart` | 5 |
| 11 | ⚠ `admin_dashboard_page.dart` (charts) | **12** |
| 12 | venue config + settings page | 5 |
| 13 | tests | 5 |
| 15 | report assets | 4 |
| | **Subtotal** | **~50 h** |
| 14 | commission fix (paired w/ Mervin) | +5 |

**Hardest file: `admin_dashboard_page.dart` (12 h)** — not because the logic is
hard (step 10 already did the thinking) but because `fl_chart` has a fiddly
API. Build the chart with dummy data first, then wire the real getter.

**Second hardest: `dispute_repository.dart` (4 h)** — it is short, but it is
the only Firestore transaction you write, and it moves real money. The
read-before-write rule and the `if (order.refunded) return;` idempotence guard
are both easy to get wrong and both are likely Q&A questions.

---

## Deviations from the reference repo (say these in the Q&A if asked)

1. **`VenueConfigRepository` lives in `lib/core/repository/`, not
   `features/admin/repository/`.** Once the commission rate genuinely drives
   pricing, all three roles read the venue config, so it is no longer
   admin-owned code. You keep the writes.
2. **`updateServiceFee` is new.** The reference has no way to edit the service
   fee, and its `VenueConfig.serviceFee` field is read by nothing — the same
   orphaned-setting bug as the commission rate.
3. **A per-stall commission override control on the vendor-management page is
   new.** It's what makes the nullable `Stall.commissionRate` reachable from
   the UI.
4. **The commission rate now actually affects order pricing** (step 14). In the
   reference repo it does not — this is the assignment's known defect #1.
