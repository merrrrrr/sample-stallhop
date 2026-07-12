import 'package:flutter/material.dart';

import '../../features/admin/view/admin_dashboard_page.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/customer/view/customer_home_page.dart';
import '../../features/vendor/view/vendor_dashboard_page.dart';
import '../utils/constants.dart';

/// Maps a user role to its home screen.
Widget getHomeForRole(String role) {
  switch (role) {
    case AppConstants.roleCustomer:
      return const CustomerHomePage();
    case AppConstants.roleVendor:
      return const VendorDashboardPage();
    case AppConstants.roleAdmin:
      return const AdminDashboardPage();
    default:
      return const LoginPage();
  }
}
