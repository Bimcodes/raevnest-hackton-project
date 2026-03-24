import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_screen.dart';
import 'home_screen.dart';

class DriverEntryScreen extends StatefulWidget {
  const DriverEntryScreen({super.key});

  @override
  State<DriverEntryScreen> createState() => _DriverEntryScreenState();
}

class _DriverEntryScreenState extends State<DriverEntryScreen> {
  bool _isLoading = true;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    _isRegistered = prefs.getBool('driver_registered') ?? false;
    setState(() => _isLoading = false);
  }

  void _onRegistered() {
    setState(() => _isRegistered = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isRegistered) return DriverRegistrationScreen(onRegistered: _onRegistered);
    return const DriverHomeScreen();
  }
}
