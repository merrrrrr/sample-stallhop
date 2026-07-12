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
