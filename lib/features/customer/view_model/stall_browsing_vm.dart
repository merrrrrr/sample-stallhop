import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';
import '../repository/stall_repository.dart';

enum StallSort { rating, prepTime, name }

/// Loads visible stalls and exposes a filtered/sorted view for the home tab.
class StallBrowsingViewModel extends ChangeNotifier {
  final StallRepository _repository;
  StreamSubscription<List<Stall>>? _sub;

  StallBrowsingViewModel({StallRepository? repository})
      : _repository = repository ?? StallRepository() {
    _listen();
  }

  List<Stall> _all = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _cuisine;
  StallSort _sort = StallSort.rating;

  bool get isLoading => _loading;
  String? get error => _error;
  String get search => _search;
  String? get cuisine => _cuisine;
  StallSort get sort => _sort;

  /// Distinct cuisines present in the data, for the filter chips.
  List<String> get cuisines {
    final set = <String>{};
    for (final s in _all) {
      if (s.cuisine.isNotEmpty) set.add(s.cuisine);
    }
    final list = set.toList()..sort();
    return list;
  }

  void _listen() {
    _sub = _repository.watchVisibleStalls().listen(
      (stalls) {
        _all = stalls;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = 'Could not load stalls.';
        notifyListeners();
      },
    );
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setCuisine(String? value) {
    _cuisine = value;
    notifyListeners();
  }

  void setSort(StallSort value) {
    _sort = value;
    notifyListeners();
  }

  List<Stall> get stalls {
    var list = _all.where((s) {
      final matchesSearch = _search.isEmpty ||
          s.name.toLowerCase().contains(_search.toLowerCase());
      final matchesCuisine = _cuisine == null || s.cuisine == _cuisine;
      return matchesSearch && matchesCuisine;
    }).toList();

    switch (_sort) {
      case StallSort.rating:
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case StallSort.prepTime:
        list.sort((a, b) => a.prepTimeMinutes.compareTo(b.prepTimeMinutes));
      case StallSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    // Show open stalls before closed ones regardless of sort.
    list.sort((a, b) {
      final ao = a.status == AppConstants.stallOpen ? 0 : 1;
      final bo = b.status == AppConstants.stallOpen ? 0 : 1;
      return ao.compareTo(bo);
    });
    return list;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
