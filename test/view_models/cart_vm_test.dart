import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/utils/constants.dart';
import 'package:stallhop/features/customer/view_model/cart_vm.dart';
import 'package:stallhop/models/order_item.dart';
import 'package:stallhop/models/stall.dart';

Stall _stall(String id) => Stall(
      stallId: id,
      vendorUid: 'v_$id',
      name: 'Stall $id',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

OrderItem _item(
  String id, {
  int price = 500,
  int qty = 1,
  List<Map<String, dynamic>> addOns = const [],
}) =>
    OrderItem(
      itemId: id,
      name: 'Item $id',
      unitPrice: price,
      quantity: qty,
      addOns: addOns,
    );

void main() {
  late CartViewModel cart;

  setUp(() => cart = CartViewModel());

  test('starts empty', () {
    expect(cart.isEmpty, isTrue);
    expect(cart.totalItemCount, 0);
    expect(cart.grandTotal, 0);
  });

  test('adds an item and computes subtotal + service fee', () {
    cart.addItem(_stall('s1'), _item('i1', price: 500, qty: 2));
    expect(cart.getSubtotal('s1'), 1000);
    expect(cart.getServiceFee('s1'), AppConstants.serviceFeeCents);
    expect(cart.getStallTotal('s1'), 1000 + AppConstants.serviceFeeCents);
    expect(cart.totalItemCount, 2);
  });

  test('merges identical lines by quantity', () {
    cart.addItem(_stall('s1'), _item('i1', qty: 1));
    cart.addItem(_stall('s1'), _item('i1', qty: 2));
    expect(cart.itemsFor('s1').length, 1);
    expect(cart.itemsFor('s1').first.quantity, 3);
  });

  test('keeps distinct lines when add-ons differ', () {
    cart.addItem(_stall('s1'), _item('i1'));
    cart.addItem(
      _stall('s1'),
      _item('i1', addOns: [
        {'name': 'Egg', 'price': 100},
      ]),
    );
    expect(cart.itemsFor('s1').length, 2);
  });

  test('increment / decrement adjusts quantity', () {
    cart.addItem(_stall('s1'), _item('i1', qty: 1));
    cart.incrementItem('s1', 0);
    expect(cart.itemsFor('s1').first.quantity, 2);
    cart.decrementItem('s1', 0);
    expect(cart.itemsFor('s1').first.quantity, 1);
  });

  test('decrementing to zero removes the line and empties the stall', () {
    cart.addItem(_stall('s1'), _item('i1', qty: 1));
    cart.decrementItem('s1', 0);
    expect(cart.isEmpty, isTrue);
    expect(cart.stallIds, isEmpty);
  });

  test('groups items across multiple stalls', () {
    cart.addItem(_stall('s1'), _item('i1', price: 500));
    cart.addItem(_stall('s2'), _item('i2', price: 700));
    expect(cart.stallIds.length, 2);
    expect(cart.grandSubtotal, 1200);
    expect(cart.totalServiceFee, AppConstants.serviceFeeCents * 2);
    expect(cart.grandTotal, 1200 + AppConstants.serviceFeeCents * 2);
  });

  test('clear empties everything', () {
    cart.addItem(_stall('s1'), _item('i1'));
    cart.addItem(_stall('s2'), _item('i2'));
    cart.clear();
    expect(cart.isEmpty, isTrue);
    expect(cart.grandTotal, 0);
  });
}
