import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/menu_item.dart';
import '../repository/menu_repository.dart';

/// Lists and mutates a stall's menu items.
class MenuManagementViewModel extends ChangeNotifier {
  final MenuRepository _repository;
  final String stallId;
  StreamSubscription<List<MenuItem>>? _sub;

  List<MenuItem> _items = [];
  bool _loading = true;

  MenuManagementViewModel(this.stallId, {MenuRepository? repository})
      : _repository = repository ?? MenuRepository() {
    _sub = _repository.watchMenuItems(stallId).listen((items) {
      _items = items;
      _loading = false;
      notifyListeners();
    });
  }

  List<MenuItem> get items => _items;
  bool get isLoading => _loading;

  Future<void> toggleAvailable(MenuItem item) {
    return _repository.setAvailable(stallId, item.itemId, !item.available);
  }

  Future<void> delete(MenuItem item) {
    return _repository.deleteItem(stallId, item.itemId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
