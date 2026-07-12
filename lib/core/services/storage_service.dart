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
