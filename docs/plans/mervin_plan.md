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

### Code for §0.1

The finished `pubspec.yaml`. Keep the comment group headers — they are what
make later appends land in different places and stay conflict-free:

**`pubspec.yaml`**

```yaml
name: stallhop
description: "StallHop — food-court ordering app (customer / vendor / admin)."
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.9.0
  firebase_auth: ^5.5.0
  cloud_firestore: ^5.6.0
  firebase_storage: ^12.4.0

  # Auth
  google_sign_in: ^6.2.2

  # State management
  provider: ^6.1.2

  # QR
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.0

  # Maps
  google_maps_flutter: ^2.10.0
  geolocator: ^13.0.2

  # Image
  image_picker: ^1.1.2
  cached_network_image: ^3.4.1

  # Notifications (in-app/local — no FCM; see Phase 8 decision)
  flutter_local_notifications: ^18.0.1

  # UI helpers
  intl: ^0.19.0
  flutter_rating_bar: ^4.0.1
  fl_chart: ^0.70.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.13
  fake_cloud_firestore: ^3.1.0

flutter:
  uses-material-design: true
```

`android/app/build.gradle.kts`. Two things matter here beyond the defaults:
the `google-services` plugin line (written by `flutterfire configure`), and
**core library desugaring**, which `flutter_local_notifications` requires and
which is easy to miss — without it the build fails with an obscure
`java.time` error rather than anything mentioning notifications:

**`android/app/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stallhop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time backport).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.stallhop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

> On `minSdk`: the plan calls for 23 because `firebase_auth` needs it.
> `flutter.minSdkVersion` already resolves to 24 on this Flutter version, so
> leaving it as the Flutter default satisfies the requirement. If you are on an
> older Flutter and the build complains, replace that line with `minSdk = 23`.

`android/app/src/main/AndroidManifest.xml` — the only permission you declare by
hand is `POST_NOTIFICATIONS`. **Be ready to explain why there is no camera or
photo-library permission here**: `mobile_scanner` and `image_picker` merge
their own declarations into the manifest at build time. iOS has no such
mechanism, which is exactly why Yong Jun's `Info.plist` fix exists:

**`android/app/src/main/AndroidManifest.xml`**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Runtime notification permission (Android 13+), requested via
         flutter_local_notifications on app start. -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <application
        android:label="StallHop"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

> **iOS Podfile.** `ios/Podfile` does not exist yet — it is generated by the
> first `pod install`, which can only run on macOS. There is nothing to commit
> from Windows. When a Mac is available, run `pod install` once from `ios/`,
> then set `platform :ios, '13.0'` at the top of the generated Podfile and
> commit it. `GoogleService-Info.plist` in `ios/Runner/` **is** committable from
> here and `flutterfire configure` should already have written it.

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

**`lib/core/utils/constants.dart`**

```dart
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
```

- [ ] **`lib/core/utils/app_exceptions.dart`**
      `AppException implements Exception` carrying a user-facing `message` and
      overriding `toString()`. Two subclasses: `InsufficientBalanceException`
      and `NotFoundException`, each with a default message via
      `super.message = '...'`. These exist so the wallet transaction can fail
      with a message the UI can show directly instead of leaking a Firestore
      error string.

**`lib/core/utils/app_exceptions.dart`**

```dart
/// Base class for domain errors that carry a user-facing message.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a wallet does not have enough balance to cover a charge.
class InsufficientBalanceException extends AppException {
  const InsufficientBalanceException([
    super.message = 'Insufficient wallet balance',
  ]);
}

/// Thrown when an expected document is missing during a transaction.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Record not found']);
}
```

- [ ] **`lib/core/utils/formatters.dart`**
      Top-level functions, not a class. `centsToRM(int) → 'RM 7.50'` handling
      negatives via a sign prefix; `rmToCents(String) → int?` returning null on
      unparseable input; three `DateFormat` singletons behind `formatDate`,
      `formatTime`, `formatDateTime` (always `.toLocal()` first); and
      `timeAgo(DateTime)` returning "just now" / "N min ago" / "N h ago" /
      "N d ago" / a date beyond a week.

**`lib/core/utils/formatters.dart`**

```dart
import 'package:intl/intl.dart';

/// Converts an integer amount in cents to a display string, e.g.
/// `750` -> `"RM 7.50"`. Handles negative and large values.
String centsToRM(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign'
      'RM ${(abs / 100).toStringAsFixed(2)}';
}

/// Parses a Ringgit string (e.g. "7.50") into integer cents. Returns null
/// when the value cannot be parsed.
int? rmToCents(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) return null;
  return (parsed * 100).round();
}

final DateFormat _dateFormat = DateFormat('d MMM yyyy');
final DateFormat _timeFormat = DateFormat('h:mm a');
final DateFormat _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

String formatDate(DateTime dt) => _dateFormat.format(dt.toLocal());

String formatTime(DateTime dt) => _timeFormat.format(dt.toLocal());

String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

/// Relative time like "just now", "5 min ago", "2 h ago", else a date.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(dt);
}
```

- [ ] **`lib/core/utils/validators.dart`**
      `Validators._()` holder of statics matching Flutter's
      `FormFieldValidator` contract — **return `null` when valid**, an error
      string when not. `email` (regex), `password` (min 6),
      `confirmPassword(value, original)`, `phone` (Malaysian mobile, strips
      spaces/dashes, accepts `0…`/`+60…`/`60…`), `required(value, [fieldName])`,
      and `price` (parses Ringgit, rejects ≤ 0).

**`lib/core/utils/validators.dart`**

```dart
/// Form field validators. Each returns `null` when valid, or an error
/// message string when invalid — matching the [FormFieldValidator] contract.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$',
  );

  // Malaysian mobile numbers, with or without country code, e.g.
  // 0123456789, +60123456789, 60123456789.
  static final RegExp _phoneRegExp = RegExp(r'^(\+?6?0)[0-9]{8,10}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.replaceAll(RegExp(r'[\s-]'), '').trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (!_phoneRegExp.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Validates a price entered in Ringgit (e.g. "7.50"). Returns null when
  /// the value parses to a positive amount.
  static String? price(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Price is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid price';
    if (parsed <= 0) return 'Price must be greater than zero';
    return null;
  }
}
```

- [ ] **`lib/core/theme/app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`**
      Orange-led palette; `AppTheme.lightTheme` assembling a `ThemeData` from
      the two. Keep it small — theming is not where the marks are.

**`lib/core/theme/app_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// StallHop brand palette.
class AppColors {
  AppColors._();

  static const orange = Color(0xFFF4732A); // Primary
  static const navy = Color(0xFF1F2933); // Text / structure
  static const teal = Color(0xFF2BB673); // Success / Ready
  static const offWhite = Color(0xFFF7F5F2); // Background
  static const warmGrey = Color(0xFF9AA0A6); // Secondary text
  static const white = Colors.white;
  static const error = Color(0xFFE12D39);

  // Helpful tints derived from the palette.
  static const orangeLight = Color(0xFFFFF1E8);
  static const tealLight = Color(0xFFE8F8F0);
  static const divider = Color(0xFFE4E7EB);
}
```

**`lib/core/theme/app_text_styles.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for StallHop.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Roboto';

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.navy,
    height: 1.5,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.warmGrey,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.warmGrey,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static const TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.orange,
  );
}
```

**`lib/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Central [ThemeData] for StallHop, built from [AppColors] and
/// [AppTextStyles].
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      secondary: AppColors.teal,
      error: AppColors.error,
      surface: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.offWhite,
      fontFamily: AppTextStyles.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: IconThemeData(color: AppColors.navy),
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        titleLarge: AppTextStyles.h3,
        titleMedium: AppTextStyles.title,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySecondary,
        labelSmall: AppTextStyles.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.orange),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.bodySecondary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.orangeLight,
        labelStyle: AppTextStyles.body,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.warmGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
```

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

**`lib/core/services/firestore_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

typedef JsonMap = Map<String, dynamic>;
typedef QueryBuilder = Query<JsonMap> Function(Query<JsonMap> query);

/// Generic Firestore helper. Every document in StallHop embeds its own id
/// field (uid, stallId, orderId, …), so returning raw data maps is enough to
/// reconstruct models — callers don't need the [DocumentSnapshot] id.
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

> The injectable `FirebaseFirestore? db` on the constructor is not decoration —
> it is what lets every repository in the app be tested against
> `FakeFirebaseFirestore`. Every repository your teammates write copies this
> same constructor shape for exactly that reason.

- [ ] **`lib/core/services/auth_service.dart`**
      Injectable `FirebaseAuth` + `GoogleSignIn`. Exposes `currentUser`,
      `authStateChanges`, `signUp`, `signIn`, `signInWithGoogle()` (returns
      `null` when the user cancels the picker — the caller must handle that),
      `sendPasswordResetEmail`, `updatePassword`, `signOut` (Google *then*
      Firebase). Holds **no app state**; `AuthViewModel` owns that.

**`lib/core/services/auth_service.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around [FirebaseAuth] (plus Google Sign-In). Holds no app
/// state — the auth view model owns that.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Returns the [UserCredential] on success, or `null` if the user cancelled
  /// the Google account picker.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
```

- [ ] **`lib/core/services/storage_service.dart`**
      `uploadImage(File, String path) → Future<String>` download URL, and
      `deleteImage(String url)` which resolves via `refFromURL` and swallows
      only `object-not-found`, rethrowing everything else. Yong Jun depends on
      this for menu photos — get it right before he starts.

**`lib/core/services/storage_service.dart`**

```dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Wraps [FirebaseStorage] for image upload/delete.
class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads [file] to [path] (e.g. `stalls/{id}/menu/{itemId}.jpg`) and
  /// returns the public download URL.
  Future<String> uploadImage(File file, String path) async {
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Deletes the object referenced by a download [url]. Silently ignores a
  /// missing object.
  Future<void> deleteImage(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
```

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

**`lib/core/services/notification_service.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over [FlutterLocalNotificationsPlugin] for showing local
/// (in-app) notifications.
///
/// StallHop deliberately has no server-side push (no Cloud Functions / FCM):
/// notifications are generated on-device from Firestore listeners, so they
/// arrive while the app is running. See [NotificationCoordinator] for the
/// listeners that decide *when* to notify.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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

  /// Shows a notification. [id] should be stable per subject (e.g. derived
  /// from the order id) so repeated updates replace rather than stack.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'stallhop_default',
        'StallHop notifications',
        channelDescription: 'Order updates and venue announcements',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}
```

- [ ] **`lib/core/routing/app_router.dart`**
      One function: `Widget getHomeForRole(String role)` switching on the three
      role constants into `CustomerHomePage` / `VendorDashboardPage` /
      `AdminDashboardPage`, defaulting to `LoginPage`. Three lines of real
      logic. It will not compile until all three homes exist — stub the vendor
      and admin homes with a placeholder `Scaffold` so Phase 0 builds, and let
      the teammates replace them.

**`lib/core/routing/app_router.dart`**

```dart
import 'package:flutter/material.dart';

import '../../features/admin/view/admin_dashboard_page.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/customer/view/customer_home_page.dart';
import '../../features/vendor/view/vendor_dashboard_page.dart';
import '../utils/constants.dart';

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

> This is the finished version, which imports the three real home pages. During
> Phase 0 those do not exist yet, so temporarily point the vendor and admin
> branches at a placeholder and swap the imports back in once your teammates
> land their screens:
>
> ```dart
> // TEMPORARY Phase 0 stub — delete once the real pages exist.
> class _StubHome extends StatelessWidget {
>   final String role;
>   const _StubHome(this.role);
>
>   @override
>   Widget build(BuildContext context) => Scaffold(
>         appBar: AppBar(title: Text('$role home')),
>         body: Center(child: Text('$role home coming in Phase 1')),
>       );
> }
> ```

## 0.3 Models (~4 h)

Every model: `final` fields, a named-parameter constructor, `fromJson`,
`toJson`, `copyWith`. `Timestamp` ⇄ `DateTime` conversion lives **here and
nowhere else**. Defensive reads throughout (`json['x'] ?? default`) so a
document written by an older build never crashes the app.

- [ ] **`user.dart` → `AppUser`** (named to avoid clashing with Firebase's
      `User`). `uid, name, email, phone, role, profileImageUrl?,
      walletBalance (int cents, default 0), fcmToken?, createdAt, updatedAt`.

**`lib/models/user.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Application user. Named [AppUser] to avoid clashing with Firebase's
/// own `User` type.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // "customer" | "vendor" | "admin"
  final String? profileImageUrl;
  final int walletBalance; // in cents
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.walletBalance = 0,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
      profileImageUrl: json['profileImageUrl'],
      walletBalance: (json['walletBalance'] ?? 0) as int,
      fcmToken: json['fcmToken'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'profileImageUrl': profileImageUrl,
        'walletBalance': walletBalance,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    int? walletBalance,
    String? fcmToken,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **`stall.dart` → `Stall`.** `stallId, vendorUid, name, description,
      cuisine, imageUrl?, status (default 'pending'), prepTimeMinutes (15),
      averageRating (double), totalReviews, latitude?, longitude?, createdAt,
      updatedAt`, plus `bool get isOpen => status == 'open'`.
      ⚠️ **`commissionRate` is `double?`, nullable** — `null` means "inherit the
      venue default". This is the decided deviation from the reference (see
      `foundation_and_integration.md` §6.1); build it nullable from the start
      so nothing has to migrate later.

**`lib/models/stall.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A food stall owned by a vendor.
///
/// `status` is one of: `pending`, `open`, `closed`, `suspended`, `rejected`.
class Stall {
  final String stallId;
  final String vendorUid;
  final String name;
  final String description;
  final String cuisine;
  final String? imageUrl;
  final String status;
  final int prepTimeMinutes;
  final double averageRating;
  final int totalReviews;

  /// Per-stall commission override. `null` means "inherit the venue-wide
  /// default" (`config/venue.defaultCommission`), which is what makes the
  /// admin's commission setting actually reach pricing. Only an admin may
  /// write this field (enforced in `firestore.rules`).
  final double? commissionRate;

  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  Stall({
    required this.stallId,
    required this.vendorUid,
    required this.name,
    this.description = '',
    this.cuisine = '',
    this.imageUrl,
    this.status = 'pending',
    this.prepTimeMinutes = 15,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.commissionRate,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';

  factory Stall.fromJson(Map<String, dynamic> json) {
    return Stall(
      stallId: json['stallId'] ?? '',
      vendorUid: json['vendorUid'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      cuisine: json['cuisine'] ?? '',
      imageUrl: json['imageUrl'],
      status: json['status'] ?? 'pending',
      prepTimeMinutes: (json['prepTimeMinutes'] ?? 15) as int,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalReviews: (json['totalReviews'] ?? 0) as int,
      // Deliberately NOT defaulted to 0.10 — a missing/null value means
      // "inherit the venue default", so it must survive the round trip.
      commissionRate: (json['commissionRate'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stallId': stallId,
        'vendorUid': vendorUid,
        'name': name,
        'description': description,
        'cuisine': cuisine,
        'imageUrl': imageUrl,
        'status': status,
        'prepTimeMinutes': prepTimeMinutes,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'commissionRate': commissionRate,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Note [clearCommissionRate]: because `null` is a meaningful value here,
  /// `copyWith(commissionRate: null)` cannot mean "clear it" — that is
  /// indistinguishable from "don't change it". Pass `clearCommissionRate: true`
  /// to reset a stall back to inheriting the venue default.
  Stall copyWith({
    String? name,
    String? description,
    String? cuisine,
    String? imageUrl,
    String? status,
    int? prepTimeMinutes,
    double? averageRating,
    int? totalReviews,
    double? commissionRate,
    bool clearCommissionRate = false,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return Stall(
      stallId: stallId,
      vendorUid: vendorUid,
      name: name ?? this.name,
      description: description ?? this.description,
      cuisine: cuisine ?? this.cuisine,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      commissionRate:
          clearCommissionRate ? null : (commissionRate ?? this.commissionRate),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **`menu_item.dart` → `MenuItem`.** `itemId, stallId, name, description,
      price (int cents), category, imageUrl?, available (default true),
      customizations, addOns, createdAt, updatedAt`. The last two are
      `List<Map<String, dynamic>>` — customizations are single-select groups
      `{"name": "Size", "options": ["S","L"]}`, add-ons are
      `{"name": "Extra egg", "price": 150}`. Needs a `static _mapList(dynamic)`
      helper because Firestore returns `List<dynamic>` and a bare cast throws.

**`lib/models/menu_item.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A menu item belonging to a stall, stored at
/// `stalls/{stallId}/menuItems/{itemId}`.
///
/// `customizations` are single-select groups, each shaped like:
/// `{"name": "Size", "options": ["Small", "Large"]}`.
///
/// `addOns` are optional extras, each shaped like:
/// `{"name": "Extra cheese", "price": 100}` (price in cents).
class MenuItem {
  final String itemId;
  final String stallId;
  final String name;
  final String description;
  final int price; // in cents
  final String category;
  final String? imageUrl;
  final bool available;
  final List<Map<String, dynamic>> customizations;
  final List<Map<String, dynamic>> addOns;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItem({
    required this.itemId,
    required this.stallId,
    required this.name,
    this.description = '',
    required this.price,
    this.category = '',
    this.imageUrl,
    this.available = true,
    this.customizations = const [],
    this.addOns = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value == null) return [];
    return (value as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      itemId: json['itemId'] ?? '',
      stallId: json['stallId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0) as int,
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'],
      available: json['available'] ?? true,
      customizations: _mapList(json['customizations']),
      addOns: _mapList(json['addOns']),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'stallId': stallId,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'imageUrl': imageUrl,
        'available': available,
        'customizations': customizations,
        'addOns': addOns,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  MenuItem copyWith({
    String? name,
    String? description,
    int? price,
    String? category,
    String? imageUrl,
    bool? available,
    List<Map<String, dynamic>>? customizations,
    List<Map<String, dynamic>>? addOns,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      itemId: itemId,
      stallId: stallId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      available: available ?? this.available,
      customizations: customizations ?? this.customizations,
      addOns: addOns ?? this.addOns,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **`order_item.dart` → `OrderItem`.** *Embedded in the order, not a
      collection.* `itemId, name, unitPrice (base, excludes add-ons), quantity,
      customizations (Map), addOns (List<Map>), specialInstructions`. Two
      computed getters: `addOnsTotal` (fold of add-on prices) and
      `subtotal => (unitPrice + addOnsTotal) * quantity`. `toJson` writes
      `subtotal` as a stored field for readability in the console even though
      `fromJson` recomputes it.

**`lib/models/order_item.dart`**

```dart
/// A single line in an order. Embedded inside [FoodOrder] — not a separate
/// Firestore collection.
class OrderItem {
  final String itemId;
  final String name;

  /// Base price of the menu item, in cents (excludes add-ons).
  final int unitPrice;
  final int quantity;

  /// Selected single-choice customizations, e.g. `{"Size": "Large"}`.
  final Map<String, dynamic> customizations;

  /// Selected add-ons, each `{"name": String, "price": int(cents)}`.
  final List<Map<String, dynamic>> addOns;

  final String specialInstructions;

  OrderItem({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.customizations = const {},
    this.addOns = const [],
    this.specialInstructions = '',
  });

  /// Sum of add-on prices for a single unit, in cents.
  int get addOnsTotal =>
      addOns.fold(0, (sum, a) => sum + ((a['price'] ?? 0) as num).toInt());

  /// Total for this line: (base + add-ons) × quantity, in cents.
  int get subtotal => (unitPrice + addOnsTotal) * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      unitPrice: (json['unitPrice'] ?? 0) as int,
      quantity: (json['quantity'] ?? 1) as int,
      customizations: json['customizations'] == null
          ? {}
          : Map<String, dynamic>.from(json['customizations']),
      addOns: json['addOns'] == null
          ? []
          : (json['addOns'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
      specialInstructions: json['specialInstructions'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'customizations': customizations,
        'addOns': addOns,
        'specialInstructions': specialInstructions,
        'subtotal': subtotal,
      };

  OrderItem copyWith({int? quantity}) {
    return OrderItem(
      itemId: itemId,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      customizations: customizations,
      addOns: addOns,
      specialInstructions: specialInstructions,
    );
  }
}
```

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

**`lib/models/order.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_item.dart';

/// A customer order for a single stall. Named [FoodOrder] to avoid clashing
/// with Firestore's `Order` concepts and Dart conventions.
///
/// `status` is one of: `preparing`, `ready`, `collected`, `cancelled`.
class FoodOrder {
  final String orderId;
  final String customerUid;
  final String customerName;
  final String stallId;
  final String vendorUid;
  final String stallName;
  final List<OrderItem> items;
  final int subtotal; // cents
  final int serviceFee; // cents
  final int total; // cents
  final String status;
  final String pickupCode;
  final bool refunded;

  /// Admin dismissed the dispute for this cancelled order without refunding.
  /// A cancelled order is an *open dispute* while neither [refunded] nor
  /// [dismissed] is true.
  final bool dismissed;

  /// The commission rate actually applied when this order was placed
  /// (`stall.commissionRate ?? venueConfig.defaultCommission`). Stored so a
  /// later refund reverses at the rate that was charged, not today's rate.
  final double commissionRate;

  /// The exact amount credited to the vendor at place time, in cents.
  /// A refund debits *this* number — never a recomputed one — which is what
  /// guarantees a reversal exactly equals the original credit.
  final int vendorEarning;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readyAt;
  final DateTime? collectedAt;
  final DateTime? cancelledAt;

  FoodOrder({
    required this.orderId,
    required this.customerUid,
    required this.customerName,
    required this.stallId,
    required this.vendorUid,
    required this.stallName,
    this.items = const [],
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    this.status = 'preparing',
    required this.pickupCode,
    this.refunded = false,
    this.dismissed = false,
    this.commissionRate = 0.0,
    this.vendorEarning = 0,
    required this.createdAt,
    required this.updatedAt,
    this.readyAt,
    this.collectedAt,
    this.cancelledAt,
  });

  static DateTime? _ts(dynamic value) =>
      value == null ? null : (value as Timestamp).toDate();

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    return FoodOrder(
      orderId: json['orderId'] ?? '',
      customerUid: json['customerUid'] ?? '',
      customerName: json['customerName'] ?? '',
      stallId: json['stallId'] ?? '',
      vendorUid: json['vendorUid'] ?? '',
      stallName: json['stallName'] ?? '',
      items: json['items'] == null
          ? []
          : (json['items'] as List)
              .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      subtotal: (json['subtotal'] ?? 0) as int,
      serviceFee: (json['serviceFee'] ?? 0) as int,
      total: (json['total'] ?? 0) as int,
      status: json['status'] ?? 'preparing',
      pickupCode: json['pickupCode'] ?? '',
      refunded: json['refunded'] ?? false,
      dismissed: json['dismissed'] ?? false,
      // Defensive: orders written before these fields existed read as 0,
      // which is why both have defaults rather than being `required`.
      commissionRate: (json['commissionRate'] ?? 0).toDouble(),
      vendorEarning: (json['vendorEarning'] ?? 0) as int,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      readyAt: _ts(json['readyAt']),
      collectedAt: _ts(json['collectedAt']),
      cancelledAt: _ts(json['cancelledAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'customerUid': customerUid,
        'customerName': customerName,
        'stallId': stallId,
        'vendorUid': vendorUid,
        'stallName': stallName,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'serviceFee': serviceFee,
        'total': total,
        'status': status,
        'pickupCode': pickupCode,
        'refunded': refunded,
        'dismissed': dismissed,
        'commissionRate': commissionRate,
        'vendorEarning': vendorEarning,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'readyAt': readyAt == null ? null : Timestamp.fromDate(readyAt!),
        'collectedAt':
            collectedAt == null ? null : Timestamp.fromDate(collectedAt!),
        'cancelledAt':
            cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
      };

  FoodOrder copyWith({
    String? status,
    bool? refunded,
    bool? dismissed,
    DateTime? updatedAt,
    DateTime? readyAt,
    DateTime? collectedAt,
    DateTime? cancelledAt,
  }) {
    return FoodOrder(
      orderId: orderId,
      customerUid: customerUid,
      customerName: customerName,
      stallId: stallId,
      vendorUid: vendorUid,
      stallName: stallName,
      items: items,
      subtotal: subtotal,
      serviceFee: serviceFee,
      total: total,
      status: status ?? this.status,
      pickupCode: pickupCode,
      refunded: refunded ?? this.refunded,
      dismissed: dismissed ?? this.dismissed,
      commissionRate: commissionRate,
      vendorEarning: vendorEarning,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readyAt: readyAt ?? this.readyAt,
      collectedAt: collectedAt ?? this.collectedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
```

- [ ] **`transaction.dart` → `WalletTransaction`** (named to avoid Firestore's
      `Transaction`). `txnId, userId, type, amount, balanceBefore,
      balanceAfter, description, relatedOrderId?, createdAt`. `amount` is
      always **positive**; the `type` conveys direction. `balanceBefore`/`After`
      make the ledger self-auditing.

**`lib/models/transaction.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A wallet ledger entry. Named [WalletTransaction] to avoid clashing with
/// Firestore's `Transaction` type.
///
/// `type` is one of: `topup`, `payment`, `refund`, `earning`, `withdrawal`.
/// Amounts and balances are in cents.
class WalletTransaction {
  final String txnId;
  final String userId;
  final String type;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final String description;
  final String? relatedOrderId;
  final DateTime createdAt;

  WalletTransaction({
    required this.txnId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description = '',
    this.relatedOrderId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      txnId: json['txnId'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0) as int,
      balanceBefore: (json['balanceBefore'] ?? 0) as int,
      balanceAfter: (json['balanceAfter'] ?? 0) as int,
      description: json['description'] ?? '',
      relatedOrderId: json['relatedOrderId'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'txnId': txnId,
        'userId': userId,
        'type': type,
        'amount': amount,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'description': description,
        'relatedOrderId': relatedOrderId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WalletTransaction copyWith({String? txnId}) {
    return WalletTransaction(
      txnId: txnId ?? this.txnId,
      userId: userId,
      type: type,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: description,
      relatedOrderId: relatedOrderId,
      createdAt: createdAt,
    );
  }
}
```

- [ ] **`review.dart` → `Review`.** `reviewId, orderId, stallId, customerUid,
      customerName, rating (1–5 int), comment, createdAt`.

**`lib/models/review.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's review of a stall, tied to a collected order.
/// `rating` is an integer from 1 to 5.
class Review {
  final String reviewId;
  final String orderId;
  final String stallId;
  final String customerUid;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.reviewId,
    required this.orderId,
    required this.stallId,
    required this.customerUid,
    required this.customerName,
    required this.rating,
    this.comment = '',
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewId: json['reviewId'] ?? '',
      orderId: json['orderId'] ?? '',
      stallId: json['stallId'] ?? '',
      customerUid: json['customerUid'] ?? '',
      customerName: json['customerName'] ?? '',
      rating: (json['rating'] ?? 0) as int,
      comment: json['comment'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'reviewId': reviewId,
        'orderId': orderId,
        'stallId': stallId,
        'customerUid': customerUid,
        'customerName': customerName,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Review copyWith({String? reviewId}) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      orderId: orderId,
      stallId: stallId,
      customerUid: customerUid,
      customerName: customerName,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }
}
```

- [ ] **`announcement.dart` → `Announcement`.** `announcementId, title,
      message, createdBy, createdAt`.

**`lib/models/announcement.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A venue-wide announcement created by an admin.
class Announcement {
  final String announcementId;
  final String title;
  final String message;
  final String createdBy;
  final DateTime createdAt;

  Announcement({
    required this.announcementId,
    required this.title,
    required this.message,
    this.createdBy = '',
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['announcementId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'announcementId': announcementId,
        'title': title,
        'message': message,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Announcement copyWith({String? announcementId}) {
    return Announcement(
      announcementId: announcementId ?? this.announcementId,
      title: title,
      message: message,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
```

- [ ] **`venue_config.dart` → `VenueConfig`.** Singleton at `config/venue`.
      `venueName, defaultCommission, serviceFee, pickupCodePrefix,
      pickupCodeCounter, latitude?, longitude?, updatedAt`. Note the
      code/counter reset daily — the mechanism lives in `placeOrder`.

**`lib/models/venue_config.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton configuration document stored at `config/venue`.
///
/// The pickup code is built from [pickupCodePrefix] + a zero-padded
/// [pickupCodeCounter]; the counter increments atomically per order and the
/// prefix/counter reset daily.
class VenueConfig {
  final String venueName;
  final double defaultCommission;
  final int serviceFee; // cents
  final String pickupCodePrefix;
  final int pickupCodeCounter;
  final double? latitude;
  final double? longitude;
  final DateTime updatedAt;

  VenueConfig({
    this.venueName = 'StallHop',
    this.defaultCommission = 0.10,
    this.serviceFee = 50,
    this.pickupCodePrefix = 'A',
    this.pickupCodeCounter = 0,
    this.latitude,
    this.longitude,
    required this.updatedAt,
  });

  factory VenueConfig.fromJson(Map<String, dynamic> json) {
    return VenueConfig(
      venueName: json['venueName'] ?? 'StallHop',
      defaultCommission: (json['defaultCommission'] ?? 0.10).toDouble(),
      serviceFee: (json['serviceFee'] ?? 50) as int,
      pickupCodePrefix: json['pickupCodePrefix'] ?? 'A',
      pickupCodeCounter: (json['pickupCodeCounter'] ?? 0) as int,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'venueName': venueName,
        'defaultCommission': defaultCommission,
        'serviceFee': serviceFee,
        'pickupCodePrefix': pickupCodePrefix,
        'pickupCodeCounter': pickupCodeCounter,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  VenueConfig copyWith({
    String? venueName,
    double? defaultCommission,
    int? serviceFee,
    String? pickupCodePrefix,
    int? pickupCodeCounter,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return VenueConfig(
      venueName: venueName ?? this.venueName,
      defaultCommission: defaultCommission ?? this.defaultCommission,
      serviceFee: serviceFee ?? this.serviceFee,
      pickupCodePrefix: pickupCodePrefix ?? this.pickupCodePrefix,
      pickupCodeCounter: pickupCodeCounter ?? this.pickupCodeCounter,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Test as you go:** `test/models/models_test.dart` — round-trip each
      model through `toJson → fromJson → toJson` and compare the two maps as
      strings (deterministic deep compare that also handles `Timestamp`). Plus
      an explicit `OrderItem.subtotal` case and a Timestamp-fidelity case.

### Test code for §0.3

The whole file is one helper plus one near-identical `test()` per model, so
only the helper and the cases that aren't boilerplate are shown here.

**`test/models/models_test.dart` — the helper every round-trip case uses**

```dart
/// Round-trips a model through toJson -> fromJson and asserts the resulting
/// JSON maps are identical. Comparing the serialized maps (as strings) gives a
/// deterministic deep comparison that also handles Timestamps.
void expectRoundTrip(
  Map<String, dynamic> original,
  Map<String, dynamic> roundTripped,
) {
  expect(roundTripped.toString(), original.toString());
}
```

Then one case per model in that shape:

```dart
test('AppUser round-trips', () {
  final user = AppUser(/* ...every field populated... */);
  expectRoundTrip(user.toJson(), AppUser.fromJson(user.toJson()).toJson());
});
```

⚠️ **The cases that actually earn their keep** are the nullable-commission
ones — they are the only thing standing between you and a silent regression
back to the pre-fix design, because `commissionRate: 0.12` compiles fine
against *both* `double` and `double?`.

```dart
test('Stall round-trips a null commissionRate as null', () {
  final stall = Stall(
    stallId: 's2',
    vendorUid: 'v1',
    name: 'Inherits The Default',
    createdAt: now,
    updatedAt: later,
  );
  expect(stall.commissionRate, isNull);
  final back = Stall.fromJson(stall.toJson());
  expect(back.commissionRate, isNull,
      reason: 'null means "inherit the venue default" and must not be '
          'coerced to a concrete rate on the way back');
  expectRoundTrip(stall.toJson(), back.toJson());
});

test('Stall.fromJson treats a missing commissionRate as inherit', () {
  final json = Stall(
    stallId: 's3',
    vendorUid: 'v1',
    name: 'No Rate Key',
    createdAt: now,
    updatedAt: later,
  ).toJson()
    ..remove('commissionRate');
  expect(Stall.fromJson(json).commissionRate, isNull);
});

test('Stall.copyWith preserves an override but clears it on request', () {
  final overridden = Stall(
    stallId: 's4',
    vendorUid: 'v1',
    name: 'Negotiated Rate',
    commissionRate: 0.05,
    createdAt: now,
    updatedAt: later,
  );

  expect(overridden.copyWith(name: 'Renamed').commissionRate, 0.05);
  expect(overridden.copyWith(commissionRate: null).commissionRate, 0.05,
      reason: 'passing null cannot mean "clear" — it is indistinguishable '
          'from "leave unchanged"');
  expect(overridden.copyWith(commissionRate: 0.20).commissionRate, 0.20);
  expect(overridden.copyWith(clearCommissionRate: true).commissionRate, isNull);
});

test('FoodOrder carries the applied rate and earning through copyWith', () {
  final order = FoodOrder(
    /* ...subtotal: 1000, serviceFee: 50, total: 1050... */
    commissionRate: 0.15,
    vendorEarning: 850,
  );

  final back = FoodOrder.fromJson(order.toJson());
  expect(back.commissionRate, 0.15);
  expect(back.vendorEarning, 850);

  // Both must survive a status transition, because cancelAndRefund reverses
  // the stored earning long after placement.
  final cancelled = order.copyWith(status: 'cancelled', refunded: true);
  expect(cancelled.commissionRate, 0.15);
  expect(cancelled.vendorEarning, 850);
});
```

Plus the two non-round-trip cases the bullet calls for — `OrderItem.subtotal`
(`expect(orderItem.subtotal, 1900)` for `(800 + 150) * 2`) and a Timestamp
fidelity check (`expect((user.toJson()['createdAt'] as Timestamp).toDate(), now)`).

## 0.4 Shared widgets (~3 h)

- [ ] `widgets/loading_indicator.dart` — centred spinner + optional message.

**`lib/widgets/loading_indicator.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Centered progress spinner used for full-screen async states.
class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.orange),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
```

- [ ] `widgets/empty_state.dart` — icon + title + subtitle + optional action.
      Used on nearly every list screen by all three of you.

**`lib/widgets/empty_state.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Friendly placeholder for empty lists ("No orders yet", etc.).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Full layout needs ~200px of height; fall back to a smaller icon and
        // tighter spacing when hosted in short containers (e.g. fixed-height
        // dashboard cards) so the Column never overflows.
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 200;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: compact ? 32 : 64, color: AppColors.warmGrey),
                SizedBox(height: compact ? 8 : 16),
                Text(title,
                    style: compact ? AppTextStyles.title : AppTextStyles.h3,
                    textAlign: TextAlign.center),
                if (subtitle != null && !compact) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[
                  SizedBox(height: compact ? 12 : 20),
                  action!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] `widgets/stall_card.dart` — image, name, cuisine, rating, prep time,
      open/closed badge, `onTap`.

**`lib/widgets/stall_card.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/constants.dart';
import '../models/stall.dart';

class StallCard extends StatelessWidget {
  final Stall stall;
  final VoidCallback? onTap;

  const StallCard({super.key, required this.stall, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = stall.status == AppConstants.stallOpen;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _StallImage(url: stall.imageUrl),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _StatusBadge(isOpen: isOpen),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stall.name,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stall.cuisine.isEmpty ? 'Food' : stall.cuisine,
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: stall.averageRating,
                        itemCount: 5,
                        itemSize: 16,
                        unratedColor: AppColors.divider,
                        itemBuilder: (_, _) => const Icon(
                          Icons.star,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stall.totalReviews > 0
                            ? '${stall.averageRating.toStringAsFixed(1)} '
                                '(${stall.totalReviews})'
                            : 'New',
                        style: AppTextStyles.caption,
                      ),
                      const Spacer(),
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.warmGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${stall.prepTimeMinutes} min',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StallImage extends StatelessWidget {
  final String? url;
  const _StallImage({this.url});

  @override
  Widget build(BuildContext context) {
    const height = 120.0;
    if (url == null || url!.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: AppColors.offWhite,
        child: const Icon(Icons.storefront,
            size: 48, color: AppColors.warmGrey),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: height,
        color: AppColors.offWhite,
      ),
      errorWidget: (_, _, _) => Container(
        height: height,
        color: AppColors.offWhite,
        child: const Icon(Icons.broken_image, color: AppColors.warmGrey),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.teal : AppColors.warmGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

- [ ] `widgets/wallet_balance_card.dart` — formatted balance + top-up action.

**`lib/widgets/wallet_balance_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';

/// Gradient card showing the current wallet balance in cents.
class WalletBalanceCard extends StatelessWidget {
  final int balanceCents;
  final String label;

  const WalletBalanceCard({
    super.key,
    required this.balanceCents,
    this.label = 'Wallet balance',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            centsToRM(balanceCents),
            style: AppTextStyles.h1.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
```

- [ ] `widgets/order_status_stepper.dart` — horizontal preparing → ready →
      collected stepper driven by a status string.

**`lib/widgets/order_status_stepper.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/constants.dart';

/// Horizontal Preparing → Ready → Collected stepper. A cancelled order shows a
/// single cancelled state instead.
class OrderStatusStepper extends StatelessWidget {
  final String status;
  const OrderStatusStepper({super.key, required this.status});

  static const _steps = [
    (AppConstants.orderPreparing, 'Preparing', Icons.soup_kitchen),
    (AppConstants.orderReady, 'Ready', Icons.check_circle_outline),
    (AppConstants.orderCollected, 'Collected', Icons.shopping_bag),
  ];

  int get _currentIndex {
    final idx = _steps.indexWhere((s) => s.$1 == status);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    if (status == AppConstants.orderCancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: const [
            Icon(Icons.cancel, color: AppColors.error),
            SizedBox(width: 8),
            Text('Order cancelled'),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _StepNode(
            label: _steps[i].$2,
            icon: _steps[i].$3,
            done: i <= _currentIndex,
            active: i == _currentIndex,
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                color: i < _currentIndex
                    ? AppColors.teal
                    : AppColors.divider,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  const _StepNode({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.teal : AppColors.warmGrey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: done ? AppColors.teal : AppColors.divider,
          child: Icon(
            icon,
            color: done ? AppColors.white : AppColors.warmGrey,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
```

- [ ] `widgets/pickup_code_display.dart` — large code text + `qr_flutter`
      `QrImageView` of the code.

**`lib/widgets/pickup_code_display.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Shows the order's QR code and human-readable pickup code, for the vendor to
/// scan at collection.
class PickupCodeDisplay extends StatelessWidget {
  final String pickupCode;
  final double size;

  const PickupCodeDisplay({
    super.key,
    required this.pickupCode,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: QrImageView(
            data: pickupCode,
            size: size,
            backgroundColor: AppColors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.navy,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Pickup code', style: AppTextStyles.caption),
        Text(
          pickupCode,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.orange,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
```

- [ ] `widgets/qr_scanner_widget.dart` → **`QrScannerPage`.** Full-screen
      `MobileScanner`, pops with the first decoded `rawValue` or `null` if
      dismissed. Guard with a `_handled` bool — `onDetect` fires repeatedly and
      without the guard you `pop` several times and blow up the navigator.
      Torch + camera-switch actions; dispose the controller.
      *Yong Jun consumes this — it must work before he starts.*

**`lib/widgets/qr_scanner_widget.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/app_colors.dart';

/// Full-screen QR scanner. Pops with the first decoded string value, or `null`
/// if dismissed.
class QrScannerPage extends StatefulWidget {
  final String title;
  const QrScannerPage({super.key, this.title = 'Scan pickup code'});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Simple viewfinder overlay.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.orange, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] Widget tests for the three most reusable: `stall_card_test.dart`,
      `wallet_balance_card_test.dart`, `order_status_stepper_test.dart`.

### Test code for §0.4

All three follow the same shape: a top-level `pump…` helper that wraps the
widget in `MaterialApp(home: Scaffold(body: …))`, then one `testWidgets` per
visual state. Only the helpers and the non-obvious assertions are shown.

**`test/widgets/stall_card_test.dart`** — a `stall({...})` factory with
defaults keeps each case to the one field it varies:

```dart
Stall stall({
  String status = 'open',
  String cuisine = 'Malay',
  double rating = 4.5,
  int reviews = 12,
}) { /* ...returns a Stall with those overrides... */ }

Future<void> pumpCard(WidgetTester tester, Stall s) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: StallCard(stall: s))),
  );
}
```

Cases: renders name/cuisine/`'4.5 (12)'`/`'15 min'`; `Open` vs `Closed` badge;
`'New'` instead of a rating when `reviews == 0`; falls back to `'Food'` when
cuisine is empty; `onTap` fires.

**`test/widgets/wallet_balance_card_test.dart`** — assert the *formatted*
string, never the raw cents:

```dart
await pumpCard(tester, cents: 12345);
expect(find.text('RM 123.45'), findsOneWidget);
expect(find.text('Wallet balance'), findsOneWidget);
```

Plus a zero-balance case and a custom-`label` case (asserting the default
label is now absent).

**`test/widgets/order_status_stepper_test.dart`** — the stepper has no text
for "how far along am I", so count the filled circles:

```dart
/// Number of step circles filled teal (i.e. reached).
int doneSteps(WidgetTester tester) => tester
    .widgetList<CircleAvatar>(find.byType(CircleAvatar))
    .where((c) => c.backgroundColor == AppColors.teal)
    .length;
```

Cases: `preparing` → 1, `ready` → 2, `collected` → 3, and `cancelled` shows
`'Order cancelled'` with `find.byType(CircleAvatar)` finding **nothing** —
the cancelled state replaces the stepper rather than greying it out.

## 0.5 Auth feature (~4 h)

- [ ] **`features/auth/repository/auth_repository.dart`**
      Thin user-document CRUD over `FirestoreService`: `createUser(AppUser)`,
      `getUser(uid)`, `watchUser(uid) → Stream<AppUser?>`, `updateUser(uid, map)`.

**`lib/features/auth/repository/auth_repository.dart`**

```dart
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/user.dart';

/// User-document CRUD on top of [FirestoreService].
class AuthRepository {
  final FirestoreService _firestore;

  AuthRepository({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  String get _col => AppConstants.usersCollection;

  Future<void> createUser(AppUser user) {
    return _firestore.setDocument('$_col/${user.uid}', user.toJson());
  }

  Future<AppUser?> getUser(String uid) async {
    final data = await _firestore.getDocument('$_col/$uid');
    return data == null ? null : AppUser.fromJson(data);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _firestore
        .documentStream('$_col/$uid')
        .map((data) => data == null ? null : AppUser.fromJson(data));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _firestore.updateDocument('$_col/$uid', data);
  }
}
```

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

**`lib/features/auth/view_model/auth_view_model.dart`**

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import '../../../models/user.dart';
import '../repository/auth_repository.dart';

enum AuthStatus {
  /// Still resolving the initial auth/user-doc state — show a splash.
  unknown,
  unauthenticated,

  /// Signed in with Firebase but no StallHop user document yet
  /// (a new Google account that must pick a role).
  needsRoleSelection,
  authenticated,
}

/// Single source of truth for authentication. Listens to Firebase auth state
/// and the signed-in user's Firestore document, exposing both to the widget
/// tree via [ChangeNotifier].
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  final AuthRepository _authRepository;

  AuthViewModel({AuthService? authService, AuthRepository? authRepository})
      : _authService = authService ?? AuthService(),
        _authRepository = authRepository ?? AuthRepository() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;

  /// Suppresses the role-selection prompt during email registration, where the
  /// user document is created moments after the auth user.
  bool _suppressRolePrompt = false;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _onAuthStateChanged(User? fbUser) {
    _firebaseUser = fbUser;
    _userSub?.cancel();
    if (fbUser == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _userSub = _authRepository.watchUser(fbUser.uid).listen(
      (appUser) {
        _currentUser = appUser;
        if (appUser != null) {
          _status = AuthStatus.authenticated;
          _suppressRolePrompt = false;
        } else {
          _status = _suppressRolePrompt
              ? AuthStatus.unknown
              : AuthStatus.needsRoleSelection;
        }
        notifyListeners();
      },
      onError: (Object e) {
        // Without this the app wedges on the splash screen with an unhandled
        // stream error if the user document can't be read.
        debugPrint('AuthViewModel user stream error: $e');
        _suppressRolePrompt = false;
        _error = 'Could not load your profile. Please try again.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      },
    );
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _setLoading(true);
    try {
      await _authService.signIn(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    _error = null;
    _suppressRolePrompt = true;
    _setLoading(true);
    try {
      final cred = await _authService.signUp(email, password);
      final uid = cred.user!.uid;
      final now = DateTime.now();
      final user = AppUser(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: role,
        createdAt: now,
        updatedAt: now,
      );
      await _authRepository.createUser(user);
      return true;
    } on FirebaseAuthException catch (e) {
      _suppressRolePrompt = false;
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _suppressRolePrompt = false;
      _error = 'Registration failed. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs in with Google. Returns true if a session was established (existing
  /// or new). For new accounts, [status] becomes [AuthStatus.needsRoleSelection]
  /// and the UI should route to the role-selection page. Returns false when the
  /// user cancels.
  Future<bool> googleSignIn() async {
    _error = null;
    _suppressRolePrompt = false;
    _setLoading(true);
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred == null) return false; // cancelled
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Creates the user document for a newly signed-in Google account once they
  /// pick a role.
  Future<bool> completeRoleSelection({
    required String role,
    String phone = '',
  }) async {
    final fbUser = _firebaseUser;
    if (fbUser == null) {
      _error = 'No active sign-in session.';
      notifyListeners();
      return false;
    }
    _error = null;
    _setLoading(true);
    try {
      final now = DateTime.now();
      final user = AppUser(
        uid: fbUser.uid,
        name: fbUser.displayName ?? '',
        email: fbUser.email ?? '',
        phone: phone.trim(),
        role: role,
        profileImageUrl: fbUser.photoURL,
        createdAt: now,
        updatedAt: now,
      );
      await _authRepository.createUser(user);
      return true;
    } catch (e) {
      _error = 'Could not finish setup. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **`features/auth/view/login_page.dart`** — `Form` + email/password fields
      with `Validators`, error banner from `vm.error`, loading state disables
      the button, Google sign-in button, links to register and password reset.

**`lib/features/auth/view/login_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../view_model/auth_view_model.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final vm = context.read<AuthViewModel>();
    final ok = await vm.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!ok && mounted && vm.error != null) {
      _showError(vm.error!);
    }
  }

  Future<void> _google() async {
    final vm = context.read<AuthViewModel>();
    final ok = await vm.googleSignIn();
    if (!ok && mounted && vm.error != null) {
      _showError(vm.error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text('StallHop', style: AppTextStyles.h1.copyWith(
                    color: AppColors.orange,
                  ), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'Order ahead, skip the queue',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: Validators.password,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: vm.isLoading ? null : _submit,
                    child: vm.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading ? null : _google,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text('Sign up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **`features/auth/view/register_page.dart`** — name, email, phone,
      password, confirm password, and a role selector; calls `vm.register`.

**`lib/features/auth/view/register_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/validators.dart';
import '../view_model/auth_view_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = AppConstants.roleCustomer;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final vm = context.read<AuthViewModel>();
    final ok = await vm.register(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      role: _role,
    );
    if (!mounted) return;
    if (ok) {
      // The AuthGate will route to the role home automatically; pop the
      // registration page off the stack.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => Validators.required(v, 'Name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 24),
                Text('I am a', style: AppTextStyles.title),
                const SizedBox(height: 8),
                _RoleSelector(
                  value: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: vm.isLoading ? null : _submit,
                  child: vm.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RoleSelector({required this.value, required this.onChanged});

  static const _roles = [
    (AppConstants.roleCustomer, 'Customer', Icons.shopping_bag_outlined),
    (AppConstants.roleVendor, 'Vendor', Icons.storefront_outlined),
    (AppConstants.roleAdmin, 'Admin', Icons.admin_panel_settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (role, label, icon) in _roles)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _RoleChip(
                label: label,
                icon: icon,
                selected: value == role,
                onTap: () => onChanged(role),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeLight : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.orange : AppColors.warmGrey),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.orange : AppColors.navy,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **`features/auth/view/choose_role_page.dart`** — three role cards + an
      optional phone field; calls `vm.completeRoleSelection`. Only ever shown
      in the `needsRoleSelection` state.

**`lib/features/auth/view/choose_role_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../view_model/auth_view_model.dart';

/// Shown after a brand-new Google sign-in to capture the user's role before
/// their StallHop account document is created.
class ChooseRolePage extends StatefulWidget {
  const ChooseRolePage({super.key});

  @override
  State<ChooseRolePage> createState() => _ChooseRolePageState();
}

class _ChooseRolePageState extends State<ChooseRolePage> {
  String _role = AppConstants.roleCustomer;
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final vm = context.read<AuthViewModel>();
    final ok = await vm.completeRoleSelection(
      role: _role,
      phone: _phoneController.text,
    );
    if (!ok && mounted && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: AppColors.error),
      );
    }
    // On success the AuthGate routes to the role home automatically.
  }

  static const _roles = [
    (
      AppConstants.roleCustomer,
      'Customer',
      'Browse stalls and order food',
      Icons.shopping_bag_outlined,
    ),
    (
      AppConstants.roleVendor,
      'Vendor',
      'Run a stall and manage orders',
      Icons.storefront_outlined,
    ),
    (
      AppConstants.roleAdmin,
      'Admin',
      'Oversee the venue',
      Icons.admin_panel_settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your role'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.read<AuthViewModel>().logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How will you use StallHop?', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              for (final (role, title, subtitle, icon) in _roles) ...[
                _RoleCard(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: vm.isLoading ? null : _continue,
                child: vm.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeLight : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  selected ? AppColors.orange : AppColors.offWhite,
              child: Icon(icon,
                  color: selected ? AppColors.white : AppColors.warmGrey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}
```

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

**`lib/main.dart`**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/services/notification_coordinator.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'features/auth/view/choose_role_page.dart';
import 'features/auth/view/login_page.dart';
import 'features/auth/view_model/auth_view_model.dart';
import 'features/customer/view_model/cart_vm.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notificationService = NotificationService();
  await notificationService.init();

  // In-app notifications follow the signed-in user: listeners start on
  // login and stop on logout (see NotificationCoordinator).
  final authViewModel = AuthViewModel();
  final notificationCoordinator =
      NotificationCoordinator(notifications: notificationService);
  authViewModel.addListener(
    () => notificationCoordinator.sync(authViewModel.currentUser),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authViewModel),
        ChangeNotifierProvider(create: (_) => CartViewModel()),
      ],
      child: const StallHopApp(),
    ),
  );
}

class StallHopApp extends StatelessWidget {
  const StallHopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

/// Routes between the splash, login, role-selection, and the role home based on
/// [AuthViewModel.status].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    switch (vm.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.needsRoleSelection:
        return const ChooseRolePage();
      case AuthStatus.authenticated:
        return getHomeForRole(vm.currentUser!.role);
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.orange,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **`core/services/notification_coordinator.dart`** — client-side
      replacement for the planned Cloud Functions. `sync(AppUser?)` is
      idempotent: returns early if uid *and* role are unchanged, else stops and
      restarts listeners. Watches announcements for everyone (filtered
      `createdAt > Timestamp.now()` so history doesn't fire, and skips the
      author's own), customer order status transitions, and vendor new-order
      arrivals. The `_orderStatuses` map is **seeded from the first snapshot**
      so pre-existing orders don't notify on login — that seeding logic is the
      subtle part; write the test alongside it.
**`lib/core/services/notification_coordinator.dart`**

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/user.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'notification_service.dart';

/// Client-side replacement for the plan's notification Cloud Functions
/// (`onOrderCreated`, `onOrderStatusChange`, `onAnnouncementCreated`).
///
/// Watches Firestore for the signed-in user and raises local notifications:
/// - customer: their order turns ready / collected / cancelled
/// - vendor: a new order arrives for their stall
/// - everyone: a new venue announcement is published
///
/// Limitation (accepted): notifications only arrive while the app process is
/// alive, since there is no server to push to a killed app.
class NotificationCoordinator {
  final FirebaseFirestore _db;
  final NotificationService _notifications;

  NotificationCoordinator({
    required NotificationService notifications,
    FirebaseFirestore? db,
  })  : _notifications = notifications,
        _db = db ?? FirebaseFirestore.instance;

  String? _activeUid;
  String? _activeRole;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];

  /// Order statuses seen so far, keyed by orderId. Seeded from the first
  /// snapshot so pre-existing orders don't fire notifications on login.
  Map<String, String>? _orderStatuses;

  /// Syncs listeners with the signed-in user. Idempotent: call freely on
  /// every auth change; listeners restart only when the uid or role changes.
  void sync(AppUser? user) {
    if (user?.uid == _activeUid && user?.role == _activeRole) return;
    stop();
    if (user == null) return;
    _activeUid = user.uid;
    _activeRole = user.role;

    _watchAnnouncements(user.uid);
    if (user.role == AppConstants.roleCustomer) {
      _watchCustomerOrders(user.uid);
    } else if (user.role == AppConstants.roleVendor) {
      _watchVendorOrders(user.uid);
    }
  }

  void stop() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _orderStatuses = null;
    _activeUid = null;
    _activeRole = null;
  }

  // --- announcements (all roles) ---

  void _watchAnnouncements(String uid) {
    // Only announcements created after login; no seeding needed.
    final query = _db
        .collection(AppConstants.announcementsCollection)
        .where('createdAt', isGreaterThan: Timestamp.now());
    _listen(query, (snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null || data['createdBy'] == uid) continue;
        _notifications.show(
          id: _stableId(change.doc.id),
          title: (data['title'] ?? 'Announcement') as String,
          body: (data['message'] ?? '') as String,
        );
      }
    });
  }

  // --- customer: order status changes ---

  void _watchCustomerOrders(String uid) {
    final query = _db
        .collection(AppConstants.ordersCollection)
        .where('customerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20);
    _listen(query, (snap) {
      final seeded = _orderStatuses != null;
      final statuses = _orderStatuses ??= {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '') as String;
        final previous = statuses[doc.id];
        statuses[doc.id] = status;
        // Notify only on a transition observed after the initial snapshot.
        // A newly placed order (previous == null) is the customer's own
        // action and needs no notification.
        if (!seeded || previous == null || previous == status) continue;
        _notifyCustomerStatus(doc.id, data, status);
      }
    });
  }

  void _notifyCustomerStatus(
    String orderId,
    Map<String, dynamic> data,
    String status,
  ) {
    final stall = (data['stallName'] ?? 'the stall') as String;
    final code = (data['pickupCode'] ?? '') as String;
    String? title;
    String? body;
    switch (status) {
      case AppConstants.orderReady:
        title = 'Order $code is ready!';
        body = 'Show your QR code at $stall to collect it.';
      case AppConstants.orderCollected:
        title = 'Order $code collected';
        body = 'Enjoy your meal from $stall!';
      case AppConstants.orderCancelled:
        final total = (data['total'] ?? 0) as int;
        title = 'Order $code cancelled';
        body = '${centsToRM(total)} has been refunded to your wallet.';
    }
    if (title == null || body == null) return;
    _notifications.show(id: _stableId(orderId), title: title, body: body);
  }

  // --- vendor: new incoming orders ---

  void _watchVendorOrders(String uid) {
    final query = _db
        .collection(AppConstants.ordersCollection)
        .where('vendorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20);
    _listen(query, (snap) {
      final seeded = _orderStatuses != null;
      final statuses = _orderStatuses ??= {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '') as String;
        final isNew = !statuses.containsKey(doc.id);
        statuses[doc.id] = status;
        if (!seeded || !isNew) continue;
        final code = (data['pickupCode'] ?? '') as String;
        final total = (data['total'] ?? 0) as int;
        _notifications.show(
          id: _stableId(doc.id),
          title: 'New order $code',
          body: '${data['customerName'] ?? 'A customer'} • '
              '${centsToRM(total)} — start preparing!',
        );
      }
    });
  }

  // --- helpers ---

  void _listen(
    Query<Map<String, dynamic>> query,
    void Function(QuerySnapshot<Map<String, dynamic>>) onData,
  ) {
    _subs.add(query.snapshots().listen(
      onData,
      onError: (Object e) =>
          debugPrint('NotificationCoordinator stream error: $e'),
    ));
  }

  /// Stable non-negative notification id derived from a document id, so a
  /// later update to the same subject replaces its notification.
  static int _stableId(String docId) => docId.hashCode & 0x7fffffff;
}
```

- [ ] `test/services/notification_coordinator_test.dart` with a
      `RecordingNotificationService extends NotificationService` that captures
      calls instead of touching the platform plugin.
- [ ] `test/utils/formatters_test.dart`, `test/utils/validators_test.dart`.

### Test code for §0.5

**`test/services/notification_coordinator_test.dart`** — the whole trick is
the recording subclass. Subclassing beats mocking here because
`NotificationService.show` is the only method the coordinator calls:

```dart
/// Records notifications instead of touching the platform plugin.
class RecordingNotificationService extends NotificationService {
  final List<({int id, String title, String body})> shown = [];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id: id, title: title, body: body));
  }
}
```

Two more helpers carry the rest of the file — an `orderDoc({...})` map builder
(the coordinator reads raw Firestore docs, so build maps, not models) and:

```dart
// Let the fake's snapshot streams deliver.
Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 10));
```

⚠️ Note this is `milliseconds: 10`, **not** the `Duration.zero` used after
constructing a view model. The coordinator chains a stream subscription onto
`FakeFirebaseFirestore`'s snapshot stream, and a zero-delay microtask drain
lands before the fake emits.

**`test/utils/formatters_test.dart`** — group per function; the cases worth
naming are the sign placement and the rounding boundary:

```dart
expect(centsToRM(0), 'RM 0.00');
expect(centsToRM(5), 'RM 0.05');       // not 'RM 0.5'
expect(centsToRM(-750), '-RM 7.50');   // sign outside the currency prefix
expect(rmToCents('7.505'), 751);       // rounds, not truncates
expect(rmToCents('7,50'), isNull);     // comma is not a decimal separator
```

**`test/utils/validators_test.dart`** — every validator returns `null` for
valid input and a message otherwise, so each group is a pair of
`isNull` / `isNotNull` tests. Cover `email`, `password`, `confirmPassword`,
`phone`, `required`, `price`. The two easy-to-miss ones:

```dart
expect(Validators.phone('012-345 6789'), isNull); // separators stripped
expect(Validators.required('', 'Name'), contains('Name'));
```

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
### The rules file

**`firestore.rules`**

```javascript
rules_version = '2';

// StallHop security rules.
//
// The client performs ALL wallet arithmetic (there are no Cloud Functions in
// this project), so these rules are the only thing standing between a customer
// and `walletBalance: 999999`. See the documented limitation at the bottom.
service cloud.firestore {
  match /databases/{database}/documents {

    // ---------- helpers ----------

    function signedIn() {
      return request.auth != null;
    }

    function myUid() {
      return request.auth.uid;
    }

    // NOTE: each get() costs a document read and counts toward the rules
    // evaluation limit. Kept simple deliberately for a single-venue app.
    function userRole() {
      return get(/databases/$(database)/documents/users/$(myUid())).data.role;
    }

    function isAdmin() {
      return signedIn() && userRole() == 'admin';
    }

    function isVendor() {
      return signedIn() && userRole() == 'vendor';
    }

    // Fields being changed by this write.
    function touchedKeys() {
      return request.resource.data.diff(resource.data).affectedKeys();
    }

    // ---------- users ----------

    match /users/{uid} {
      allow read: if signedIn() && (uid == myUid() || isAdmin());

      // A new account may only be created for yourself, must pick one of the
      // three real roles, and must start with an empty wallet — otherwise a
      // user could register themselves rich.
      allow create: if signedIn()
                    && uid == myUid()
                    && request.resource.data.uid == myUid()
                    && request.resource.data.role in ['customer', 'vendor', 'admin']
                    && request.resource.data.walletBalance == 0;

      // Role is immutable after creation: a customer must not be able to
      // promote themselves to admin and unlock the venue-wide queries below.
      //
      // The third clause is the unavoidable hole (see the note at the bottom
      // of this file): placeOrder credits the VENDOR's wallet from the
      // CUSTOMER's client, so a signed-in user must be able to touch another
      // user's balance. It is narrowed as far as rules allow — only
      // walletBalance/updatedAt, and role still cannot change.
      allow update: if signedIn()
                    && request.resource.data.role == resource.data.role
                    && (
                      uid == myUid()
                      || isAdmin()
                      || touchedKeys().hasOnly(['walletBalance', 'updatedAt'])
                    );

      allow delete: if false;
    }

    // ---------- stalls ----------

    match /stalls/{stallId} {
      allow read: if signedIn();

      // A vendor may only create a stall for themselves, and it must start
      // `pending` so it cannot bypass admin approval.
      allow create: if isVendor()
                    && request.resource.data.vendorUid == myUid()
                    && request.resource.data.status == 'pending';

      // The owning vendor edits their stall, but `status` and `commissionRate`
      // are admin-only: a vendor must not approve their own stall or set their
      // own commission to zero.
      allow update: if isAdmin()
                    || (isVendor()
                        && resource.data.vendorUid == myUid()
                        && !touchedKeys().hasAny(['status', 'commissionRate']));

      allow delete: if isAdmin();

      match /menuItems/{itemId} {
        allow read: if signedIn();
        allow write: if isVendor()
                     && get(/databases/$(database)/documents/stalls/$(stallId))
                          .data.vendorUid == myUid();
      }
    }

    // ---------- orders ----------

    match /orders/{orderId} {
      allow read: if signedIn() && (
                    resource.data.customerUid == myUid()
                    || resource.data.vendorUid == myUid()
                    || isAdmin()
                  );

      allow create: if signedIn()
                    && request.resource.data.customerUid == myUid()
                    && request.resource.data.status == 'preparing';

      // Vendor drives status transitions, customer can cancel, admin resolves
      // disputes (refunded / dismissed).
      allow update: if signedIn() && (
                      resource.data.vendorUid == myUid()
                      || resource.data.customerUid == myUid()
                      || isAdmin()
                    );

      allow delete: if false;
    }

    // ---------- transactions (the ledger) ----------

    match /transactions/{txnId} {
      allow read: if signedIn() && (resource.data.userId == myUid() || isAdmin());
      allow create: if signedIn();

      // Append-only. A ledger whose rows can be edited or deleted after the
      // fact cannot audit anything — the balanceBefore/balanceAfter chain is
      // only meaningful if past rows are frozen.
      allow update, delete: if false;
    }

    // ---------- reviews ----------

    match /reviews/{reviewId} {
      allow read: if signedIn();
      allow create: if signedIn()
                    && request.resource.data.customerUid == myUid();
      allow update, delete: if false;
    }

    // ---------- announcements ----------

    match /announcements/{announcementId} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    // ---------- venue config ----------

    match /config/venue {
      // All three roles read this now (commission + service fee).
      allow read: if signedIn();

      allow create: if isAdmin();

      // Admins write settings freely. Any signed-in customer may also write,
      // but ONLY the pickup-code fields, because placeOrder bumps the counter
      // from the customer's client inside its transaction.
      allow update: if isAdmin()
                    || (signedIn() && touchedKeys().hasOnly([
                         'pickupCodePrefix',
                         'pickupCodeCounter',
                         'pickupCodeDate',
                         'updatedAt'
                       ]));

      allow delete: if false;
    }

    // Deny anything not matched above.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}

// ---------------------------------------------------------------------------
// KNOWN LIMITATION (documented deliberately; see report §8)
//
// `OrderRepository.placeOrder` credits the VENDOR's `walletBalance` from the
// CUSTOMER's client, inside a single Firestore transaction. No rule can verify
// that this credit corresponds to a real order, because security rules evaluate
// each document write in isolation and cannot inspect sibling writes in the
// same transaction. The `users` update rule above therefore has to permit any
// signed-in user to change another user's `walletBalance`, which means a
// hand-crafted client could credit itself. The rule narrows the blast radius
// (role stays immutable, only two fields are writable) but cannot close it.
//
// Closing this properly requires moving the wallet mutation server-side (a
// Cloud Function or callable), which is out of scope for this project. It is
// named here rather than left to be discovered.
// ---------------------------------------------------------------------------
```

And the `firestore` block of `firebase.json` gains the `rules` key alongside
the existing `indexes` key:

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

- [ ] Deploy: `firebase deploy --only firestore:rules`
- [ ] Copy `firestore.indexes.json` from the reference **as-is** — its seven
      composite indexes are correct and complete (orders by
      status/customerUid/vendorUid + createdAt, vendorUid+status+createdAt,
      transactions by userId(+type)+createdAt, reviews by stallId+createdAt).
      Deploy with `firebase deploy --only firestore:indexes`.

**`firestore.indexes.json`**

```json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "customerUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "vendorUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "vendorUid", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "transactions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "transactions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "stallId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

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

### The seed script

⚠ **Fill in the three UIDs at the top before running** — the script fails fast
rather than writing documents keyed by a placeholder string.

**`integration_test/seed_test.dart`**

```dart
// Seed data for StallHop.
//
// This is NOT a real test — it is a script that happens to run through the
// integration_test harness, because that is the only way to get Firebase
// initialised with real platform bindings without the Admin SDK. A plain
// `dart run` script cannot do this.
//
// Run it on a connected device/emulator:
//
//     flutter test integration_test/seed_test.dart
//
// It is IDEMPOTENT: every document uses a fixed id and `set` (with merge where
// appropriate), so re-running restores the known-good state rather than
// duplicating rows. You will re-run this constantly during QA.
//
// PREREQUISITE: register these three accounts through the app's own register
// page first, then paste their UIDs below (Firebase Console > Authentication).
// Auth users cannot be created from here.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stallhop/core/utils/constants.dart';
import 'package:stallhop/firebase_options.dart';

// ---------------------------------------------------------------------------
// FILL THESE IN — copy from Firebase Console > Authentication > Users.
// Never commit the shared password; keep it in the team channel.
// ---------------------------------------------------------------------------
const customerUid = 'PASTE_CUSTOMER_UID';
const vendorUid = 'PASTE_VENDOR_UID';
const adminUid = 'PASTE_ADMIN_UID';

Timestamp get _now => Timestamp.fromDate(DateTime.now());

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed firestore', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final db = FirebaseFirestore.instance;

    // Fail loudly rather than writing documents keyed by a placeholder.
    for (final uid in [customerUid, vendorUid, adminUid]) {
      if (uid.startsWith('PASTE_')) {
        fail('Fill in the three UIDs at the top of seed_test.dart first.');
      }
    }

    // ----- config/venue -------------------------------------------------
    // merge:true so a re-run never wipes the live pickup-code counter.
    await db
        .collection(AppConstants.configCollection)
        .doc(AppConstants.venueConfigDoc)
        .set({
      'venueName': 'StallHop Food Court',
      'defaultCommission': 0.10,
      'serviceFee': 50,
      'pickupCodePrefix': 'A',
      'pickupCodeCounter': 0,
      'latitude': 3.1390,
      'longitude': 101.6869,
      'updatedAt': _now,
    }, SetOptions(merge: true));

    // ----- wallet top-up for the customer test account ------------------
    // merge:true — this must not clobber the name/email/role written by the
    // app when the account registered.
    await db.collection(AppConstants.usersCollection).doc(customerUid).set({
      'walletBalance': 10000, // RM 100.00
      'updatedAt': _now,
    }, SetOptions(merge: true));

    // ----- stalls -------------------------------------------------------
    // Three open + one pending, so Justin has something to approve on day one.
    // commissionRate is null everywhere: inherit the venue default.
    final stalls = <String, Map<String, dynamic>>{
      'stall-malay': {
        'name': 'Warung Nasi Lemak',
        'description': 'Classic nasi lemak with sambal, egg and rendang.',
        'cuisine': 'Malay',
        'status': AppConstants.stallOpen,
        'prepTimeMinutes': 12,
        'averageRating': 4.5,
        'totalReviews': 24,
      },
      'stall-chinese': {
        'name': 'Wok Hei Noodles',
        'description': 'Char kway teow and wonton mee cooked to order.',
        'cuisine': 'Chinese',
        'status': AppConstants.stallOpen,
        'prepTimeMinutes': 15,
        'averageRating': 4.2,
        'totalReviews': 18,
      },
      'stall-indian': {
        'name': 'Roti Corner',
        'description': 'Roti canai, thosai and teh tarik all day.',
        'cuisine': 'Indian',
        'status': AppConstants.stallOpen,
        'prepTimeMinutes': 8,
        'averageRating': 4.7,
        'totalReviews': 31,
      },
      'stall-western': {
        'name': 'Grill & Chill',
        'description': 'Burgers, chicken chop and fries.',
        'cuisine': 'Western',
        'status': AppConstants.stallPending, // <- awaiting admin approval
        'prepTimeMinutes': 20,
        'averageRating': 0.0,
        'totalReviews': 0,
      },
    };

    for (final entry in stalls.entries) {
      await db
          .collection(AppConstants.stallsCollection)
          .doc(entry.key)
          .set({
        'stallId': entry.key,
        'vendorUid': vendorUid,
        'imageUrl': null,
        'commissionRate': null, // inherit config/venue.defaultCommission
        'latitude': 3.1390,
        'longitude': 101.6869,
        'createdAt': _now,
        'updatedAt': _now,
        ...entry.value,
      });
    }

    // ----- menu items ---------------------------------------------------
    // ~15 items across the four stalls, prices 300–1800 cents. At least two
    // carry customizations, two carry add-ons, and one is unavailable.
    final menu = <String, List<Map<String, dynamic>>>{
      'stall-malay': [
        {
          'itemId': 'malay-1',
          'name': 'Nasi Lemak Ayam',
          'description': 'Coconut rice, fried chicken, sambal, egg.',
          'price': 950,
          'category': 'Rice',
          'customizations': [
            {'name': 'Spice level', 'options': ['Mild', 'Medium', 'Extra hot']},
          ],
          'addOns': [
            {'name': 'Extra egg', 'price': 150},
            {'name': 'Extra sambal', 'price': 100},
          ],
        },
        {
          'itemId': 'malay-2',
          'name': 'Nasi Lemak Rendang',
          'description': 'Coconut rice with beef rendang.',
          'price': 1250,
          'category': 'Rice',
        },
        {
          'itemId': 'malay-3',
          'name': 'Teh Tarik',
          'description': 'Pulled milk tea.',
          'price': 300,
          'category': 'Drinks',
          'customizations': [
            {'name': 'Temperature', 'options': ['Hot', 'Iced']},
            {'name': 'Sugar', 'options': ['Normal', 'Less', 'None']},
          ],
        },
        {
          'itemId': 'malay-4',
          'name': 'Kuih Lapis',
          'description': 'Steamed layered cake.',
          'price': 350,
          'category': 'Desserts',
          'available': false, // <- one deliberately unavailable item
        },
      ],
      'stall-chinese': [
        {
          'itemId': 'chinese-1',
          'name': 'Char Kway Teow',
          'description': 'Flat rice noodles with prawn and cockles.',
          'price': 1100,
          'category': 'Noodles',
          'addOns': [
            {'name': 'Extra prawns', 'price': 400},
          ],
        },
        {
          'itemId': 'chinese-2',
          'name': 'Wonton Mee',
          'description': 'Egg noodles with char siu and wontons.',
          'price': 900,
          'category': 'Noodles',
        },
        {
          'itemId': 'chinese-3',
          'name': 'Hainanese Chicken Rice',
          'description': 'Poached chicken with fragrant rice.',
          'price': 1050,
          'category': 'Rice',
        },
        {
          'itemId': 'chinese-4',
          'name': 'Barley Drink',
          'description': 'Chilled barley water.',
          'price': 320,
          'category': 'Drinks',
        },
      ],
      'stall-indian': [
        {
          'itemId': 'indian-1',
          'name': 'Roti Canai',
          'description': 'Flaky flatbread with dhal curry.',
          'price': 300,
          'category': 'Bread',
          'addOns': [
            {'name': 'Egg', 'price': 150},
            {'name': 'Sardine', 'price': 250},
          ],
        },
        {
          'itemId': 'indian-2',
          'name': 'Thosai Masala',
          'description': 'Crispy thosai with spiced potato.',
          'price': 650,
          'category': 'Bread',
        },
        {
          'itemId': 'indian-3',
          'name': 'Mee Goreng Mamak',
          'description': 'Spicy fried noodles.',
          'price': 800,
          'category': 'Noodles',
          'customizations': [
            {'name': 'Spice level', 'options': ['Mild', 'Spicy']},
          ],
        },
        {
          'itemId': 'indian-4',
          'name': 'Teh O Ais Limau',
          'description': 'Iced lime tea.',
          'price': 350,
          'category': 'Drinks',
        },
      ],
      'stall-western': [
        {
          'itemId': 'western-1',
          'name': 'Chicken Chop',
          'description': 'Grilled chicken with black pepper sauce and fries.',
          'price': 1800,
          'category': 'Mains',
        },
        {
          'itemId': 'western-2',
          'name': 'Beef Burger',
          'description': 'Beef patty, cheese, lettuce, house sauce.',
          'price': 1500,
          'category': 'Mains',
          'addOns': [
            {'name': 'Extra patty', 'price': 600},
            {'name': 'Cheese slice', 'price': 200},
          ],
        },
        {
          'itemId': 'western-3',
          'name': 'Fries',
          'description': 'Salted shoestring fries.',
          'price': 600,
          'category': 'Sides',
        },
      ],
    };

    for (final stallEntry in menu.entries) {
      final stallId = stallEntry.key;
      for (final item in stallEntry.value) {
        await db
            .collection(AppConstants.stallsCollection)
            .doc(stallId)
            .collection(AppConstants.menuItemsSubcollection)
            .doc(item['itemId'] as String)
            .set({
          'stallId': stallId,
          'imageUrl': null,
          'available': true,
          'customizations': const <Map<String, dynamic>>[],
          'addOns': const <Map<String, dynamic>>[],
          'createdAt': _now,
          'updatedAt': _now,
          ...item,
        });
      }
    }

    debugPrintSeedSummary(stalls.length, menu.values.expand((e) => e).length);
  });
}

void debugPrintSeedSummary(int stallCount, int itemCount) {
  // ignore: avoid_print
  print('Seeded $stallCount stalls and $itemCount menu items.');
}
```

Run it against a connected device or emulator:

```bash
flutter test integration_test/seed_test.dart
```

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
- [ ] ~~Fix the two pre-existing test defects in your own files: the
      contradictory comment in `models_test.dart`, and the bare `630` literal
      in `order_repository_test.dart`.~~ **Done** — see
      `foundation_and_integration.md` §6.1 for what each turned out to be.
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
