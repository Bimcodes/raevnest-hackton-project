import 'package:flutter/material.dart';
import 'entry_screen.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    
    _animationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverEntryScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 180, height: 180),
              const SizedBox(height: 24),
              const Text(
                'DRIVER PORTAL',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Secure Transit System', style: TextStyle(color: Colors.cyanAccent, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
