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

# STEP 2 — `VendorManagementViewModel` (2 h)

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

# STEP 3 — `vendor_management_page.dart` (6 h)

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

# STEP 4 — `AnnouncementRepository` (2 h)

- [ ] `watchAnnouncements()` — `announcements` ordered by `createdAt`
      descending, `.limit(50)`. The limit matters: without it the query grows
      unbounded over the venue's lifetime.
- [ ] `create({title, message, createdBy})` — generate the doc id first, build
      an `Announcement` with `createdAt: DateTime.now()`, then `set`.
      `createdBy` is the admin's uid, which Mervin's `NotificationCoordinator`
      uses to avoid notifying the author about their own announcement.
- [ ] `delete(announcementId)`

# STEP 5 — `AnnouncementsViewModel` (1.5 h)

- [ ] Exposes `Stream<List<Announcement>> get announcements` directly from the
      repository (a `StreamBuilder` in the view consumes it) — note this VM
      does **not** hold a subscription, unlike your others. Simpler is fine
      here because there's no derived state; be able to say why the two
      patterns differ.
- [ ] `publish({title, message, createdBy})` with `_sending` and `_error`
      state; trims the inputs; returns `bool`. Catch the exception and set a
      friendly message rather than letting it reach the UI.
- [ ] `delete(id)`.

# STEP 6 — `announcements_page.dart` (5 h)

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

# STEP 8 — `DisputesViewModel` (1.5 h)

- [ ] Subscribes to `watchCancelledOrders()` (`onError` handler as always).
- [ ] `open` → `!o.refunded && !o.dismissed`; `resolved` → `o.refunded || o.dismissed`.
- [ ] `refund(order)` and `dismiss(order)` wrapped in a `_busy` flag set before
      the await and cleared in a `finally` — the UI disables buttons while busy
      so a double-tap can't fire two refunds.
- [ ] `dispose()` cancels.

# STEP 9 — `disputes_page.dart` (6 h)

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

# STEP 14 — ⚠ Commission fix, **paired with Mervin** (5 h)

This is the assignment's known defect #1 and it is jointly assigned. Sit
together for one session. **Read `foundation_and_integration.md` §6.1 in full
first** — it explains both bugs and the exact fix. Summary of who does what:

- **You drive:** the `VenueConfigRepository` move into `core/`, the
  `updateServiceFee` addition, and a new per-stall commission override control
  on `vendor_management_page.dart` (so the nullable `Stall.commissionRate` is
  actually reachable from the UI and demonstrable in the Q&A).
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
