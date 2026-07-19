import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/user.dart';

/// User-document CRUD at `users/{uid}`.
class AuthRepository {
  final FirebaseFirestore _db;

  AuthRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  Future<void> createUser(AppUser user) {
    return _userRef(user.uid).set(user.toJson());
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _userRef(uid).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromJson(data);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _userRef(uid).snapshots().map(
          (snap) => snap.data() == null ? null : AppUser.fromJson(snap.data()!),
        );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _userRef(uid).update(data);
  }
}
