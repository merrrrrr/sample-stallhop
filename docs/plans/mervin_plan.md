# Mervin — Build Plan

**Role:** Customer + core/shared foundation + models + auth + order/wallet
transaction logic + final integration
**Total estimate:** ~25 h (Phase 0) + ~45 h (Phase 1) + ~12 h (Phase 2/3)

Read `foundation_and_integration.md` first. Phase 0 blocks both teammates —
their Phase 1 cannot start until it is merged, so protect that timeline.

---

# PHASE 0 — Foundation (~25 h, blocking)

## 0.1 Project + Firebase setup (~3 h)

- [ ] `flutter create stallhop` (org id matching the reference so
      `google-services.json` stays valid)
- [ ] Firebase Console: create project `stallhop-app`
- [ ] Enable **Authentication** → Email/Password + Google providers
- [ ] Enable **Cloud Firestore** in production mode (rules come in §0.6)
- [ ] Enable **Cloud Storage**
- [ ] `dart pub global activate flutterfire_cli` → `flutterfire configure`
      → generates `lib/firebase_options.dart` for **android + ios**.
      Configure both platforms even though day-to-day development is Android
      only — the iOS config costs nothing to generate now and is painful to
      retrofit later when a Mac becomes available (see
      `foundation_and_integration.md` §6.2).
- [ ] Android: confirm `android/app/google-services.json` written;
      set `minSdk` to 23 (required by `firebase_auth`) in
      `android/app/build.gradle.kts`
- [ ] Android: add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
      to `AndroidManifest.xml`
- [ ] iOS: place `GoogleService-Info.plist` in `ios/Runner/`; set
      `platform :ios, '13.0'` in the Podfile. You cannot run `pod install` from
      Windows — that happens on whichever Mac the app is eventually built on.
      Keeping the config committed and correct is what makes that build a
      short session rather than a day of setup.
- [ ] Confirm the **Android** build runs on a physical device or emulator.
      Decide now which device/emulator the team will standardise on — the same
      one is used for all report screenshots (§7.4 of the shared plan).
- [ ] `pubspec.yaml` — add all dependencies in one go so nobody has to touch it
      later (see the reference `pubspec.yaml`; keep the comment group headers,
      they make later appends conflict-free):
      firebase_core, firebase_auth, cloud_firestore, firebase_storage,
      google_sign_in, provider, qr_flutter, mobile_scanner,
      google_maps_flutter, geolocator, image_picker, cached_network_image,
      flutter_local_notifications, intl, flutter_rating_bar, fl_chart;
      dev: mockito, build_runner, **fake_cloud_firestore**, integration_test
- [ ] `flutter run` on a device — blank app boots and connects to Firebase
- [ ] Commit. Push `phase0-foundation`.

## 0.2 Core layer, in dependency order (~6 h)

Build in exactly this order — each depends only on what precedes it.

- [ ] **`lib/core/utils/constants.dart`**
      A private-constructor holder (`AppConstants._();`) of `static const`
      values only. Collection paths (`usersCollection`, `stallsCollection`,
      `menuItemsSubcollection`, `ordersCollection`, `transactionsCollection`,
      `reviewsCollection`, `announcementsCollection`, `configCollection`,
      `venueConfigDoc`), the three role strings, the four order statuses, the
      five stall statuses, the five transaction types, plus
      `defaultCommissionRate = 0.10`, `serviceFeeCents = 50`, and
      `topUpPresetsCents = [1000, 2000, 5000, 10000]`. Nothing in the app may
      type a collection name as a literal — this file is why.
      **Append only, never reorder** (merge-conflict discipline).

- [ ] **`lib/core/utils/app_exceptions.dart`**
      `AppException implements Exception` carrying a user-facing `message` and
      overriding `toString()`. Two subclasses: `InsufficientBalanceException`
      and `NotFoundException`, each with a default message via
      `super.message = '...'`. These exist so the wallet transaction can fail
      with a message the UI can show directly instead of leaking a Firestore
      error string.

- [ ] **`lib/core/utils/formatters.dart`**
      Top-level functions, not a class. `centsToRM(int) → 'RM 7.50'` handling
      negatives via a sign prefix; `rmToCents(String) → int?` returning null on
      unparseable input; three `DateFormat` singletons behind `formatDate`,
      `formatTime`, `formatDateTime` (always `.toLocal()` first); and
      `timeAgo(DateTime)` returning "just now" / "N min ago" / "N h ago" /
      "N d ago" / a date beyond a week.

- [ ] **`lib/core/utils/validators.dart`**
      `Validators._()` holder of statics matching Flutter's
      `FormFieldValidator` contract — **return `null` when valid**, an error
      string when not. `email` (regex), `password` (min 6),
      `confirmPassword(value, original)`, `phone` (Malaysian mobile, strips
      spaces/dashes, accepts `0…`/`+60…`/`60…`), `required(value, [fieldName])`,
      and `price` (parses Ringgit, rejects ≤ 0).

- [ ] **`lib/core/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`**
      Orange-led palette; `AppTheme.lightTheme` assembling a `ThemeData` from
      the two. Keep it small — theming is not where the marks are.

- [ ] **`lib/core/services/firestore_service.dart`** ← *the keystone file*
      Declares `typedef JsonMap = Map<String, dynamic>;` and
      `typedef QueryBuilder = Query<JsonMap> Function(Query<JsonMap>);`.
      Wraps an injectable `FirebaseFirestore _db`. Methods: `newDocId(path)`
      (id without a write), `getDocument`, `documentStream`, `setDocument(path,
      data, {merge})`, `updateDocument`, `deleteDocument`, `getCollection(path,
      {QueryBuilder? query})`, `collectionStream(path, {QueryBuilder? query})`.
      Collection methods apply the optional `query` callback to shape the
      `Query` before executing, then map `snap.docs` to raw `.data()` maps.
      **Returns maps, never snapshots** — every StallHop document embeds its
      own id, so callers never need `doc.id`. Be ready to explain that trade-off.

- [ ] **`lib/core/services/auth_service.dart`**
      Injectable `FirebaseAuth` + `GoogleSignIn`. Exposes `currentUser`,
      `authStateChanges`, `signUp`, `signIn`, `signInWithGoogle()` (returns
      `null` when the user cancels the picker — the caller must handle that),
      `sendPasswordResetEmail`, `updatePassword`, `signOut` (Google *then*
      Firebase). Holds **no app state**; `AuthViewModel` owns that.

- [ ] **`lib/core/services/storage_service.dart`**
      `uploadImage(File, String path) → Future<String>` download URL, and
      `deleteImage(String url)` which resolves via `refFromURL` and swallows
      only `object-not-found`, rethrowing everything else. Yong Jun depends on
      this for menu photos — get it right before he starts.

- [ ] **`lib/core/services/notification_service.dart`**
      `flutter_local_notifications` wrapper: `init()` with **both** Android and
      Darwin initialization settings, requesting permission on each
      (`requestNotificationsPermission()` on Android — required from Android 13
      — and `requestPermissions(alert/badge/sound)` on iOS). Keep the Darwin
      half even though it is untestable day to day; it is a few lines and its
      absence would silently break notifications on any future iOS build. And
      `show({required int id, required String title, required String body})`.
      Keep `show` `Future<void>` and overridable — the coordinator test
      subclasses it.

- [ ] **`lib/core/routing/app_router.dart`**
      One function: `Widget getHomeForRole(String role)` switching on the three
      role constants into `CustomerHomePage` / `VendorDashboardPage` /
      `AdminDashboardPage`, defaulting to `LoginPage`. Three lines of real
      logic. It will not compile until all three homes exist — stub the vendor
      and admin homes with a placeholder `Scaffold` so Phase 0 builds, and let
      the teammates replace them.

## 0.3 Models (~4 h)

Every model: `final` fields, a named-parameter constructor, `fromJson`,
`toJson`, `copyWith`. `Timestamp` ⇄ `DateTime` conversion lives **here and
nowhere else**. Defensive reads throughout (`json['x'] ?? default`) so a
document written by an older build never crashes the app.

- [ ] **`user.dart` → `AppUser`** (named to avoid clashing with Firebase's
      `User`). `uid, name, email, phone, role, profileImageUrl?,
      walletBalance (int cents, default 0), fcmToken?, createdAt, updatedAt`.
- [ ] **`stall.dart` → `Stall`.** `stallId, vendorUid, name, description,
      cuisine, imageUrl?, status (default 'pending'), prepTimeMinutes (15),
      averageRating (double), totalReviews, latitude?, longitude?, createdAt,
      updatedAt`, plus `bool get isOpen => status == 'open'`.
      ⚠️ **`commissionRate` is `double?`, nullable** — `null` means "inherit the
      venue default". This is the decided deviation from the reference (see
      `foundation_and_integration.md` §6.1); build it nullable from the start
      so nothing has to migrate later.
- [ ] **`menu_item.dart` → `MenuItem`.** `itemId, stallId, name, description,
      price (int cents), category, imageUrl?, available (default true),
      customizations, addOns, createdAt, updatedAt`. The last two are
      `List<Map<String, dynamic>>` — customizations are single-select groups
      `{"name": "Size", "options": ["S","L"]}`, add-ons are
      `{"name": "Extra egg", "price": 150}`. Needs a `static _mapList(dynamic)`
      helper because Firestore returns `List<dynamic>` and a bare cast throws.
- [ ] **`order_item.dart` → `OrderItem`.** *Embedded in the order, not a
      collection.* `itemId, name, unitPrice (base, excludes add-ons), quantity,
      customizations (Map), addOns (List<Map>), specialInstructions`. Two
      computed getters: `addOnsTotal` (fold of add-on prices) and
      `subtotal => (unitPrice + addOnsTotal) * quantity`. `toJson` writes
      `subtotal` as a stored field for readability in the console even though
      `fromJson` recomputes it.
- [ ] **`order.dart` → `FoodOrder`** (named to avoid Dart/Firestore `Order`
      clashes). `orderId, customerUid, customerName, stallId, vendorUid,
      stallName, items (List<OrderItem>), subtotal, serviceFee, total, status,
      pickupCode, refunded, dismissed, createdAt, updatedAt, readyAt?,
      collectedAt?, cancelledAt?`.
      ⚠️ **Plus the two decided new fields:** `commissionRate` (double, the rate
      applied at place time) and `vendorEarning` (int cents, the exact amount
      credited). Both defensive in `fromJson`.
      Needs a `static DateTime? _ts(dynamic)` helper for the three nullable
      timestamps. `customerName` and `stallName` are denormalised on purpose —
      an order must render without extra reads.
- [ ] **`transaction.dart` → `WalletTransaction`** (named to avoid Firestore's
      `Transaction`). `txnId, userId, type, amount, balanceBefore,
      balanceAfter, description, relatedOrderId?, createdAt`. `amount` is
      always **positive**; the `type` conveys direction. `balanceBefore`/`After`
      make the ledger self-auditing.
- [ ] **`review.dart` → `Review`.** `reviewId, orderId, stallId, customerUid,
      customerName, rating (1–5 int), comment, createdAt`.
- [ ] **`announcement.dart` → `Announcement`.** `announcementId, title,
      message, createdBy, createdAt`.
- [ ] **`venue_config.dart` → `VenueConfig`.** Singleton at `config/venue`.
      `venueName, defaultCommission, serviceFee, pickupCodePrefix,
      pickupCodeCounter, latitude?, longitude?, updatedAt`. Note the
      code/counter reset daily — the mechanism lives in `placeOrder`.
- [ ] **Test as you go:** `test/models/models_test.dart` — round-trip each
      model through `toJson → fromJson → toJson` and compare the two maps as
      strings (deterministic deep compare that also handles `Timestamp`). Plus
      an explicit `OrderItem.subtotal` case and a Timestamp-fidelity case.

## 0.4 Shared widgets (~3 h)

- [ ] `widgets/loading_indicator.dart` — centred spinner + optional message.
- [ ] `widgets/empty_state.dart` — icon + title + subtitle + optional action.
      Used on nearly every list screen by all three of you.
- [ ] `widgets/stall_card.dart` — image, name, cuisine, rating, prep time,
      open/closed badge, `onTap`.
- [ ] `widgets/wallet_balance_card.dart` — formatted balance + top-up action.
- [ ] `widgets/order_status_stepper.dart` — horizontal preparing → ready →
      collected stepper driven by a status string.
- [ ] `widgets/pickup_code_display.dart` — large code text + `qr_flutter`
      `QrImageView` of the code.
- [ ] `widgets/qr_scanner_widget.dart` → **`QrScannerPage`.** Full-screen
      `MobileScanner`, pops with the first decoded `rawValue` or `null` if
      dismissed. Guard with a `_handled` bool — `onDetect` fires repeatedly and
      without the guard you `pop` several times and blow up the navigator.
      Torch + camera-switch actions; dispose the controller.
      *Yong Jun consumes this — it must work before he starts.*
- [ ] Widget tests for the three most reusable: `stall_card_test.dart`,
      `wallet_balance_card_test.dart`, `order_status_stepper_test.dart`.

## 0.5 Auth feature (~4 h)

- [ ] **`features/auth/repository/auth_repository.dart`**
      Thin user-document CRUD over `FirestoreService`: `createUser(AppUser)`,
      `getUser(uid)`, `watchUser(uid) → Stream<AppUser?>`, `updateUser(uid, map)`.
- [ ] **`features/auth/view_model/auth_view_model.dart`** ← *the most
      structurally important file in the app*
      Declares `enum AuthStatus { unknown, unauthenticated, needsRoleSelection,
      authenticated }`. Subscribes to `authStateChanges` in the constructor; on
      each event cancels the previous user-doc subscription and re-subscribes
      to `watchUser(uid)`. State: signed out → `unauthenticated`; signed in
      *with* a user doc → `authenticated`; signed in *without* one → 
      `needsRoleSelection` (a fresh Google account that must pick a role).
      - `_suppressRolePrompt` exists because during email registration the auth
        user is created a moment before the Firestore document, and without the
        flag the app flashes the role-selection screen. Set it true at the top
        of `register()`, clear it once the doc arrives or on any error. **Be
        ready to explain this in the Q&A — it is exactly the kind of subtle
        state question you will be asked.**
      - `onError` on the user-doc stream is mandatory: without it a rules
        failure wedges the app on the splash screen permanently.
      - `_mapAuthError(FirebaseAuthException)` translates codes to human
        messages; deliberately collapses `user-not-found` / `wrong-password` /
        `invalid-credential` into one "Incorrect email or password" so the app
        doesn't leak which emails are registered.
      - Methods: `login`, `register({name, email, phone, password, role})`,
        `googleSignIn`, `completeRoleSelection({role, phone})`, `logout`,
        `clearError`.
- [ ] **`features/auth/view/login_page.dart`** — `Form` + email/password fields
      with `Validators`, error banner from `vm.error`, loading state disables
      the button, Google sign-in button, links to register and password reset.
- [ ] **`features/auth/view/register_page.dart`** — name, email, phone,
      password, confirm password, and a role selector; calls `vm.register`.
- [ ] **`features/auth/view/choose_role_page.dart`** — three role cards + an
      optional phone field; calls `vm.completeRoleSelection`. Only ever shown
      in the `needsRoleSelection` state.
- [ ] **`lib/main.dart`** — `WidgetsFlutterBinding.ensureInitialized()`,
      `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`,
      init `NotificationService`, construct `AuthViewModel` and
      `NotificationCoordinator` and wire
      `authViewModel.addListener(() => coordinator.sync(authViewModel.currentUser))`,
      then `MultiProvider` over `AuthViewModel` + `CartViewModel` around
      `StallHopApp`. `AuthGate` switches `vm.status` into the splash, login,
      role-selection, or `getHomeForRole(vm.currentUser!.role)`.
      **You own this file. Nobody else edits it** — teammates send you their
      provider line.
- [ ] **`core/services/notification_coordinator.dart`** — client-side
      replacement for the planned Cloud Functions. `sync(AppUser?)` is
      idempotent: returns early if uid *and* role are unchanged, else stops and
      restarts listeners. Watches announcements for everyone (filtered
      `createdAt > Timestamp.now()` so history doesn't fire, and skips the
      author's own), customer order status transitions, and vendor new-order
      arrivals. The `_orderStatuses` map is **seeded from the first snapshot**
      so pre-existing orders don't notify on login — that seeding logic is the
      subtle part; write the test alongside it.
- [ ] `test/services/notification_coordinator_test.dart` with a
      `RecordingNotificationService extends NotificationService` that captures
      calls instead of touching the platform plugin.
- [ ] `test/utils/formatters_test.dart`, `test/utils/validators_test.dart`.

## 0.6 Security rules (~2 h) — **greenfield, not in the reference repo**

There is **no `firestore.rules` file in the reference repo** and `firebase.json`
declares only `indexes`. You are writing these from scratch, and since the
client performs all wallet arithmetic, these rules are the only thing between a
customer and `walletBalance: 999999`. Treat it as a graded item.

- [ ] Create `firestore.rules`; add `"rules": "firestore.rules"` to the
      `firestore` block of `firebase.json`.
- [ ] Helpers: `signedIn()`, `myUid()`, `userRole()` via
      `get(/databases/$(database)/documents/users/$(myUid())).data.role`,
      `isAdmin()`, `isVendor()`.
- [ ] `users/{uid}` — read own doc or admin; create only own uid, role must be
      one of the three, and `walletBalance` must start at 0; update own doc but
      **`role` immutable**; no deletes.
- [ ] `stalls/{stallId}` — read by any signed-in user; create by a vendor for
      their own `vendorUid` with `status == 'pending'`; update by the owning
      vendor **or** an admin; only an admin may write `status` or
      `commissionRate`; delete admin-only.
- [ ] `stalls/{stallId}/menuItems/{itemId}` — read by any signed-in user;
      write only by the vendor who owns the parent stall (a `get()` on the
      parent).
- [ ] `orders/{orderId}` — read if `customerUid == myUid()` or
      `vendorUid == myUid()` or admin; create by the customer for themselves
      with `status == 'preparing'`; update by the owning vendor (status
      transitions), the customer (cancel), or an admin.
- [ ] `transactions/{txnId}` — read own (`userId == myUid()`) or admin; create
      signed-in; **no update, no delete** — a ledger is append-only. Be ready to
      explain why immutability matters here.
- [ ] `reviews/{reviewId}` — read all signed-in; create by the reviewing
      customer only; no update/delete.
- [ ] `announcements/{id}` — read all signed-in; write admin-only.
- [ ] `config/venue` — read all signed-in (all three roles now read it);
      write admin-only, **except** the pickup-code fields which `placeOrder`
      must bump. Simplest defensible rule: allow a customer write that touches
      only `pickupCodePrefix`, `pickupCodeCounter`, `pickupCodeDate`,
      `updatedAt` — use `request.resource.data.diff(resource.data)
      .affectedKeys().hasOnly([...])`.
- [ ] **Document the unavoidable hole.** `placeOrder` credits the *vendor's*
      `walletBalance` from the *customer's* client. No rule can verify that
      credit corresponds to a real order, because rules cannot inspect sibling
      writes in a transaction. Leave a comment in the rules file saying so and
      write it up in the report's limitations section (§8 of the shared doc).
      Naming this weakness yourself is worth more marks than leaving it to be
      discovered.
- [ ] Deploy: `firebase deploy --only firestore:rules`
- [ ] Copy `firestore.indexes.json` from the reference **as-is** — its seven
      composite indexes are correct and complete (orders by
      status/customerUid/vendorUid + createdAt, vendorUid+status+createdAt,
      transactions by userId(+type)+createdAt, reviews by stallId+createdAt).
      Deploy with `firebase deploy --only firestore:indexes`.

## 0.7 Seed data (~2 h)

Auth accounts cannot be created by a script without the Admin SDK, so create
them through the app's own register page, then seed Firestore around them.

- [ ] Register three accounts via the running app:
      `customer@stallhop.test`, `vendor@stallhop.test`, `admin@stallhop.test`
      (shared password, documented in the team channel — **never committed**).
- [ ] Copy the three UIDs out of the Firebase Console.
- [ ] Write `integration_test/seed_test.dart` — a "test" that exists only to
      write seed data. This runs on a device with Firebase already initialised,
      so it needs no extra tooling:
      `flutter test integration_test/seed_test.dart`
- [ ] Seed contents:
      - `config/venue` — `venueName`, `defaultCommission: 0.10`,
        `serviceFee: 50`, `pickupCodePrefix: 'A'`, `pickupCodeCounter: 0`,
        venue lat/lng, `updatedAt`
      - **4 stalls**, all `vendorUid` = the vendor test account, varied
        cuisines (Malay, Chinese, Indian, Western), `status: 'open'` for three
        and `'pending'` for one **so Justin has something to approve on day
        one**, `commissionRate: null` (inherit)
      - **~15 menu items** spread across the four stalls, prices 300–1800
        cents, at least two with `customizations`, two with `addOns`, one with
        `available: false`
      - top up the customer account to `walletBalance: 10000` (RM 100)
- [ ] Make the script idempotent — fixed document ids and `set` with merge, so
      re-running restores state rather than duplicating. You will re-run it
      constantly during QA.
- [ ] Commit it. All three of you need working data.

## 0.8 Phase 0 exit

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] App boots → login → register → each role lands on its (possibly stubbed)
      home
- [ ] Merge `phase0-foundation` → `main`
- [ ] **Run the 90-minute teaching session** (`foundation_and_integration.md`
      §5) before either teammate starts. Do not skip this to save time — it is
      what makes their Q&A survivable.

---

# PHASE 1 — Customer role (~45 h)

Build order per screen: **repository → view model → view.** Never write a view
before its view model compiles.

## 1.1 `StallRepository` (~2 h)
`features/customer/repository/stall_repository.dart`. Read-only access for
customers. `watchVisibleStalls()` / `getVisibleStalls()` query
`stalls` where `status whereIn ['open','closed']` — pending, suspended and
rejected stalls are invisible to customers, which is the mechanism behind
Justin's approve/suspend actions. Plus `getStall`, `watchStall`,
`getMenuItems(stallId)`, `watchMenuItems(stallId)` on the
`stalls/{stallId}/menuItems` subcollection.

## 1.2 `StallBrowsingViewModel` + home/browse screens (~6 h)
`stall_browsing_vm.dart`. Holds `_all`, `_loading`, `_error`, `_search`,
`_cuisine`, `_sort` (`enum StallSort { rating, prepTime, name }`). The
`stalls` getter filters by search and cuisine, sorts by the selected mode,
**then applies a second stable sort putting open stalls above closed ones
regardless of the chosen sort** — that ordering is deliberate; be ready to
explain why two sorts rather than a compound comparator. `cuisines` derives the
filter chips from the data.

- [ ] `customer_home_page.dart` — `BottomNavigationBar` shell over four tabs
      (Browse, Orders, Wallet, Profile). Keep the tab labels exactly
      `Orders` / `Wallet` / `Profile` — the integration test asserts on them.
- [ ] `stall_browsing_page.dart` — search field, cuisine `FilterChip` row, sort
      menu, `ListView` of `StallCard`, empty state when filters match nothing.

## 1.3 `stall_menu_page.dart` + `item_detail_page.dart` (~7 h)
- [ ] Menu page: stall header (image, rating, prep time, open/closed), menu
      items grouped by `category`, unavailable items visibly disabled.
- [ ] Item detail: image, description, one `RadioListTile` group per entry in
      `customizations`, a `CheckboxListTile` per `addOns` entry, quantity
      stepper, special-instructions field, and a **live-updating total** —
      `(price + selected add-ons) × quantity`. Builds an `OrderItem` and calls
      `cart.addItem(stall, item)`.

## 1.4 `CartViewModel` (~4 h) — app-wide provider
`cart_vm.dart`. Provided at the root in `main.dart` so the cart survives
navigation. Holds `Map<String, List<OrderItem>> _itemsByStall` and
`Map<String, Stall> _stalls`. **Each stall group becomes its own order with its
own service fee** — that is the core rule of this class.

`_signature(item)` concatenates `itemId | customizations | addOns |
specialInstructions`; identical signatures merge by quantity, differing ones
stay separate lines. Methods: `addItem`, `updateQuantity` (≤ 0 removes),
`incrementItem`, `decrementItem`, `removeItem` (removing the last line drops
the stall entirely), `clearStall`, `clear`. Getters: `getSubtotal(stallId)`,
`getServiceFee(stallId)`, `getStallTotal(stallId)`, `grandSubtotal`,
`totalServiceFee`, `grandTotal`, `totalItemCount`, `isEmpty`.

> Phase 2 change: `getServiceFee` reads the venue-config value rather than the
> hardcoded constant (`foundation_and_integration.md` §6.1, Bug C).

- [ ] `test/view_models/cart_vm_test.dart` — merging identical lines, keeping
      distinct lines when add-ons differ, decrement-to-zero removal,
      multi-stall grouping and per-group service fees.

## 1.5 ⚠ `OrderRepository.placeOrder` (~8 h) — highest-risk file in the app

`features/customer/repository/order_repository.dart`. One Firestore
transaction must atomically: validate funds, generate the daily pickup code,
debit the customer, credit the vendor net of commission, and write the order
plus two ledger entries. If any part fails, **all** of it must roll back.

**The one hard rule: in a Firestore transaction, every read must happen before
every write.** Violating it throws at runtime, not compile time.

- [ ] Compute `subtotal` from the items and `total = subtotal + serviceFee`
      *before* opening the transaction.
- [ ] Inside `_db.runTransaction((txn) async { ... })`, **reads first**:
      `txn.get(customerRef)`, `txn.get(vendorRef)`, `txn.get(_venueRef)`.
- [ ] Guard: `if (custBefore < total) throw const InsufficientBalanceException();`
      Throwing inside the transaction aborts it — nothing is written.
- [ ] **Pickup code, with daily reset.** Compare the stored `pickupCodeDate`
      against today's `yyyy-MM-dd` key (`_dateKey` helper). New day → prefix
      `'A'`, counter `0`. Otherwise continue from the stored values. Code is
      `prefix + counter.toString().padLeft(3, '0')` → `A001`. This replaces the
      planned scheduled Cloud Function — the reset is client-side, evaluated
      per order. Be ready to explain why that is acceptable here (single venue,
      counter is monotonic within a day, collisions impossible because the
      transaction serialises).
- [ ] **Commission** (the Phase 2 wiring, built in from the start):
      ```dart
      final venueRate = (venueSnap.data()?['defaultCommission']
          ?? AppConstants.defaultCommissionRate).toDouble();
      final rate = stall.commissionRate ?? venueRate;   // null = inherit
      final vendorEarning = (subtotal * (1 - rate)).round();
      ```
      Commission is taken on `subtotal`, **not** `total` — the service fee is
      the platform's, not the vendor's. Store both `rate` and `vendorEarning`
      on the order.
- [ ] **Writes**: `txn.set(orderRef, order.toJson())`;
      `txn.update(customerRef, {'walletBalance': custAfter, ...})`;
      `txn.update(vendorRef, {'walletBalance': vendAfter, ...})`;
      `txn.set(_venueRef, {pickup code fields}, SetOptions(merge: true))`
      (**merge**, or you wipe the venue config); then `_writeTxn(...)` twice —
      a `payment` entry for the customer at `total` and an `earning` entry for
      the vendor at `vendorEarning`.
- [ ] `_writeTxn` private helper takes the `Transaction`, builds a
      `WalletTransaction` with `balanceBefore`/`balanceAfter`, and `txn.set`s it.
      Amounts are always positive; the `type` carries direction.
- [ ] **`cancelAndRefund(order)`** — early-return if `order.refunded`. Reads
      both wallets, credits the customer `order.total`, debits the vendor
      **`order.vendorEarning`** (the stored amount — never recompute), sets
      `status: 'cancelled'`, `refunded: true`, `cancelledAt`, and writes two
      `refund` ledger entries. *Do not write a `_commissionFor` helper.* The
      reference repo has one and it is the source of a real money bug
      (`foundation_and_integration.md` §6.1, Bug B).
- [ ] Read/watch methods: `updateStatus(orderId, status)` (stamps `readyAt` or
      `collectedAt` to match), `getOrder`, `listenToOrder`,
      `watchCustomerOrders(uid)`, `watchVendorOrders(uid, {statuses})` — the
      last two are consumed by Yong Jun, so their signatures are contracts.
- [ ] **`test/repositories/order_repository_test.dart`** against
      `FakeFirebaseFirestore`: codes increment within a day; counter resets when
      the stored date is in the past; counter continues when it is today;
      `placeOrder` debits the customer `subtotal + fee` and credits the vendor
      `subtotal × (1 − rate)`; insufficient balance throws **and writes
      nothing**; cancel restores **both** wallets to their exact starting
      values at a non-0.10 rate (the Bug B regression test); a stall override
      beats the venue default.

## 1.6 `WalletRepository` + `WalletViewModel` + `wallet_page.dart` (~5 h)
`_applyDelta({uid, delta, type, description, relatedOrderId, requireFunds})` is
the single private core; `topUp`, `refund`, `deductPayment`, `withdraw` are all
thin wrappers over it with different signs and types. Each runs its own
transaction so the balance and its ledger row can never diverge.
`requireFunds` rejects a negative resulting balance with
`InsufficientBalanceException`. Also `getTransactions` / `watchTransactions`
with an optional `types` filter — **Yong Jun's `EarningsRepository` delegates
straight into `watchTransactions`**, so keep that signature stable.

The wallet *balance* shown in the UI comes from the auth user document via
`AuthViewModel`, not from this repository — one source of truth. The view model
only handles top-ups and the ledger stream.

- [ ] `wallet_page.dart` — `WalletBalanceCard`, preset top-up chips from
      `AppConstants.topUpPresetsCents`, custom amount field, transaction list
      with per-type icons and signed amounts.
- [ ] `test/view_models/wallet_vm_test.dart` — top-up success and ledger row;
      unknown user fails cleanly without throwing to the UI; `deductPayment`
      rejects insufficient funds **and leaves the ledger empty**; withdraw;
      refund.

## 1.7 Cart, checkout, order placed (~5 h)
- [ ] `cart_page.dart` — one section per stall group with its own subtotal,
      service fee and total; quantity steppers; a place-order button per group.
      `_placeOrder()` calls `_orderRepository.placeOrder(customer: …,
      stall: cart.stallFor(stallId), items: cart.itemsFor(stallId),
      serviceFeeCents: cart.getServiceFee(stallId))`, then
      `cart.clearStall(stallId)` and `Navigator.pushReplacement` to the
      confirmation. Catch `InsufficientBalanceException` and show its message —
      that is what the custom exception type is for.
- [ ] `order_placed_page.dart` — `PickupCodeDisplay` (code + QR), stall name,
      estimated prep time, buttons to track the order or return home.

## 1.8 Order tracking, list, review (~6 h)
- [ ] `order_tracking_vm.dart` + `order_tracking_page.dart` — subscribes to
      `listenToOrder`; `OrderStatusStepper`, live status, the pickup QR while
      `ready`, item breakdown, and a cancel action while still `preparing`.
- [ ] `orders_list_page.dart` — `watchCustomerOrders(uid)` split into active
      and past; tapping an active order opens tracking, a collected one offers
      a review.
- [ ] `review_vm.dart` + `review_page.dart` — `checkExisting(orderId)` first
      (one review per order), `flutter_rating_bar` for the stars, comment field.
      `ReviewRepository.createReview` runs a transaction that writes the review
      **and** recomputes the stall's `averageRating` / `totalReviews` in the
      same atomic step — the client-side stand-in for an `onReviewCreated`
      Cloud Function. The incremental mean is
      `((oldAvg × oldCount) + rating) / (oldCount + 1)`, rounded to 2 dp.
- [ ] `customer_profile_page.dart` — profile display and edit, image upload via
      `StorageService`, password change, sign out.

## 1.9 Integration test (~2 h)
- [ ] `integration_test/app_test.dart` — a boot smoke test asserting the app
      reaches a `Scaffold` with no lingering `CircularProgressIndicator`, plus
      a login test **skipped unless credentials are supplied** via
      `--dart-define=TEST_EMAIL=… --dart-define=TEST_PASSWORD=…`. Never commit
      credentials.

---

# PHASE 2 / 3 — your share (~12 h)

- [ ] **Commission fix, paired with Justin** — `foundation_and_integration.md`
      §6.1. You drive `OrderRepository`, the `FoodOrder`/`Stall` model changes,
      and the `VenueConfigRepository` move into `core/`. ~5 h paired.
- [ ] Fix the two pre-existing test defects in your own files: the contradictory
      comment at `models_test.dart:160`, and the bare `630` literal in
      `order_repository_test.dart`.
- [ ] **Merge integration** — run the merge order in §7.1, keep `main` green
      after each merge, arbitrate `main.dart` / `app_router.dart` /
      `constants.dart` conflicts.
- [ ] **Firebase Test Lab / Robo pass** — §7.3. Build the release APK, run per
      role if the crawler can sign in (otherwise one overall pass, stated as
      such), capture screenshots to `screenshots/testlab/`.
- [ ] **Report §4.2 write-up**, including both honest caveats: Robo is
      **Android-only** so it cannot cover Yong Jun's iOS `Info.plist` fix
      (that's covered by his opportunistic manual session, or not at all — say
      which), and Robo's crawler is shallow on Flutter because Flutter renders
      to a single canvas, so the real value is crash detection across
      device/API combinations rather than UI traversal.
- [ ] Report sections you own: architecture/MVVM write-up, Firestore schema +
      security rules, known limitations, your ~15 customer screenshots,
      customer wireframes and user manual.

---

## Deviations from the reference repo

1. **`FoodOrder` gains `commissionRate` and `vendorEarning`;
   `Stall.commissionRate` becomes nullable.** *Why:* the reference's admin
   commission setting is never read by pricing, and its refund path reverses at
   a hardcoded 0.10 regardless of the rate charged, so any non-10% stall drifts
   the vendor's wallet on every refund. Capturing the rate *and* the exact cents
   on the order makes a reversal provably equal to the original credit and lets
   an old order refund at the rate it was placed at. Making the stall rate
   nullable is what allows the venue-wide default to actually apply — with a
   non-null default on every stall it never could. Built into Phase 0 so
   nothing migrates mid-project.
2. **Service fee is read from `config/venue`** rather than the hardcoded
   constant, for the same reason.
3. **`VenueConfigRepository` moves from `features/admin/repository/` to
   `lib/core/repository/`.** All three roles read it now, so it is no longer
   admin-owned. Justin keeps the writes.
4. **`firestore.rules` is new work.** The reference repo has no rules file at
   all — this is authored from scratch, not ported.
5. **Seed data ships as `integration_test/seed_test.dart`** rather than a
   standalone script, because a plain Dart script cannot initialise Firebase
   without platform bindings or the Admin SDK.
6. **`_commissionFor()` is deliberately not reimplemented.** It is the source
   of the refund bug; `order.vendorEarning` replaces it.
