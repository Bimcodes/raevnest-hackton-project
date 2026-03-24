import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'pass_screen.dart';
import 'ledger_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  final List<Widget> _pages = [
    const PassScreen(),
    const HistoryScreen(),
    const LedgerScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: 0,
        height: 65.0,
        items: <Widget>[
          Icon(Icons.qr_code_2_rounded, size: 30, color: _currentIndex == 0 ? primary : (isDark ? Colors.white54 : Colors.black45)),
          Icon(Icons.history_rounded, size: 30, color: _currentIndex == 1 ? primary : (isDark ? Colors.white54 : Colors.black45)),
          Icon(Icons.account_balance_wallet_outlined, size: 30, color: _currentIndex == 2 ? primary : (isDark ? Colors.white54 : Colors.black45)),
          Icon(Icons.person_outline, size: 30, color: _currentIndex == 3 ? primary : (isDark ? Colors.white54 : Colors.black45)),
        ],
        color: isDark ? const Color(0xFF141414) : Colors.white,
        buttonBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
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
