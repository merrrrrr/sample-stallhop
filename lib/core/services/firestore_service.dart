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
