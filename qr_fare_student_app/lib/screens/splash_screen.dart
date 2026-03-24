import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_screen.dart';
import 'home_screen.dart';

class StudentSplashScreen extends StatefulWidget {
  const StudentSplashScreen({super.key});

  @override
  State<StudentSplashScreen> createState() => _StudentSplashScreenState();
}

class _StudentSplashScreenState extends State<StudentSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final isRegistered = prefs.getBool('student_registered') ?? false;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => isRegistered 
                ? const StudentHomeScreen() 
                : const StudentRegistrationScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              // const Text(
              //   'GHOST GRAVITY',
              //   style: TextStyle(
              //     color: Colors.white,
              //     fontSize: 28,
              //     fontWeight: FontWeight.w900,
              //     letterSpacing: 8.0,
              //   ),
              // ),
              const SizedBox(height: 8),
              const Text(
                'STUDENT PORTAL',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
