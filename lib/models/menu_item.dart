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
