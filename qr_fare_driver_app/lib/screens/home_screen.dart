import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'dashboard_screen.dart';
import 'rides_screen.dart';
import 'balance_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  final List<Widget> _pages = [
    const DashboardScreen(),
    const RidesScreen(),
    const ScanScreen(),
    const BalanceScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In Light Mode the bar is white, so inactive icons must be dark to be visible
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;
    final activeColor = Colors.cyanAccent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: 0,
        height: 65.0,
        items: <Widget>[
          Icon(Icons.home_outlined, size: 30, color: _currentIndex == 0 ? activeColor : inactiveColor),
          Icon(Icons.format_list_bulleted_outlined, size: 30, color: _currentIndex == 1 ? activeColor : inactiveColor),
          // The scan tab uses a special orange bubble — always high contrast
          Icon(Icons.qr_code_scanner, size: 36, color: _currentIndex == 2 ? Colors.white : Colors.deepOrangeAccent),
          Icon(Icons.account_balance_wallet_outlined, size: 30, color: _currentIndex == 3 ? activeColor : inactiveColor),
          Icon(Icons.person_outline, size: 30, color: _currentIndex == 4 ? activeColor : inactiveColor),
        ],
        color: isDark ? const Color(0xFF141414) : Colors.white,
        buttonBackgroundColor: _currentIndex == 2
            ? Colors.deepOrangeAccent
            : (isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]),
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOutQuint,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
