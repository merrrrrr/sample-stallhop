# Yong Jun — Build Plan (Stall Vendor role)

**Total estimate: ~68 h.** This is the largest of the three roles — the two
biggest files in the whole app are yours. Start early and work strictly top to
bottom; every step only uses things built in earlier steps.

**Before you start:** Phase 0 must be merged and you must have completed
Mervin's teaching session (the menu-management walkthrough). You will
essentially rebuild that slice as your steps 3–5, which is deliberate — it is
the part you have already been walked through.

**The rule:** never copy-paste from the reference repo. Read a file, close it,
type your own. If you can't explain a line in the Q&A, it shouldn't be in your
submission. When stuck for more than ~30 minutes, ask Mervin — but ask him to
**pair with you while you type**, not to write it for you.

---

## What "the vendor role" is

A vendor owns exactly **one stall**. They can:

1. create their stall (it starts `pending` until Justin's admin approves it)
2. open/close it and set a prep time
3. manage its menu — add, edit, photograph, toggle availability, delete
4. work the live order queue — see incoming orders, mark them ready
5. verify pickup by scanning the customer's QR code, then mark collected
6. cancel an order (which refunds the customer)
7. view earnings and withdraw

## Your files

```
lib/features/vendor/
├── repository/
│   ├── menu_repository.dart
│   ├── vendor_order_repository.dart
│   └── earnings_repository.dart
├── view_model/
│   ├── menu_management_vm.dart
│   ├── vendor_dashboard_vm.dart
│   ├── order_queue_vm.dart
│   ├── order_detail_vm.dart
│   └── earnings_vm.dart
└── view/
    ├── vendor_dashboard_page.dart      ⚠ 487 lines — the biggest file in the app
    ├── menu_management_page.dart
    ├── add_edit_item_page.dart         ⚠ 449 lines — the hardest file you own
    ├── order_queue_page.dart
    ├── order_detail_page.dart
    └── vendor_earnings_page.dart
```

## Things Mervin built that you use (don't rebuild these)

| What | Where | What you call |
|---|---|---|
| `MenuItem`, `Stall`, `FoodOrder`, `WalletTransaction` | `lib/models/` | `fromJson` / `toJson` / `copyWith` |
| `FirestoreService` | `core/services/` | `collectionStream`, `getCollection`, `setDocument` |
| `StorageService` | `core/services/` | `uploadImage(file, path)` → URL |
| `OrderRepository` | `features/customer/repository/` | `updateStatus`, `cancelAndRefund`, `watchVendorOrders`, `listenToOrder` |
| `WalletRepository` | `features/customer/repository/` | `watchTransactions`, `withdraw` |
| `QrScannerPage` | `widgets/qr_scanner_widget.dart` | push it, await the scanned string |
| `EmptyState`, `LoadingIndicator` | `widgets/` | every list screen |
| `centsToRM`, `formatDateTime`, `timeAgo` | `core/utils/formatters.dart` | all money and dates |
| `Validators` | `core/utils/validators.dart` | all forms |
| `AppConstants` | `core/utils/constants.dart` | never type a collection name yourself |

**Important:** your order status changes and cancellations **delegate into
Mervin's `OrderRepository`**. You never write wallet balances yourself — all
the money logic stays in one transactional place. Be ready to explain *why*
that is (if refund logic existed in two files, they would drift apart, and one
of them would eventually reverse the wrong amount).

---

# STEP 1 — `MenuRepository` (3 h)

`lib/features/vendor/repository/menu_repository.dart`

**What it does:** all reading and writing of a stall's menu items. Nothing else
in your role touches the menu collection directly.

**Firestore:** subcollection `stalls/{stallId}/menuItems/{itemId}`, built from
`AppConstants.stallsCollection` and `AppConstants.menuItemsSubcollection` —
never as a string literal.

- [ ] Constructor takes optional `FirebaseFirestore? db` and
      `FirestoreService? firestore`, each falling back to a real instance.
      **This is what makes your tests possible in step 13** — don't skip it.
- [ ] `String _path(String stallId)` and
      `CollectionReference _col(String stallId)` private helpers.
- [ ] `Stream<List<MenuItem>> watchMenuItems(String stallId)` —
      `_firestore.collectionStream(_path(stallId)).map((rows) => rows.map(MenuItem.fromJson).toList())`
- [ ] `Future<MenuItem> addItem({required stallId, name, description, price,
      category, imageUrl, customizations, addOns})` — call `_col(stallId).doc()`
      **first** to generate the id, put that id inside the `MenuItem`, then
      `set`. *Why:* every StallHop document stores its own id as a field, so a
      raw data map is enough to rebuild the model. Return the created item.
- [ ] `Future<void> updateItem(MenuItem item)` — `set` the whole document from
      `item.copyWith(updatedAt: DateTime.now())`.
- [ ] `Future<void> setAvailable(stallId, itemId, bool available)` — a targeted
      `update` of just `available` and `updatedAt`. A separate method from
      `updateItem` because the availability toggle fires constantly and
      shouldn't rewrite the whole document.
- [ ] `Future<void> deleteItem(stallId, itemId)`

# STEP 2 — `MenuManagementViewModel` (2 h)

`view_model/menu_management_vm.dart`

**State:** `List<MenuItem> _items` (starts empty), `bool _loading` (starts
`true`). Exposed via `items` and `isLoading` getters — the fields stay private.

- [ ] Constructor takes `String stallId` and optional `MenuRepository?`, then
      immediately subscribes:
      `_sub = _repository.watchMenuItems(stallId).listen(onData, onError: ...)`
- [ ] In `onData`: set `_items`, set `_loading = false`, `notifyListeners()`.
- [ ] **In `onError`: `debugPrint` the error, set `_loading = false`,
      `notifyListeners()`.** Miss this and any Firestore permission problem
      leaves the screen spinning forever with no clue why. This is the single
      most common bug you will hit — Mervin demonstrated it deliberately in the
      teaching session.
- [ ] `toggleAvailable(MenuItem item)` → `_repository.setAvailable(stallId,
      item.itemId, !item.available)`. **No local state change** — the write goes
      to Firestore, the stream fires, the VM notifies, the UI rebuilds.
- [ ] `delete(MenuItem item)`
- [ ] `dispose()` → `_sub?.cancel()` then `super.dispose()`.

# STEP 3 — `menu_management_page.dart` (4 h)

**Renders:** loading spinner → `EmptyState` if no items → grouped list.

- [ ] `ChangeNotifierProvider(create: (_) => MenuManagementViewModel(stallId))`
      wrapping the page body.
- [ ] Three render states in order: `if (vm.isLoading) return LoadingIndicator();`
      → `if (vm.items.isEmpty) return EmptyState(...)` → the list.
- [ ] Group items by `category` — a `Map<String, List<MenuItem>>` built in the
      build method is fine at this scale.
- [ ] Each row: thumbnail (`CachedNetworkImage`, with a placeholder icon when
      `imageUrl` is null), name, `centsToRM(item.price)`, and a `Switch` bound
      to `item.available` calling `vm.toggleAvailable(item)`.
- [ ] Tap a row → push `AddEditItemPage(item: item)` (step 4).
- [ ] Long-press or a menu → delete, behind an `AlertDialog` confirmation.
- [ ] `FloatingActionButton` → `AddEditItemPage()` with no item (add mode).

# STEP 4 — ⚠ `add_edit_item_page.dart` (12 h) — **the hardest file you own**

449 lines. One screen doing four hard things at once: a validated form, image
capture and upload, and two nested dynamic list editors. **Build it in the five
sub-steps below and get each working before starting the next.** Do not try to
write it in one pass.

**4a — the form shell (3 h)**
- [ ] `StatefulWidget` taking an optional `MenuItem? item` — null means add
      mode, non-null means edit mode. One screen, two modes; the app bar title
      and the save button label switch on it.
- [ ] `GlobalKey<FormState>` + `TextEditingController`s for name, description,
      price, category. In edit mode, seed the controllers from the passed item
      in `initState`.
- [ ] Validators: `Validators.required` for name, `Validators.price` for price.
      Price is typed in Ringgit ("7.50") and converted with `rmToCents` at save
      time — **the model stores cents**. Getting this wrong by a factor of 100
      is the classic bug here; test it.
- [ ] `dispose()` every controller.

**4b — image picking and upload (3 h)**
- [ ] `ImagePicker().pickImage(source: ...)` behind a bottom sheet offering
      camera and gallery. Store the result as a `File?` in state.
- [ ] Preview: the picked `File` if there is one, else the existing `imageUrl`
      via `CachedNetworkImage`, else a placeholder.
- [ ] On save, **if** a new file was picked, `StorageService().uploadImage(file,
      'stalls/$stallId/menu/$itemId.jpg')` and use the returned URL. Skip the
      upload when unchanged — don't re-upload the same image on every edit.
- [ ] Show a progress indicator during upload; uploads are slow on real
      connections and a frozen button looks like a crash.
- [ ] Test both camera and gallery **on Android**. ⚠ This is also the feature
      that hard-crashes on iOS without the `Info.plist` fix — that's step 14.

**4c — the customizations editor (3 h)**
- [ ] `customizations` is a `List<Map<String, dynamic>>` where each entry is
      `{"name": "Size", "options": ["Small", "Large"]}` — a single-select group.
- [ ] Held in local `setState` state (not a view model — it is transient form
      state that only matters until save).
- [ ] UI: a list of groups; each group has a name field and a chip-style list of
      options with add and remove; plus an "add group" button.
- [ ] Removing the last option in a group should remove the group.

**4d — the add-ons editor (2 h)**
- [ ] `addOns` entries are `{"name": "Extra egg", "price": 150}` — **price in
      cents**, again entered in Ringgit and converted.
- [ ] Simpler than 4c: a flat list of name + price rows with add and remove.

**4e — save (1 h)**
- [ ] Validate the form, upload the image if needed, then
      `_repository.addItem(...)` in add mode or `_repository.updateItem(
      item.copyWith(...))` in edit mode.
- [ ] `Navigator.pop()` on success; a `SnackBar` on failure. Disable the save
      button while in flight so a double-tap can't create two items.

# STEP 5 — `VendorOrderRepository` (4 h)

`repository/vendor_order_repository.dart`. Two responsibilities: the vendor's
own **stall** document, and the **order queue** (which it delegates).

- [ ] Constructor takes optional `db`, `firestore`, **and `OrderRepository?`**.
- [ ] `Stream<Stall?> watchMyStall(String vendorUid)` — query `stalls` where
      `vendorUid == uid`, `.limit(1)`, map `rows.isEmpty ? null :
      Stall.fromJson(rows.first)`. *A vendor owns at most one stall, which is
      why `limit(1)` and a nullable single result rather than a list.*
- [ ] `Future<Stall?> getMyStall(String vendorUid)` — same query, one-shot.
- [ ] `Future<Stall> createStall({vendorUid, name, cuisine, description,
      prepTimeMinutes})` — generate the id first, `status:
      AppConstants.stallPending`. ⚠ **Write `commissionRate: null`**, not a
      hardcoded rate. `null` means "inherit the venue-wide default that the
      admin controls". *(This differs from the reference repo, which hardcodes
      0.10 here and thereby makes the admin's setting do nothing — see
      `foundation_and_integration.md` §6.1. Know this answer; it's a likely
      Q&A question.)*
- [ ] `updateStall(stallId, Map data)` — spreads the map and always stamps
      `updatedAt`.
- [ ] `setOpen(stallId, bool)` → status `open` or `closed`.
      `setPrepTime(stallId, int)`.
- [ ] **Orders — all delegated to Mervin's `OrderRepository`:**
      `watchActiveOrders(uid)` → `watchVendorOrders(uid, statuses: ['preparing',
      'ready'])`; `watchAllOrders(uid)`; `listenToOrder(orderId)`;
      `markReady(orderId)` → `updateStatus(id, 'ready')`;
      `markCollected(orderId)` → `updateStatus(id, 'collected')`;
      `cancelOrder(order)` → `cancelAndRefund(order)`.
      **You write no wallet code at all.**

# STEP 6 — `OrderQueueViewModel` (2 h)

- [ ] Subscribes to `watchActiveOrders(vendorUid)` in the constructor
      (`onError` handler — same as step 2).
- [ ] Two computed getters filtering the one list:
      `preparing` (status `preparing`) and `ready` (status `ready`), each
      **sorted oldest-first** — `..sort((a, b) => a.createdAt.compareTo(b.createdAt))`.
      Oldest first is correct for a kitchen queue; be ready to say why.
- [ ] `markReady(orderId)` delegating to the repository.
- [ ] `dispose()` cancels.

# STEP 7 — `order_queue_page.dart` (5 h)

- [ ] `DefaultTabController` with two tabs, Preparing and Ready, showing the
      counts in the labels.
- [ ] Each order card: pickup code (large — it's the main identifier), customer
      name, item count, `centsToRM(order.total)`, and `timeAgo(order.createdAt)`.
- [ ] Preparing cards get a "Mark ready" button; ready cards get "Verify pickup"
      pushing the order detail (step 9).
- [ ] `EmptyState` per tab when it's empty.
- [ ] Watch it work: with two devices, a customer order should appear here
      **without any refresh** — that's the snapshot stream.

# STEP 8 — `VendorOrderDetailViewModel` (1.5 h)

- [ ] Constructor takes `orderId`, subscribes to `listenToOrder(orderId)`,
      holds `FoodOrder? _order` and `bool _loading`, `onError` handler,
      `dispose()` cancels.
- [ ] Passthrough methods: `markReady`, `markCollected`, `cancel(order)`.

# STEP 9 — `order_detail_page.dart` (9 h)

Full order detail plus the **QR pickup verification** — the most interesting
screen you own and a good one to demo.

- [ ] Header: pickup code, status chip, customer name, order time.
- [ ] Item breakdown — for each `OrderItem`: name, quantity, chosen
      `customizations`, selected `addOns`, `specialInstructions`, and
      `centsToRM(item.subtotal)`. Then subtotal, service fee, total.
- [ ] Status actions driven by the current status: `preparing` → "Mark ready";
      `ready` → "Scan to verify"; `collected` → no actions.
- [ ] **QR verification flow:**
      ```dart
      final scanned = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const QrScannerPage()));
      if (scanned == null) return;                 // user dismissed
      if (scanned != order.pickupCode) { show "wrong code" SnackBar; return; }
      await vm.markCollected(order.orderId);
      ```
      Handle all three outcomes — dismissed, mismatch, match. A mismatch must
      fail loudly and clearly; this is the anti-fraud check of the whole app.
- [ ] Also offer manual code entry as a fallback for when a camera won't
      cooperate — you will be glad of this during the live demo.
- [ ] Cancel action behind an `AlertDialog` warning that the customer is
      refunded in full. Calls `vm.cancel(order)` → Mervin's `cancelAndRefund`.
- [ ] Test the scanner on a **physical Android device** — an emulator's fake
      camera cannot read a real QR code. Display the customer's code on a second
      device (or on your laptop screen) and scan it from the phone.
      ⚠ This screen also hard-crashes on iOS without the `Info.plist` fix
      (step 14).

# STEP 10 — `VendorDashboardViewModel` (3 h)

- [ ] Constructor takes `vendorUid` and opens **two** subscriptions — the stall
      (`watchMyStall`) and all orders (`watchAllOrders`). Two separate
      `StreamSubscription` fields, both cancelled in `dispose()`.
- [ ] `hasStall` → `_stall != null`. The dashboard shows a *create stall* form
      when false and the real dashboard when true.
- [ ] `activeOrders` — status `preparing` or `ready`.
- [ ] `_todayOrders` — private getter filtering to today's calendar date
      (compare `year`/`month`/`day`, not a duration) **and excluding
      cancelled** orders.
- [ ] `todayOrderCount` → `_todayOrders.length`
- [ ] `todayEarnings` → **sum `o.vendorEarning` across `_todayOrders`.**
      ⚠ The reference repo recomputes this as `subtotal × (1 − stall rate)`,
      which is wrong once per-stall or historical rates differ. `vendorEarning`
      is stored on each order at place time by Mervin's `placeOrder` and is the
      truthful figure. One line, but know why.
- [ ] `toggleOpen(bool)`, `updatePrepTime(int)`, `createStall({...})`, each
      setting an `_updating` flag around the await so the UI can disable
      controls.

# STEP 11 — ⚠ `vendor_dashboard_page.dart` (12 h) — biggest file in the app

487 lines, but it is **two screens in one widget**, which is what makes it
long rather than hard. Build them separately.

**11a — the no-stall state (4 h)**
- [ ] Shown when `!vm.hasStall`. A create-stall `Form`: name, cuisine,
      description, prep time. On submit → `vm.createStall(...)`.
- [ ] After creation, show a clear "pending admin approval" state — the vendor
      must understand their stall isn't live yet. *(Justin's admin approves it;
      coordinate with him when testing.)*

**11b — the real dashboard (8 h)**
- [ ] Stall header: image, name, cuisine, rating + review count, status badge.
- [ ] An open/closed `Switch` → `vm.toggleOpen`, disabled while `vm.isUpdating`.
      ⚠ If the stall is `pending` or `suspended` the vendor must **not** be able
      to open it — guard on status, not just on the switch value.
- [ ] Prep-time control → `vm.updatePrepTime`.
- [ ] KPI tiles: `vm.todayOrderCount`, `centsToRM(vm.todayEarnings)`,
      active order count.
- [ ] A preview list of `vm.activeOrders` (first 3–5) with a "view all" into the
      order queue.
- [ ] Navigation into your other screens: menu management, order queue,
      earnings.
- [ ] Sign out via `context.read<AuthViewModel>().logout()`.

**Tip:** pull each section into its own small private widget
(`_StallHeader`, `_KpiRow`, `_ActiveOrdersPreview`). A 487-line `build` method
is both unreadable and very hard to defend in a Q&A; six 80-line widgets are
easy to explain one at a time.

# STEP 12 — Earnings (6 h)

- [ ] **`EarningsRepository`** — thin view over Mervin's `WalletRepository`:
      `watchEarnings(vendorUid)` → `_wallet.watchTransactions(vendorUid, types:
      [txnEarning, txnWithdrawal, txnRefund])`, and `withdraw(uid, cents)` →
      `_wallet.withdraw(...)`. It filters the shared ledger to the entry types a
      vendor cares about; it does not have its own storage.
- [ ] **`EarningsViewModel`** — `earnings(vendorUid)` returning the stream, plus
      `withdraw(uid, cents)` with `_processing` and `_error` state. Catch the
      failure and set a friendly message; don't let the exception reach the UI.
- [ ] **`vendor_earnings_page.dart`** — total earned / total withdrawn /
      available balance summary; an `fl_chart` bar chart of daily earnings for
      the last 7 days; the transaction list with type icons, signed amounts and
      `formatDateTime`; and a withdraw dialog validating against the available
      balance.
- [ ] The withdrawal is simulated (no real payout) — say so in your user manual.

# STEP 13 — Your tests (5 h)

**Test only your own files.** Testing marks are per person.

Unit tests (`test/` mirroring your folder structure), using
`FakeFirebaseFirestore` — this is why every constructor takes an injectable
`db`:
- [ ] `test/vendor/menu_repository_test.dart` — `addItem` writes a document
      whose `itemId` matches its own id; `setAvailable` flips only that field;
      `deleteItem` removes it; `watchMenuItems` emits the current list.
- [ ] `test/vendor/menu_management_vm_test.dart` — starts loading, emits items,
      `isLoading` becomes false; `toggleAvailable` inverts the stored value.
- [ ] `test/vendor/order_queue_vm_test.dart` — orders split correctly into
      `preparing` and `ready`, and each bucket is sorted oldest-first.
- [ ] `test/vendor/vendor_dashboard_vm_test.dart` — `todayOrderCount` **excludes
      cancelled orders**; `todayEarnings` sums `vendorEarning`; yesterday's
      orders are excluded. (Construct `FoodOrder`s directly — no Firestore
      needed for the getters.)

Widget tests:
- [ ] `test/vendor/menu_management_page_test.dart` — renders `EmptyState` with
      no items, and a row per item when populated. Inject a fake VM.
- [ ] `test/vendor/order_queue_page_test.dart` — an order card displays its
      pickup code and formatted total.

# STEP 14 — ⚠ iOS permission fix (0.5 h) — **assigned to you**

> **Platform reality.** You develop and test on Android — the team has no Mac
> or iPhone. But the iOS project stays correct and buildable, because a
> friend's Mac may be available for a one-off check. The *fix* below is plain
> XML you can write on Windows today; the *verification* is opportunistic.

Both camera features in the app are yours, so this defect is yours.
`ios/Runner/Info.plist` currently declares **neither** required usage string.
On iOS, touching the camera or photo library without one is an **instant hard
crash**, not a permission denial.

- [ ] Add inside the top-level `<dict>` of `ios/Runner/Info.plist`:
      ```xml
      <key>NSCameraUsageDescription</key>
      <string>StallHop uses the camera to scan customer pickup QR codes and to photograph your menu items.</string>
      <key>NSPhotoLibraryUsageDescription</key>
      <string>StallHop needs photo library access so you can choose an existing photo for a menu item.</string>
      ```
      Write a real, specific reason. Apple rejects vague strings, and a vague
      one is a weak Q&A answer too.
- [ ] **Verify on Android** — that's steps 4b and 9, and it's your real,
      available-today testing.
- [ ] **If you can borrow a Mac + iPhone, book the session deliberately.** It
      is ~20 minutes: `flutter build ios`, run on device, open the QR scanner
      (step 9), then add-item → pick image → camera and gallery (step 4b).
      Screenshot it. Do this before the report deadline — a verified fix beats
      a plausible one, and this is the only defect of the three whose fix you
      cannot otherwise prove.
- [ ] **Report whichever actually happened.** Verified → show the evidence.
      Not verified → *"the missing iOS usage-description strings were
      identified and corrected by inspection; the fix could not be validated at
      runtime within the project window as the team has no macOS/iOS hardware.
      Android is the target platform for all testing evidence."* Never claim a
      test you didn't run.
- [ ] Be able to explain the **platform difference**, which you can answer fully
      either way: on Android, `mobile_scanner` and `image_picker` merge their
      own permission declarations into the manifest at build time (which is why
      `AndroidManifest.xml` only declares `POST_NOTIFICATIONS`), whereas iOS
      requires a static usage-description string per sensitive API or the OS
      terminates the app on first access. Also know that **Firebase Test Lab's
      Robo pass cannot catch this**, because Robo is Android-only (Test Lab
      uses XCUITest for iOS) — which is exactly why this step is manual.

# STEP 15 — Report deliverables (4 h)

- [ ] ~9 screenshots: vendor dashboard, create stall, menu management,
      add/edit item, image picker, order queue, order detail, QR scanner,
      earnings. Consistent device size, light theme, seeded data so nothing
      looks empty. Name them `NN_vendor_screenname.png`.
- [ ] Vendor-flow wireframes.
- [ ] Vendor section of the user manual.
- [ ] Your test evidence (screenshots of your suite passing).

---

## Effort summary

| Step | File | Hours |
|---|---|---|
| 1 | `menu_repository.dart` | 3 |
| 2 | `menu_management_vm.dart` | 2 |
| 3 | `menu_management_page.dart` | 4 |
| 4 | ⚠ `add_edit_item_page.dart` | **12** |
| 5 | `vendor_order_repository.dart` | 4 |
| 6 | `order_queue_vm.dart` | 2 |
| 7 | `order_queue_page.dart` | 5 |
| 8 | `order_detail_vm.dart` | 1.5 |
| 9 | `order_detail_page.dart` (QR) | 9 |
| 10 | `vendor_dashboard_vm.dart` | 3 |
| 11 | ⚠ `vendor_dashboard_page.dart` | **12** |
| 12 | earnings (repo + VM + page) | 6 |
| 13 | tests | 5 |
| 14 | iOS `Info.plist` | 0.5 |
| 15 | report assets | 4 |
| | **Total** | **~68 h** |

**The two hardest files are steps 4 and 11**, at 12 h each — a third of your
total between them. `add_edit_item_page.dart` is hard because of genuine
complexity (form + upload + two nested dynamic editors); `vendor_dashboard_page.dart`
is hard mainly because of size. Break both into the sub-steps above and start
step 4 early — do not leave it to the final week.

---

## Deviations from the reference repo (say these in the Q&A if asked)

1. **`createStall` writes `commissionRate: null` instead of a hardcoded 0.10.**
   The reference hardcodes it, which is precisely why the admin's commission
   setting never affects pricing. `null` means "inherit the venue default".
2. **`todayEarnings` sums the stored `vendorEarning`** instead of recomputing
   from the stall's current rate. The stored value is what was actually
   credited; recomputing gives the wrong answer for any order placed at a
   different rate.
3. Optionally split the two large pages into private sub-widgets. Same
   behaviour, far easier to explain — recommended, and worth mentioning as a
   deliberate readability decision rather than an accident.
