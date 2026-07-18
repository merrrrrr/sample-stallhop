# StallHop — Foundation & Integration (shared reference)

**Module:** CT124-3-2 Mobile App Engineering · **Supervisor:** Mr. Amad Arshad
**Team:** Mervin (Customer + foundation), Yong Jun (Stall Vendor), Justin (Venue Admin)

This document is the shared contract. The three per-member plans
(`mervin_plan.md`, `yongjun_plan.md`, `justin_plan.md`) all assume what is
written here. Read this first.

---

## 0. The rule that shapes everything

Every member must be able to trace and explain their own code in a live Q&A.
The assignment brief treats an inability to explain submitted code as
*plausible academic dishonesty*.

Therefore:

- **Nobody copy-pastes from the reference repo.** You read a reference file,
  close it, and type your own version. If you cannot explain a line, delete it
  and write a line you can explain.
- **Nobody writes code in another member's folder** without that member being
  present and typing it themselves. The two joint tasks in this plan (§6) are
  explicitly pair-worked for this reason.
- Simpler code you understand beats clever code you don't. Deviating from the
  reference is allowed and expected — just record the deviation in your own
  plan's "Deviations" section so it can be explained.

---

## 1. Architecture you are all rebuilding

MVVM + Repository, three layers, no dependency-injection framework.

```
View (Widget)  ──watches──►  ViewModel (ChangeNotifier)  ──calls──►  Repository
                                                                        │
                                              FirestoreService / AuthService / StorageService
                                                                        │
                                                              Cloud Firestore / Auth / Storage
```

Five conventions that make the whole codebase hang together. Learn these before
you write anything:

1. **Constructor injection with a default.** Every repository and view model
   takes its collaborator as an optional named parameter that falls back to a
   real instance:
   ```dart
   OrderRepository({FirebaseFirestore? db})
       : _db = db ?? FirebaseFirestore.instance;
   ```
   This is the *only* reason the unit tests can substitute
   `FakeFirebaseFirestore`. Never call `FirebaseFirestore.instance` directly
   inside a method body — it makes the class untestable and costs you testing
   marks.

2. **`FirestoreService` returns raw maps, not snapshots.** Every document in
   StallHop redundantly stores its own id as a field (`orderId`, `stallId`,
   `uid`, `itemId`, `txnId`, `reviewId`, `announcementId`), so a
   `Map<String, dynamic>` is enough to rebuild a model. You will never need
   `snapshot.id` in a repository.

3. **ViewModels subscribe in the constructor, cancel in `dispose()`.** The
   pattern is identical in all fourteen view models:
   ```dart
   StreamSubscription<List<Thing>>? _sub;

   MyViewModel(...) { _sub = _repo.watchThings().listen(onData, onError: ...); }

   @override
   void dispose() { _sub?.cancel(); super.dispose(); }
   ```
   **Every `.listen()` must have an `onError` handler.** Without it a Firestore
   permission error becomes an unhandled exception and the screen hangs on its
   spinner forever. Set `_loading = false` inside `onError` too.

4. **Money is always integer cents.** `int`, never `double`. `750` means
   RM 7.50. Convert only at the display edge with `centsToRM()`. A `double`
   anywhere in the money path is a bug.

5. **Routing is deliberately primitive.** No named routes, no GoRouter.
   `AuthGate` in `main.dart` switches on `AuthViewModel.status` into
   `getHomeForRole()`; everything else is `Navigator.push(MaterialPageRoute(...))`.
   Do not introduce a routing package — it becomes a merge conflict for all
   three of you.

---

## 2. Firestore data model (authoritative)

Collection paths are all declared as constants in
`lib/core/utils/constants.dart`. Never type a collection name as a string
literal in a repository.

| Path | Model | Owner |
|---|---|---|
| `users/{uid}` | `AppUser` | Mervin |
| `stalls/{stallId}` | `Stall` | Mervin (model), Yong Jun + Justin (writes) |
| `stalls/{stallId}/menuItems/{itemId}` | `MenuItem` | Yong Jun |
| `orders/{orderId}` | `FoodOrder` (embeds `List<OrderItem>`) | Mervin |
| `transactions/{txnId}` | `WalletTransaction` | Mervin |
| `reviews/{reviewId}` | `Review` | Mervin |
| `announcements/{announcementId}` | `Announcement` | Justin |
| `config/venue` (singleton doc) | `VenueConfig` | Justin (writes), all (reads) |

**`OrderItem` is not a collection.** It is embedded as an array inside the order
document. This is intentional — an order's line items must never change after
the order is placed, so they are denormalised.

Enumerated string values (all in `AppConstants`):

- roles: `customer`, `vendor`, `admin`
- order status: `preparing` → `ready` → `collected`, or `cancelled`
- stall status: `pending` → `open` ⇄ `closed`, plus `suspended`, `rejected`
- transaction type: `topup`, `payment`, `refund`, `earning`, `withdrawal`

---

## 3. Build sequence

```
PHASE 0  Mervin alone. Blocks everyone.          ~25 h
         Firebase project, core/, models/, auth/, rules, seed data.
         Ends with: merged to main + a 90-minute teaching session (§5).
              │
              ▼
PHASE 1  All three in parallel, own branches.
         Mervin  → Customer role          ~45 h
         Yong Jun→ Stall Vendor role      ~68 h   ⚠ largest
         Justin  → Venue Admin role       ~50 h
              │
              ▼
PHASE 2  Defect fixes + per-role tests (§6).
              │
              ▼
PHASE 3  Integration, QA, Robo test, report assets (§7).
```

**Yong Jun's role is the largest by a clear margin** (~68 h vs ~50 h) because
`vendor_dashboard_page.dart` (487 lines) and `add_edit_item_page.dart` (449
lines) are the two biggest files in the app and both are his. Per the team
decision he builds his full role as specified; he raises a hand early if he is
falling behind rather than at the deadline. If help is needed, the correct form
of help is **pairing while he types**, never someone else writing the file.

Branch naming: `phase0-foundation`, `phase1-customer`, `phase1-vendor`,
`phase1-admin`. Merge into `main` via PR so there is a reviewable, per-member
commit history — this is also your evidence trail for the Q&A.

---

## 4. Phase 0 deliverables (Mervin) — summary

Full checklist is in `mervin_plan.md`. The contract the other two depend on:

**Core services**
- `core/services/firestore_service.dart` — generic `getDocument`,
  `documentStream`, `setDocument`, `updateDocument`, `deleteDocument`,
  `getCollection`, `collectionStream`, `newDocId`. The `QueryBuilder` typedef
  (`Query<JsonMap> Function(Query<JsonMap>)`) lets callers pass a query shaper.
- `core/services/auth_service.dart` — thin `FirebaseAuth` + Google Sign-In
  wrapper. Holds no app state.
- `core/services/storage_service.dart` — `uploadImage(File, path) → String url`,
  `deleteImage(url)`. Yong Jun needs this for menu item photos.
- `core/services/notification_service.dart` + `notification_coordinator.dart` —
  local notifications; coordinator watches Firestore per signed-in role.

**Core utils**
- `constants.dart` — all collection paths, roles, statuses, `serviceFeeCents`,
  `defaultCommissionRate`, `topUpPresetsCents`.
- `formatters.dart` — `centsToRM`, `rmToCents`, `formatDate`, `formatTime`,
  `formatDateTime`, `timeAgo`.
- `validators.dart` — `Validators.email/password/confirmPassword/phone/required/price`.
- `app_exceptions.dart` — `AppException`, `InsufficientBalanceException`,
  `NotFoundException`.

**Shared widgets** (`lib/widgets/`) — `LoadingIndicator`, `EmptyState`,
`StallCard`, `WalletBalanceCard`, `OrderStatusStepper`, `PickupCodeDisplay`,
`QrScannerPage`. Yong Jun uses `QrScannerPage`; Justin uses `EmptyState` and
`LoadingIndicator` heavily.

**All nine models** — every one needs `fromJson`, `toJson`, `copyWith`.
`Timestamp` ⇄ `DateTime` conversion happens in the model, nowhere else.

> ⚠️ **Model change vs the reference repo — decided, do not revert.**
> `FoodOrder` gains two fields (`commissionRate`, `vendorEarning`) and
> `Stall.commissionRate` becomes nullable. See §6.1. Mervin builds these into
> the Phase 0 models so nobody has to migrate mid-Phase-1.

**Auth feature** — `AuthRepository`, `AuthViewModel` (the 4-state `AuthStatus`
enum), `LoginPage`, `RegisterPage`, `ChooseRolePage`.

---

## 5. Teaching slice — vendor menu management

Before Yong Jun or Justin touches their own role, Mervin walks both of them
through **one complete vertical slice**, ~90 minutes, screen-shared, with both
teammates typing it themselves in a scratch branch they later delete.

The slice is the vendor menu list: `MenuRepository` → `MenuManagementViewModel`
→ `MenuManagementPage`. It is chosen because it is the smallest feature in the
app that still contains every pattern they will need (subcollection path, live
stream, list rendering, an optimistic toggle, and a delete with confirmation),
and it contains no money logic to distract from the structure.

**Run it in this order and do not skip the questions.**

1. **The model** (5 min). Open `models/menu_item.dart`. Point out: `price` is
   `int` cents; `customizations` and `addOns` are `List<Map<String,dynamic>>`
   not typed classes (a deliberate simplification); `_mapList` exists because
   Firestore hands back `List<dynamic>`.
   *Ask:* "why does `fromJson` use `json['available'] ?? true` instead of
   `json['available']`?" (Answer: older documents may not have the field;
   defaulting keeps the app from crashing on a missing key.)

2. **The repository** (25 min). Both type `menu_repository.dart` from scratch.
   - The path helper: `stalls/{stallId}/menuItems` built from
     `AppConstants.stallsCollection` and `AppConstants.menuItemsSubcollection`.
   - `watchMenuItems(stallId)` → `Stream<List<MenuItem>>` via
     `_firestore.collectionStream(...).map((rows) => rows.map(MenuItem.fromJson).toList())`.
   - `addItem(...)`: `_col(stallId).doc()` **generates the id before writing**,
     so the id can be stored inside the document. Show why this matters
     (convention #2 in §1).
   - `setAvailable`, `deleteItem`, `updateItem`.
   *Ask:* "why does `addItem` create the ref first and then `set`, instead of
   calling `add()`?"

3. **The view model** (20 min). Both type `menu_management_vm.dart`.
   - Constructor takes `stallId` and subscribes.
   - `_items`, `_loading` private; exposed via getters.
   - `notifyListeners()` after each stream event.
   - **`onError` handler** — deliberately break it: comment out `onError`,
     point Firestore at a path the rules deny, watch the screen hang forever on
     the spinner. Restore it. This is the single most common bug they will hit
     in Phase 1.
   - `dispose()` cancels.
   *Ask:* "what happens if we forget `_sub?.cancel()` in dispose?"

4. **The view** (30 min). Both type `menu_management_page.dart`.
   - `ChangeNotifierProvider` creating the VM, `Consumer`/`context.watch`
     reading it.
   - Three render states: loading → `LoadingIndicator`; empty → `EmptyState`;
     data → `ListView.builder`.
   - A `Switch` per row calling `vm.toggleAvailable(item)` — no local
     `setState`, the stream round-trips and re-renders.
   - Dismiss/delete with an `AlertDialog` confirmation.
   *Ask:* "the switch doesn't set any local state — why does the UI still
   update when you tap it?" (Answer: the write goes to Firestore, the snapshot
   stream fires, the VM notifies, the widget rebuilds. One source of truth.)

5. **Wrap-up** (10 min). Draw the loop on paper:
   `tap → VM method → repository → Firestore → snapshot stream → VM
   notifyListeners → widget rebuild`. Both must be able to redraw this from
   memory. If they can, they can build their whole role.

**Exit check before Phase 1 starts:** each teammate independently adds one new
method (`MenuRepository.setCategory`) and wires a UI control for it, without
help. Then they delete the scratch branch and start their real role.

---

## 6. Phase 2 — known defects

### 6.1 Commission rate is not wired into pricing — **Justin + Mervin, joint**

**Estimated effort: 5 h paired.** Do this together, in one sitting, with
Mervin driving the repository and Justin driving the admin side.

**What is actually broken.** There are two independent bugs and they currently
mask each other, which is why the app looks correct today.

*Bug A — the admin's setting goes nowhere.*
`admin_settings_page.dart:59` calls `VenueConfigRepository.updateCommission(rate)`,
which writes `defaultCommission` into `config/venue`. **No code ever reads that
field.** Pricing in `OrderRepository.placeOrder` uses `stall.commissionRate`
instead, and `VendorOrderRepository.createStall` seeds every new stall from the
hardcoded constant `AppConstants.defaultCommissionRate`. The admin's control is
decorative.

*Bug B — refunds reverse at the wrong rate.*
`order_repository.dart:205`:
```dart
double _commissionFor(FoodOrder order) {
  if (order.subtotal == 0) return 0;
  return AppConstants.defaultCommissionRate;   // always 0.10
}
```
Its own doc comment claims the rate is derived from total/subtotal. It is not —
it returns a hardcoded 0.10 regardless. So `placeOrder` credits the vendor at
`stall.commissionRate` but `cancelAndRefund` claws back at 0.10. **For any
stall not on exactly 10%, money is destroyed or created on every refund and the
vendor's wallet drifts permanently.**

Today `Stall.commissionRate` defaults to `0.10` and `createStall` also writes
`0.10`, so the two paths coincidentally agree and nothing looks wrong.
**Fixing Bug A alone activates Bug B.** They must be fixed in the same change.

*Bug C, same class, fix it while you're here.* `VenueConfig.serviceFee` is
equally orphaned — `CartViewModel.getServiceFee()` returns the hardcoded
`AppConstants.serviceFeeCents`.

**The fix.**

- [ ] **Move `VenueConfigRepository` out of `features/admin/repository/` into
      `lib/core/repository/venue_config_repository.dart`.** All three roles now
      read it, so it is no longer admin-owned. Justin keeps ownership of the
      *writes* (`updateCommission`, and a new `updateServiceFee`).
- [ ] **`Stall.commissionRate` becomes `double?`.** `null` means "inherit the
      venue default". `VendorOrderRepository.createStall` writes `null`, not a
      hardcoded rate. A non-null value is a per-stall negotiated override that
      only an admin can set. *This is what makes the admin's venue-wide setting
      actually govern pricing* — with a non-null default on every stall, the
      venue default could never apply to anything.
- [ ] **`FoodOrder` gains two fields:**
      - `final double commissionRate;` — the rate applied, captured at place
        time, for display and audit.
      - `final int vendorEarning;` — the exact cents credited to the vendor.
      Add both to `fromJson` (defaulting for safety:
      `(json['commissionRate'] ?? 0.10).toDouble()`,
      `(json['vendorEarning'] ?? 0) as int`), `toJson`, and the constructor.
      Storing the *amount* as well as the rate removes any chance of the
      reversal rounding differently from the original credit.
- [ ] **`placeOrder` resolves the rate inside the transaction.** It already
      reads `_venueRef` for the pickup code, so this costs **no extra read** —
      Firestore's read-before-write rule is already satisfied:
      ```dart
      final venueRate =
          (venueSnap.data()?['defaultCommission'] ?? AppConstants.defaultCommissionRate)
              .toDouble();
      final rate = stall.commissionRate ?? venueRate;
      final vendorEarning = (subtotal * (1 - rate)).round();
      ```
      Store `rate` and `vendorEarning` on the order being written.
- [ ] **`cancelAndRefund` uses the stored amount.**
      Replace `(order.subtotal * (1 - _commissionFor(order))).round()` with
      plain `order.vendorEarning`, and **delete `_commissionFor()` entirely.**
      The reversal is now guaranteed to equal the original credit, and an
      order refunded next month reverses at the rate it was placed at, not
      today's rate.
- [ ] **Service fee, same treatment.** Read `serviceFee` from `config/venue`
      in `placeOrder` and use it as the authoritative value. `CartViewModel`
      displays the venue value (streamed from the same doc via a
      `VenueConfig` provider added in `main.dart`) so the cart total the
      customer sees matches what is charged.
- [ ] **`VendorDashboardViewModel.todayEarnings`** currently recomputes
      `(subtotal * (1 - rate))` from the stall. Change it to sum
      `o.vendorEarning` — it is now stored per order and is the truthful
      figure. *(Yong Jun makes this one-line change in his own file; flag it
      to him.)*
- [ ] **Update the existing test.** `test/repositories/order_repository_test.dart`
      hardcodes `expect(vend.data()!['walletBalance'], 630)` — the 10% result.
      It will still pass with a null stall rate and a 0.10 venue default, but
      add two new cases: one where the venue default is 0.15 and the stall rate
      is null (vendor gets 85%), and one where the stall has an explicit 0.05
      override (vendor gets 95% and the venue default is ignored).
- [ ] **Regression test for Bug B specifically:** place an order at a non-0.10
      rate, cancel it, assert both wallets return to their exact starting
      balances. This is the test that would have caught the original bug.
- [ ] Justin adds a per-stall commission override control to
      `vendor_management_page.dart` so the nullable field is actually
      reachable from the UI (and demonstrable in the Q&A).

**Verification (do this on-device, not just in tests):** admin sets venue
commission to 20% → vendor with no override places nothing, customer orders
RM 10.00 from that stall → vendor wallet gains RM 8.00, order document shows
`commissionRate: 0.2`, `vendorEarning: 800`. Cancel it → vendor returns to
exactly the prior balance, customer is made whole.

### 6.2 iOS permission strings missing — **Yong Jun**

> **Platform reality.** The team has no Mac or iPhone, so iOS cannot be built
> or tested routinely — day-to-day development and all report evidence are
> **Android**. The iOS project is nonetheless kept correct and buildable,
> because a friend's Mac may be available for a one-off verification session.
> Treat iOS as *supported but rarely exercised*, not as abandoned.

**Estimated effort: 30 min** (10 min to fix, the rest to verify **if and when**
a Mac/iPhone becomes available). Confirmed against `ios/Runner/Info.plist`: the
file declares neither `NSCameraUsageDescription` nor
`NSPhotoLibraryUsageDescription`. On iOS, requesting camera or photo-library
access without a usage-description string is an **immediate hard crash**, not a
denied permission. Both affected features are Yong Jun's:
`lib/widgets/qr_scanner_widget.dart` (`MobileScanner`) and
`lib/features/vendor/view/add_edit_item_page.dart:89` (`ImagePicker`).

- [ ] Add to `ios/Runner/Info.plist`, inside the top-level `<dict>`:
      ```xml
      <key>NSCameraUsageDescription</key>
      <string>StallHop uses the camera to scan customer pickup QR codes and to photograph your menu items.</string>
      <key>NSPhotoLibraryUsageDescription</key>
      <string>StallHop needs photo library access so you can choose an existing photo for a menu item.</string>
      ```
      Write a real, specific reason — Apple rejects generic strings, and a
      vague one is also a weak answer in the Q&A. The edit itself needs no
      Apple hardware; it is plain XML.
- [ ] **Verify both camera features on Android first** — that testing is real,
      available today, and part of §7.2.
- [ ] **Opportunistic iOS verification.** *If* you get access to a Mac and an
      iPhone, this is a 20-minute session and it is worth booking deliberately
      rather than hoping it happens: `flutter build ios`, run on the device,
      open the QR scanner, then add-item → pick image → camera and gallery.
      Screenshot the result. Do this **before** the report deadline, not after —
      a verified fix is worth more than a plausible one.
- [ ] **Report the actual state, whichever it is.** If verified: say so and
      show the evidence. If not: *"the missing usage-description strings were
      identified and corrected by inspection; the fix could not be validated at
      runtime within the project window as the team has no macOS/iOS hardware.
      Android is the target platform for all testing and evidence."* An honest
      unverified fix earns marks; a claimed test you couldn't have run loses
      them the moment an examiner asks how you ran it.
- [ ] Android needs nothing: `mobile_scanner` and `image_picker` merge their own
      permissions into the manifest at build time, and `AndroidManifest.xml`
      correctly declares only `POST_NOTIFICATIONS`. Be ready to explain that
      platform difference — you can answer it fully either way.

### 6.3 Test coverage — **each member tests their own role only**

Testing marks are awarded per person. Nobody writes anyone else's tests.

Audit of the reference repo's `test/` and `integration_test/`:

| Area | Existing coverage | Owner |
|---|---|---|
| models (all 9) | `models_test.dart`, round-trip — **good** | Mervin |
| `formatters`, `validators` | 2 files — **good** | Mervin |
| `CartViewModel` | `cart_vm_test.dart` — **good** | Mervin |
| `WalletViewModel` / `WalletRepository` | `wallet_vm_test.dart` — **good** | Mervin |
| `OrderRepository` | `order_repository_test.dart` — **partial**, no commission cases | Mervin |
| `NotificationCoordinator` | `notification_coordinator_test.dart` — **good** | Mervin |
| 3 shared widgets | stepper, stall card, wallet card — **thin but present** | Mervin |
| **all vendor code** | **ZERO** | **Yong Jun** |
| **all admin code** | **ZERO** | **Justin** |

The gap maps exactly onto the role split, which makes the assignment clean.

Minimum per member — **4 unit + 2 widget tests each**, all inside your own
role's folders:

- **Mervin:** keep the existing suite green through the model change, plus the
  two new commission cases and the refund-symmetry regression test (§6.1).
- **Yong Jun:** `MenuRepository` CRUD against `FakeFirebaseFirestore`;
  `MenuManagementViewModel` stream→state; `OrderQueueViewModel`
  preparing/ready bucketing and sort order; `VendorDashboardViewModel`
  `todayOrderCount` / `todayEarnings` (including that cancelled orders are
  excluded). Widget: menu list renders empty state vs populated list; order
  queue card shows the pickup code.
- **Justin:** `AdminDashboardViewModel` is the richest target in the app and
  needs no Firestore mocking for the getters — test `revenue`, `ordersByHour`
  bucketing, `topStalls` ordering and the 5-item cap, `avgPrepMinutes` with
  and without `readyAt`, and `setRange` filtering. Also
  `VendorManagementViewModel` pending/managed bucketing and
  `DisputesViewModel` open vs resolved. Widget: dashboard KPI tiles render
  formatted currency; disputes page shows the empty state.

Two pre-existing test defects to clean up (Mervin, they're in his files):
- `test/models/models_test.dart:160` — the comment says "a fresh order defaults
  both flags to false" but the assertion is `isTrue`. The comment is wrong;
  make them agree.
- `order_repository_test.dart` — the `630` literal should be derived from a
  named constant so the intent is legible.

---

## 7. Phase 3 — integration & QA

### 7.1 Merge order (conflict-prone files first)

Merge **one branch at a time**, run `flutter analyze` and the full test suite
after each, and do not start the next merge until `main` is green.

```
1. phase0-foundation   → main    (already merged before Phase 1 began)
2. phase1-customer     → main    Mervin first: he owns the models and main.dart,
                                 so his branch defines the shape the other two
                                 rebase onto.
3. phase1-vendor       → main    Yong Jun rebases on the new main, resolves,
                                 re-runs his tests.
4. phase1-admin        → main    Justin rebases last.
5. phase2 fixes        → main    Commission fix touches all three; do it on a
                                 shared short-lived branch with both authors.
```

Files that **will** conflict — agree on them before merging, don't discover
them during:

| File | Why | Resolution |
|---|---|---|
| `lib/main.dart` | all three add providers | Mervin owns it. Others send him their provider line; nobody else edits it. |
| `lib/core/routing/app_router.dart` | each adds a role home | 3-line file, trivial merge, Mervin arbitrates. |
| `lib/models/order.dart` | commission fields | Frozen after Phase 0. Any change requires all three present. |
| `lib/models/stall.dart` | nullable commission | Same. Frozen. |
| `lib/core/utils/constants.dart` | everyone adds constants | **Append only, never reorder.** Reordering turns a 1-line diff into a whole-file conflict. |
| `pubspec.yaml` | dependency additions | Append to the existing groups; keep the comment headers. |
| `lib/core/repository/venue_config_repository.dart` | moved in §6.1 | Move it during the Phase 2 pairing session, not before. |

### 7.2 Manual QA pass

One pass per role, run by the *other two* members, not the owner — you find
more when you didn't write it. Budget 45 min per role. Record pass/fail in a
shared sheet; every failure becomes a ticket assigned to the owner.

**Customer (test with `customer@stallhop.test`)**
- [ ] Register a new account → lands on customer home
- [ ] Browse stalls; search by name; filter by cuisine; each sort order
- [ ] Closed stalls sort below open ones and cannot be ordered from
- [ ] Open an item with customizations + add-ons → price updates live
- [ ] Add to cart from two different stalls → two separate stall groups
- [ ] Cart: increment, decrement to zero removes the line, clear stall
- [ ] Checkout with **insufficient balance** → clean error, no order written,
      no wallet change *(check Firestore console, not just the UI)*
- [ ] Top up → balance and ledger both update
- [ ] Checkout with sufficient balance → order placed, pickup code shown,
      wallet debited by exactly subtotal + service fee
- [ ] Order tracking updates live when the vendor marks ready (two devices)
- [ ] Review a collected order → stall average rating recomputes
- [ ] Cannot review the same order twice

**Vendor (`vendor@stallhop.test`)**
- [ ] Create stall → status `pending`, not visible to customers
- [ ] After admin approval → appears in customer browse
- [ ] Toggle open/closed; change prep time
- [ ] Add menu item with image (camera **and** gallery), customizations, add-ons
- [ ] Edit item, toggle availability, delete item
- [ ] New order arrives in queue live + local notification fires
- [ ] Mark ready → customer's tracking screen updates
- [ ] QR scan a customer pickup code → verifies and marks collected
- [ ] Scan a *wrong* code → rejected with a clear message
- [ ] Cancel an order → customer refunded in full, vendor earning clawed back
      to the exact prior balance
- [ ] Earnings list and withdrawal
- [ ] Camera and photo library both open without crashing **on Android**
- [ ] *(Opportunistic, only if a Mac + iPhone is borrowed)* same check on iOS —
      this is the §6.2 `Info.plist` fix; a crash here means the keys are wrong

**Admin (`admin@stallhop.test`)**
- [ ] Dashboard KPIs across all three date ranges
- [ ] Peak-hours chart and top-stalls list match the underlying orders
- [ ] Approve / reject a pending stall; suspend and reactivate an active one
- [ ] Suspended stall disappears from customer browse
- [ ] Publish an announcement → other signed-in devices notify
- [ ] Delete an announcement
- [ ] Disputes: open list shows cancelled-and-unresolved orders only
- [ ] Refund a dispute → customer credited, order marked refunded, leaves open list
- [ ] Dismiss a dispute → leaves open list without a refund
- [ ] Change commission rate → **next order prices at the new rate** (§6.1)

**Cross-role, two devices side by side** — this is the demo you will be asked
to reproduce live:
- [ ] Customer orders → vendor sees it → marks ready → customer notified →
      vendor scans QR → collected → customer reviews → admin dashboard
      reflects the order.

### 7.3 Firebase Test Lab — Robo test (Mervin)

Spark (free) plan: **10 virtual + 5 physical device runs per day, 15 total.**
Plan for 3–4 runs so there is headroom to retry.

- [ ] `flutter build apk --release`
- [ ] Firebase Console → Test Lab → Robo test → upload
      `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Device matrix: 2 virtual (a recent and an older Android API level) +
      1 physical if a free slot allows. Set crawl timeout to 5 minutes.
- [ ] Provide test-account credentials in the Robo config (Advanced options →
      sign-in) so the crawler can get past the login gate. Run **once per
      role** with that role's credentials — Customer, Vendor, Admin — if the
      crawler successfully authenticates. If it cannot sign in, fall back to a
      **single overall pass** and say so explicitly in the report rather than
      implying per-role coverage you didn't get.
- [ ] Capture, per run: crash/no-crash status, device + API level, screen
      coverage, and the Robo crawl graph screenshot. Save to
      `screenshots/testlab/`.

**Two honest caveats that must appear in the report — do not gloss these:**

1. **Robo covers Android only.** Firebase Test Lab drives iOS via XCUITest,
   not Robo, so **the iOS `Info.plist` crash risk in §6.2 is not covered by
   this pass** — and because the team has no Mac or iPhone, it is covered by
   the opportunistic manual session in §6.2 or not at all. State plainly which
   of those happened. Claiming Robo coverage for iOS would be inaccurate, and
   so would implying a manual iOS pass that never took place.
2. **Robo's crawler is weak on Flutter apps.** Flutter renders to a single
   canvas rather than native view hierarchy, so the crawler often sees one
   large view and cannot enumerate individual buttons. Expect low screen
   coverage numbers. The genuine value here is **crash detection and startup
   stability across device/API combinations**, not exhaustive UI traversal.
   Report the coverage figure alongside that explanation rather than
   presenting a low number as a failure or a high one as thorough.

### 7.4 Report assets — who owns what

**~34 UI screenshots, split by whose screens they are:**

| Member | Screens | Approx count |
|---|---|---|
| Mervin | splash, login, register, choose role, customer home, stall browse, stall menu, item detail, cart, order placed, order tracking, orders list, review, wallet, customer profile | ~15 |
| Yong Jun | vendor dashboard, create stall, menu management, add/edit item, image picker, order queue, order detail, QR scanner, earnings | ~9 |
| Justin | admin dashboard (×3 date ranges), vendor management, stall approval, disputes list, dispute detail, announcements, create announcement, admin settings | ~10 |

Capture on a **single consistent Android device or emulator** (Pixel 6 class,
1080×2400), light theme, with seeded data so no screen looks empty. Agree the
exact device between the three of you before anyone starts capturing —
mismatched screenshot dimensions across members look careless in the report.
Name them `NN_role_screenname.png`.

**Written sections:**

| Section | Owner |
|---|---|
| Wireframes — customer flow | Mervin |
| Wireframes — vendor flow | Yong Jun |
| Wireframes — admin flow | Justin |
| User manual — customer | Mervin |
| User manual — vendor | Yong Jun |
| User manual — admin | Justin |
| Architecture / MVVM + Repository writeup | Mervin |
| Firestore schema + security rules writeup | Mervin |
| §4.2 Test Lab / Robo results + screenshots | **Mervin** (owns final integration) |
| Unit + widget test evidence, own role | each member, own role |
| Known limitations (client-side wallet, no FCM, Robo/Flutter caveat) | Mervin |

---

## 8. Known limitations to declare in the report

Declaring these earns more marks than hiding them, and they are all realistic
Q&A questions.

1. **Wallet mutations are client-side.** With no Cloud Functions on the Spark
   plan, the app writes `walletBalance` directly from the client inside
   Firestore transactions. Security rules can constrain *who* writes, but
   cannot verify that a credit corresponds to a real order. Production would
   move `placeOrder`, `cancelAndRefund`, and `topUp` behind a callable Cloud
   Function using the Admin SDK. **Say this before you are asked.**
2. **Notifications are local, not push.** `NotificationCoordinator` replaces
   the planned `onOrderCreated` / `onOrderStatusChange` /
   `onAnnouncementCreated` functions with client-side Firestore listeners.
   Consequence: notifications only arrive while the app process is alive.
3. **Top-ups are simulated.** No payment gateway integration.
4. **Rating aggregation is client-side** inside `ReviewRepository.createReview`'s
   transaction, replacing an `onReviewCreated` function.
5. **Android is the tested platform; iOS is supported but unverified.** The
   project is configured for both (Firebase options, `GoogleService-Info.plist`,
   Podfile, `Info.plist` usage strings), but the team has no macOS or iOS
   hardware and building for iOS requires Xcode on macOS. All development,
   testing, screenshots and Test Lab evidence are Android. Declare this as a
   resource constraint and a stated scope boundary — examiners treat a declared
   boundary very differently from a silent gap. If the opportunistic iOS
   session in §6.2 does happen, upgrade this wording to match reality.
6. **Robo testing is Android-only and shallow on Flutter** (§7.3).
7. `customizations` and `addOns` are untyped `List<Map<String, dynamic>>`
   rather than model classes — a deliberate simplification, and a fair thing to
   be asked to justify.
