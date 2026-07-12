import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/cart_vm.dart';
import 'cart_page.dart';
import 'orders_list_page.dart';
import 'stall_browsing_page.dart';
import 'wallet_page.dart';
import 'customer_profile_page.dart';

/// Customer shell with a 4-tab bottom navigation. [IndexedStack] preserves each
/// tab's state across switches.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _index = 0;

  static const _pages = [
    StallBrowsingPage(),
    OrdersListPage(),
    WalletPage(),
    CustomerProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartViewModel>().totalItemCount;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: (_index == 0 && cartCount > 0)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartPage()),
              ),
              icon: const Icon(Icons.shopping_cart),
              label: Text('$cartCount'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
