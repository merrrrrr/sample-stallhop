# Justin — Build Plan (Venue Admin role)

**Total estimate: ~50 h** (plus ~5 h paired with Mervin on the commission fix).

Work strictly top to bottom — every step only uses things built in earlier
steps.

**When you can start:** you do **not** need all of Phase 0. You need Mervin's
§0.1–§0.4 merged — `AppConstants`, the theme, `formatters.dart`,
`Validators`, `lib/models/`, and `lib/widgets/` — which is the milestone he
marks as **§0.4a**, about 16 h into his work rather than 25 h. The teaching
session happens there too.

Auth, security rules and seed data (his §0.5–§0.7) land while you are already
building; nothing in steps 1 and 4 touches them, because your stub ViewModels
do not talk to Firestore at all. Do not wait for the full Phase 0 merge — that
would idle you for an extra week for no reason.

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
| `cloud_firestore` directly | — | `_db.collection(...).snapshots()` / `.get()` — there is no wrapper service |
| `EmptyState`, `LoadingIndicator` | `widgets/` | every list screen |
| `centsToRM`, `formatDate`, `timeAgo` | `core/utils/formatters.dart` | all money and dates |
| `AppConstants` | `core/utils/constants.dart` | never type a collection name yourself |

Note you are the **only** role that reads across *all* orders and *all* stalls
rather than filtering to one user — the admin's queries are unscoped. That has a
security-rules consequence (only an admin may run them), which Mervin handles in
`firestore.rules`.

---

## How you build each slice: stub → UI → repository → real VM

Your work is grouped into four **slices**. Three of them are built UI-first:

| Slice | Steps | Order |
|---|---|---|
| Vendors | 1–3 | stub VM → page → repository → real VM |
| Announcements | 4–6 | stub VM → page → repository → real VM |
| **Disputes** | 7–9 | **repository → VM → page** (money — see below) |
| Dashboard | 10–11 | stub VM → page → real VM |

**The stub ViewModel is the whole trick.** Before you build a page, spend
fifteen minutes writing a ViewModel with the *real* class name, the *real*
getters and the *real* method signatures — but hardcoded data inside and no
Firestore at all:

```dart
/// STUB — delete the fake list in step 3, keep everything else.
class VendorManagementViewModel extends ChangeNotifier {
  final List<Stall> _fake = [
    Stall(stallId: 's1', name: 'Nasi Lemak Corner', status: AppConstants.stallPending, /* ... */),
    Stall(stallId: 's2', name: 'Wan Tan Mee',       status: AppConstants.stallOpen,    /* ... */),
    Stall(stallId: 's3', name: 'Roti Canai Bakar',  status: AppConstants.stallSuspended, /* ... */),
  ];

  bool get isLoading => false;          // flip to true by hand to check your spinner

  List<Stall> get pending =>
      _fake.where((s) => s.status == AppConstants.stallPending).toList();
  List<Stall> get managed => _fake
      .where((s) => s.status != AppConstants.stallPending &&
                    s.status != AppConstants.stallRejected)
      .toList();

  Future<void> approve(Stall s) async {}    // no-ops for now
  Future<void> reject(Stall s) async {}
  Future<void> suspend(Stall s) async {}
  Future<void> reactivate(Stall s) async {}
}
```

Why this and not a hardcoded `List` inside the widget:

- The page you write against this stub is the **final** page. When step 3
  replaces the stub with the real stream-backed ViewModel, the page does not
  change at all — same `context.watch<VendorManagementViewModel>()`, same
  getters. That is the difference between *integrating* and *rewriting*.
- It forces you to design the VM's API before you need its implementation,
  which is the part that is hard to change later.
- No Firebase, no emulator, no seed data. Hot reload is instant, so the 12 h
  dashboard is 12 h of actual layout work rather than waiting on queries.
- Give the stub `isLoading`, an empty-list case and an error case from day one.
  Flip them by hand and check the page renders `LoadingIndicator` and
  `EmptyState` properly. Pages built on always-present fake data are exactly
  the pages that have no loading state when the real stream arrives.

**Delete the stub in the same commit that adds the real ViewModel.** A stub
that survives into the final submission is a bug and an obvious Q&A target.

### The exception: money is built logic-first

The disputes slice (steps 7–9) runs the other way round — repository, then
ViewModel, then page — because `DisputeRepository.refund` is the only place in
your role that writes money, and it writes it inside a Firestore transaction.
That code gets written and **unit-tested against `fake_cloud_firestore` before
any UI exists**, because a wrong refund amount discovered during a late
integration crunch is the one failure here you cannot recover from in a demo.
The same rule applies to step 14's commission fix.

Everywhere else the UI is the risky, slow, fiddly part and the logic is simple,
so UI goes first.

---

# STEP 1 — `vendor_management_page.dart` (6 h)

`lib/features/admin/view/vendor_management_page.dart`

> **Stub first (15 min).** Write `VendorManagementViewModel` as the stub shown
> in "How you build each slice" above, then build this entire page against it.
> No Firestore, no emulator — just hot reload. Steps 2 and 3 replace the stub's
> internals; this file will not change when they do.

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

# STEP 2 — `AdminStallRepository` (2 h)

`lib/features/admin/repository/admin_stall_repository.dart`

**What it does:** the admin's control over the stall lifecycle. It reads every
stall in the venue and changes their `status` field. It's small — five short
methods — so it's a gentle first repository, and you already know exactly what
it has to provide because step 1's page has been calling the stubbed version of
it all week.

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

- [ ] Constructor takes an optional `FirebaseFirestore? db` falling back to
      `FirebaseFirestore.instance`. **This is what makes your tests possible in
      step 13** — don't skip it. Every repository in the app has this one
      parameter and nothing else.
- [ ] `Stream<List<Stall>> watchAllStalls()` — `_stalls.snapshots()` mapped
      through `Stall.fromJson(d.data())`. Unfiltered: the admin sees every
      stall in every state.
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

import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';

/// Admin control over stall lifecycle: approve, reject, suspend, reactivate.
class AdminStallRepository {
  final FirebaseFirestore _db;

  AdminStallRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);

  Stream<List<Stall>> watchAllStalls() {
    return _stalls.snapshots().map(
          (snap) => snap.docs.map((d) => Stall.fromJson(d.data())).toList(),
        );
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

# STEP 3 — `VendorManagementViewModel` (2 h)

`lib/features/admin/view_model/vendor_management_vm.dart`

> **This replaces your stub.** Same class name, same getters (`isLoading`,
> `pending`, `managed`), same four methods — only the insides change, from a
> hardcoded list to a live subscription. `vendor_management_page.dart` should
> need **zero** edits. If it needs any, note what and why: that difference is
> the thing you got wrong in your stub's API, and it is worth saying out loud
> in the Q&A.

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
- [ ] **Delete the stub file in this same commit.** Nothing should ship with
      two definitions of this class.

**Wire and verify before moving on (do not batch this up):**

- [ ] Seeded stalls actually appear, in the right tab, from Firestore.
- [ ] Approve a stall → the row moves from Pending to All stalls **by itself**,
      because the stream re-fires. You are not calling `setState` anywhere.
- [ ] Kill your network / break a rule deliberately → the spinner stops and you
      get a `debugPrint`, rather than spinning forever. This is the `onError`
      path and it is the bug the stub cannot teach you about.
- [ ] Empty collection → `EmptyState` renders, not a blank screen.

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

# STEP 4 — `announcements_page.dart` (5 h)

`lib/features/admin/view/announcements_page.dart`

> **Stub first (15 min).** Write `AnnouncementsViewModel` with the real shape —
> `Stream<List<Announcement>> get announcements => Stream.value([...two fakes...])`,
> plus `isSending`, `error`, a `publish(...)` that just returns `true`, and a
> no-op `delete(id)`. Note this VM exposes a **stream**, not a list, because the
> view drives it with a `StreamBuilder` (see step 6 for why this one differs
> from your others) — so stub it as a stream too, or the page you write here
> will not match the real thing. Use `Stream.empty()` briefly to confirm your
> `EmptyState` renders.

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

# STEP 5 — `AnnouncementRepository` (2 h)

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

import '../../../core/utils/constants.dart';
import '../../../models/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _db;

  AnnouncementRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection(AppConstants.announcementsCollection);

  Stream<List<Announcement>> watchAnnouncements() {
    return _announcements
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Announcement.fromJson(d.data())).toList());
  }

  Future<void> create({
    required String title,
    required String message,
    required String createdBy,
  }) async {
    final ref = _announcements.doc();
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
    return _announcements.doc(announcementId).delete();
  }
}
```

# STEP 6 — `AnnouncementsViewModel` (1.5 h)

`lib/features/admin/view_model/announcements_vm.dart`

> **This replaces your stub.** The stub already returned a
> `Stream<List<Announcement>>` (via `Stream.value`); here it becomes the
> repository's real stream. `announcements_page.dart` should need zero edits.
> Delete the stub in this commit.

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

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/transaction.dart';

/// Disputes are cancelled orders. One is *open* while it has been neither
/// refunded nor dismissed by an admin.
class DisputeRepository {
  final FirebaseFirestore _db;

  DisputeRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(AppConstants.ordersCollection);

  /// All cancelled orders; the view model splits them into open/resolved.
  Stream<List<FoodOrder>> watchCancelledOrders() {
    return _orders
        .where('status', isEqualTo: AppConstants.orderCancelled)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FoodOrder.fromJson(d.data())).toList());
  }

  /// Credits the customer the full order total and marks the order refunded,
  /// atomically with the ledger entry.
  Future<void> refund(FoodOrder order) async {
    if (order.refunded) return;
    final now = DateTime.now();
    await _db.runTransaction((txn) async {
      final orderRef = _orders.doc(order.orderId);
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
    return _orders.doc(order.orderId).update({
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

# STEP 10 — ⚠ `admin_dashboard_page.dart` (12 h) — hardest file you own

324 lines. The difficulty is `fl_chart`, which has a fiddly API — budget real
time for it and build the page in three passes.

> **Stub first (30 min — worth more here than anywhere else).** Write
> `AdminDashboardViewModel` with `enum DateRange { today, week, month }`, a
> `setRange(...)` that just swaps which hardcoded set you return, and every
> getter step 11 will eventually compute for real: `isLoading`, `totalOrders`,
> `revenue`, `activeStalls`, `pendingApprovals`, `avgPrepMinutes`,
> `ordersByHour` (a `Map<int,int>` — hardcode a plausible lunch spike so the
> chart has a recognisable shape), and `topStalls`.
>
> Make the three ranges return **visibly different** numbers. That is what lets
> you verify the range selector wiring here, twelve hours before the real
> aggregation exists — and `fl_chart` is far easier to fight with data you
> control than with whatever the seed script happened to produce.

**10a — shell and KPI tiles (4 h)**
- [ ] `ChangeNotifierProvider` creating the VM; loading state first.
- [ ] A `SegmentedButton` or `ChoiceChip` row for Today / Week / Month calling
      `vm.setRange(...)`. Every tile below must visibly change when you switch
      — that's your proof the range filtering works.
- [ ] KPI tiles in a `GridView` or `Wrap`: total orders, `centsToRM(vm.revenue)`,
      active stalls, pending approvals, `vm.avgPrepMinutes.toStringAsFixed(1)`
      minutes.

**10b — peak hours chart (5 h)**
- [ ] `fl_chart` `BarChart` over `vm.ordersByHour`. 24 bars is too many to
      label — label every third hour and format as `09:00`.
- [ ] Get a static chart rendering with dummy data **first**, then wire the real
      getter. Debugging chart layout and data plumbing at the same time is
      where the hours disappear.
- [ ] Handle the all-zeros case so an empty venue doesn't render a broken axis.

**10c — top stalls (3 h)**
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
row is pulled out where step 13 can test it in isolation (and where step 11's
real getter can feed it unchanged).

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

# STEP 11 — `AdminDashboardViewModel` (5 h) — ⚠ most logic in your role

`view_model/admin_dashboard_vm.dart`. Pure aggregation over two streams. Every
getter below is a plain function of already-loaded lists, which means **you can
unit-test all of them with no Firestore at all** — construct `FoodOrder`
objects directly. This is your best source of testing marks; step 13 depends on
writing this cleanly.

> **This replaces your step 10 stub.** You already know every getter's exact
> name and return type, because the chart code in `admin_dashboard_page.dart`
> is already consuming them. All you are doing here is computing the real value
> instead of returning a hardcoded one — which is a much more contained problem
> than designing the API and the aggregation at the same time. The page should
> need zero edits. Delete the stub in this commit.

- [ ] `enum DateRange { today, week, month }` declared at the top of the file.
- [ ] Constructor opens **two** subscriptions — all orders (straight off
      `firestore.collection(ordersCollection).snapshots()`, since there's no
      admin order repository) and `watchAllStalls()`. Two separate
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../repository/admin_stall_repository.dart';

enum DateRange { today, week, month }

/// Aggregates orders and stalls into the admin KPI tiles, peak-hours chart,
/// and top-stalls list, filtered by [DateRange].
class AdminDashboardViewModel extends ChangeNotifier {
  final AdminStallRepository _stallRepository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<List<Stall>>? _stallsSub;

  List<FoodOrder> _orders = [];
  List<Stall> _stalls = [];
  bool _loading = true;
  DateRange _range = DateRange.today;

  AdminDashboardViewModel({
    FirebaseFirestore? db,
    AdminStallRepository? stallRepository,
  }) : _stallRepository = stallRepository ?? AdminStallRepository(db: db) {
    final firestore = db ?? FirebaseFirestore.instance;
    _ordersSub =
        firestore.collection(AppConstants.ordersCollection).snapshots().listen(
      (snap) {
        _orders = snap.docs.map((d) => FoodOrder.fromJson(d.data())).toList();
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

# STEP 12 — `VenueConfigRepository` + `admin_settings_page.dart` (5 h)

⚠ **Read `foundation_and_integration.md` §6.1 before starting this step.** The
reference repo's version of this screen writes a setting that **nothing ever
reads** — the commission control is decorative. You are building the wired
version, and the wiring itself is step 14 (paired with Mervin).

- [ ] **Create the repository at `lib/core/repository/venue_config_repository.dart`**,
      not under `features/admin/`. All three roles read the venue config now, so
      it belongs in core. You still own the writes.
- [ ] `watchConfig()` → `Stream<VenueConfig?>` off the `config/venue`
      document's `.snapshots()`.
- [ ] `updateCommission(double rate)` — `.set(...)` with
      **`SetOptions(merge: true)`**. Merge is essential: the same document
      holds the pickup-code counter that Mervin's `placeOrder` bumps on every
      order, and a non-merged write would wipe it.
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
import '../utils/constants.dart';
import '../../models/transaction.dart';
import '../../models/venue_config.dart';

/// Reads/writes the singleton `config/venue` document and provides wallet
/// monitoring totals for the admin settings screen.
class VenueConfigRepository {
  final FirebaseFirestore _db;

  VenueConfigRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection(AppConstants.configCollection)
      .doc(AppConstants.venueConfigDoc);

  Stream<VenueConfig?> watchConfig() {
    return _doc.snapshots().map(
          (snap) =>
              snap.data() == null ? null : VenueConfig.fromJson(snap.data()!),
        );
  }

  /// One-shot read, for callers that need the config once rather than as a
  /// stream (e.g. seeding the cart's service fee at checkout).
  Future<VenueConfig?> getConfig() async {
    final snap = await _doc.get();
    final data = snap.data();
    return data == null ? null : VenueConfig.fromJson(data);
  }

  /// [rate] is a FRACTION (0.15 = 15%), not a percentage. The settings page
  /// divides the typed percentage by 100 before calling this.
  ///
  /// `SetOptions(merge: true)` is essential: this same document holds the
  /// pickup-code counter that `OrderRepository.placeOrder` bumps on every
  /// order. A non-merged write would wipe it and restart every pickup code
  /// at A001.
  Future<void> updateCommission(double rate) {
    return _doc.set({
      'defaultCommission': rate,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// Flat per-order service fee in CENTS. Same merge rule as above.
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

### Code for step 13

**A shared `order({...})` factory** is what makes these tests short. Put one at
the top of each file and vary only the field under test:

```dart
FoodOrder order({
  String id = 'o1',
  String stallName = 'Nasi Corner',
  int total = 1000,
  String status = 'collected',
  bool refunded = false,
  bool dismissed = false,
  DateTime? createdAt,
  DateTime? readyAt,
}) {
  final created = createdAt ?? DateTime.now();
  return FoodOrder(
    orderId: id,
    customerUid: 'cust1',
    customerName: 'Alice',
    stallId: 'stall1',
    vendorUid: 'vend1',
    stallName: stallName,
    subtotal: total - 50,
    serviceFee: 50,
    total: total,
    status: status,
    pickupCode: 'A001',
    refunded: refunded,
    dismissed: dismissed,
    createdAt: created,
    updatedAt: created,
    readyAt: readyAt,
  );
}
```

**`test/admin/admin_dashboard_vm_test.dart`** — the view model opens two
Firestore streams in its constructor, so pass a `FakeFirebaseFirestore`
straight in as `db` and seed the docs *before* constructing it:

```dart
late FakeFirebaseFirestore db;

Future<AdminDashboardViewModel> vmWith(List<FoodOrder> orders) async {
  for (final o in orders) {
    await db.collection('orders').doc(o.orderId).set(o.toJson());
  }
  final vm = AdminDashboardViewModel(
    db: db,
    stallRepository: AdminStallRepository(db: db),
  );
  addTearDown(vm.dispose);
  await Future<void>.delayed(Duration.zero);   // let the streams deliver
  return vm;
}
```

⚠️ The `addTearDown(vm.dispose)` and the zero-delay are the same two rules
used everywhere else in this project — a view model that loads via a stream
has not loaded anything yet at the moment its constructor returns.

The cancelled-exclusion case is the one that protects real money figures:

```dart
test('cancelled orders are excluded from every KPI', () async {
  final vm = await vmWith([
    order(id: 'a', total: 1000),
    order(id: 'b', total: 2000, status: 'cancelled'),
  ]);

  expect(vm.totalOrders, 1);
  expect(vm.revenue, 1000, reason: 'a cancelled order was refunded, so it is '
      'not revenue — counting it inflates every report the admin exports');
  expect(vm.ordersByHour.fold<int>(0, (a, b) => a + b), 1);
  expect(vm.topStalls.length, 1);
});
```

The remaining cases, each a few lines:

```dart
test('ordersByHour buckets by hour and always returns 24 entries', () async {
  final today = DateTime.now();
  final vm = await vmWith([
    order(id: 'a', createdAt: DateTime(today.year, today.month, today.day, 9)),
    order(id: 'b', createdAt: DateTime(today.year, today.month, today.day, 9)),
    order(id: 'c', createdAt: DateTime(today.year, today.month, today.day, 14)),
  ]);

  expect(vm.ordersByHour.length, 24);
  expect(vm.ordersByHour[9], 2);
  expect(vm.ordersByHour[14], 1);
  expect(vm.ordersByHour[0], 0);
});

test('topStalls sorts descending and caps at 5', () async {
  final vm = await vmWith([
    for (var i = 0; i < 6; i++)
      for (var n = 0; n <= i; n++)
        order(id: 's$i-$n', stallName: 'Stall $i'),
  ]);

  expect(vm.topStalls.length, 5, reason: 'the chart has room for five bars');
  expect(vm.topStalls.first, ('Stall 5', 6));
  expect(vm.topStalls.map((e) => e.$2).toList(), [6, 5, 4, 3, 2]);
});

test('avgPrepMinutes ignores orders that never reached ready', () async {
  final base = DateTime.now().subtract(const Duration(minutes: 30));
  final vm = await vmWith([
    order(id: 'a', createdAt: base, readyAt: base.add(const Duration(minutes: 10))),
    order(id: 'b', createdAt: base, readyAt: base.add(const Duration(minutes: 20))),
    order(id: 'c', createdAt: base),                     // still preparing
  ]);

  expect(vm.avgPrepMinutes, 15);
});
```

⚠️ **Keep the backdate small.** `DateRange.today` starts at midnight, so any
order you backdate by hours will silently fall out of range when the suite
runs shortly after midnight and the test fails for a reason that has nothing
to do with the code. Anything that needs a genuinely older order should
`setRange(DateRange.month)` first rather than backdating further.

```dart

test('avgPrepMinutes returns 0 rather than dividing by zero', () async {
  final vm = await vmWith([order(id: 'a')]);
  expect(vm.avgPrepMinutes, 0);
});

test('setRange changes which orders are counted', () async {
  final vm = await vmWith([
    order(id: 'today', createdAt: DateTime.now()),
    order(id: 'old', createdAt: DateTime.now().subtract(const Duration(days: 10))),
  ]);

  expect(vm.totalOrders, 1);          // DateRange.today by default
  vm.setRange(DateRange.month);
  expect(vm.totalOrders, 2);
});
```

**`test/admin/vendor_management_vm_test.dart`** — the assertion that matters is
the *neither* case, because `rejected` is the one status that belongs in no
bucket at all:

```dart
test('rejected stalls appear in neither bucket', () async {
  final vm = await vmWith([
    stall(id: 'a', status: 'pending'),
    stall(id: 'b', status: 'open'),
    stall(id: 'c', status: 'suspended'),
    stall(id: 'd', status: 'rejected'),
  ]);

  expect(vm.pending.map((s) => s.stallId), ['a']);
  expect(vm.managed.map((s) => s.stallId), ['b', 'c']);
  expect(
    [...vm.pending, ...vm.managed].map((s) => s.stallId),
    isNot(contains('d')),
    reason: 'a rejected stall is finished business — it must not reappear in '
        'the approval queue',
  );
});
```

**`test/admin/disputes_vm_test.dart`** — all four flag combinations, since
"open" is defined by two booleans being false together:

```dart
test('open vs resolved across every flag combination', () async {
  final vm = await vmWith([
    order(id: 'open', status: 'cancelled'),
    order(id: 'refunded', status: 'cancelled', refunded: true),
    order(id: 'dismissed', status: 'cancelled', dismissed: true),
    order(id: 'both', status: 'cancelled', refunded: true, dismissed: true),
  ]);

  expect(vm.open.map((o) => o.orderId), ['open']);
  expect(vm.resolved.map((o) => o.orderId),
      containsAll(['refunded', 'dismissed', 'both']));
});
```

**`test/admin/dispute_repository_test.dart`** — real `FakeFirebaseFirestore`,
because this one moves money:

```dart
test('refund credits the exact total and writes one ledger row', () async {
  await db.collection('users').doc('cust1').set({'walletBalance': 2000});
  final o = order(status: 'cancelled', total: 1000);
  await db.collection('orders').doc(o.orderId).set(o.toJson());

  await repo.refund(o);

  final user = await db.collection('users').doc('cust1').get();
  expect(user.data()!['walletBalance'], 2000 + 1000);

  final stored = await db.collection('orders').doc(o.orderId).get();
  expect(stored.data()!['refunded'], true);

  final ledger = await db.collection('transactions').get();
  expect(ledger.docs, hasLength(1));
  expect(ledger.docs.first.data()['balanceBefore'], 2000);
  expect(ledger.docs.first.data()['balanceAfter'], 3000);
  expect(ledger.docs.first.data()['amount'], 1000);
});

test('refunding twice credits only once', () async {
  await db.collection('users').doc('cust1').set({'walletBalance': 2000});
  final o = order(status: 'cancelled', total: 1000);
  await db.collection('orders').doc(o.orderId).set(o.toJson());

  await repo.refund(o);
  await repo.refund(o.copyWith(refunded: true));

  final user = await db.collection('users').doc('cust1').get();
  expect(user.data()!['walletBalance'], 3000);
  expect((await db.collection('transactions').get()).docs, hasLength(1));
});
```

⚠️ The second test is guarding `if (order.refunded) return;` at the top of
`refund`. Without it a double-tap on the refund button — or an admin returning
to a stale disputes list — pays the customer twice from money the platform
never took. Pass `o.copyWith(refunded: true)` to simulate the caller holding
the *updated* order, which is what the stream would deliver.

**Widget tests.** Both admin pages read their view model from a provider, so
inject a fake and hand ownership of disposal to the test:

```dart
class FakeDisputesViewModel extends ChangeNotifier implements DisputesViewModel {
  FakeDisputesViewModel(this._open);
  final List<FoodOrder> _open;

  @override
  List<FoodOrder> get open => _open;
  @override
  List<FoodOrder> get resolved => const [];
  @override
  bool get isLoading => false;
  @override
  bool get isBusy => false;

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> pumpDisputes(WidgetTester tester, List<FoodOrder> open) {
  final vm = FakeDisputesViewModel(open);
  addTearDown(vm.dispose);
  return tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<DisputesViewModel>.value(
        value: vm,
        child: const DisputesPage(),
      ),
    ),
  );
}
```

`implements` plus a `noSuchMethod` fallback means you only override the four
getters the widget actually reads, instead of stubbing the whole class. Then:
`pumpDisputes(tester, [])` finds `EmptyState`; `pumpDisputes(tester, [order(),
order(id: 'o2')])` finds two cards. For the dashboard, assert on
`find.text('RM 10.00')` and that `find.text('1000')` finds **nothing** — raw
cents must never reach the screen.


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

| Step | Slice | File | Hours |
|---|---|---|---|
| 1 | Vendors | `vendor_management_page.dart` (on a stub VM) | 6 |
| 2 | Vendors | `admin_stall_repository.dart` | 2 |
| 3 | Vendors | `vendor_management_vm.dart` (replaces stub) | 2 |
| 4 | Announce | `announcements_page.dart` (on a stub VM) | 5 |
| 5 | Announce | `announcement_repository.dart` | 2 |
| 6 | Announce | `announcements_vm.dart` (replaces stub) | 1.5 |
| 7 | Disputes | ⚠ `dispute_repository.dart` (transaction) — **logic first** | 4 |
| 8 | Disputes | `disputes_vm.dart` | 1.5 |
| 9 | Disputes | `disputes_page.dart` | 6 |
| 10 | Dashboard | ⚠ `admin_dashboard_page.dart` (charts, on a stub VM) | **12** |
| 11 | Dashboard | ⚠ `admin_dashboard_vm.dart` (replaces stub) | 5 |
| 12 | Config | venue config + settings page | 5 |
| 13 | — | tests | 5 |
| 15 | — | report assets | 4 |
| | | **Subtotal** | **~50 h** |
| 14 | — | commission fix (paired w/ Mervin) | +5 |

Note slices 1, 2 and 4 run **UI → repository → real ViewModel**; the disputes
slice (7–9) is the one that runs the other way round, because it moves money.

**Hardest file: `admin_dashboard_page.dart` (12 h)** — not because the logic is
hard (step 11 does that thinking, after this) but because `fl_chart` has a
fiddly API. You build the chart against your stub VM's fake series, which is
exactly why the stub is worth the fifteen minutes.

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
