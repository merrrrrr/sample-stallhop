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
