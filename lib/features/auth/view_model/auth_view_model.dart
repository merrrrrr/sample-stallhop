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
    _userSub = _authRepository.watchUser(fbUser.uid).listen((appUser) {
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
    });
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
