import 'package:flutter/foundation.dart';

import '../../../models/announcement.dart';
import '../repository/announcement_repository.dart';

class AnnouncementsViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;

  AnnouncementsViewModel({AnnouncementRepository? repository})
      : _repository = repository ?? AnnouncementRepository();

  bool _sending = false;
  String? _error;

  bool get isSending => _sending;
  String? get error => _error;

  Stream<List<Announcement>> get announcements =>
      _repository.watchAnnouncements();

  Future<bool> publish({
    required String title,
    required String message,
    required String createdBy,
  }) async {
    _error = null;
    _sending = true;
    notifyListeners();
    try {
      await _repository.create(
        title: title.trim(),
        message: message.trim(),
        createdBy: createdBy,
      );
      return true;
    } catch (e) {
      _error = 'Could not publish announcement.';
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) => _repository.delete(id);
}
