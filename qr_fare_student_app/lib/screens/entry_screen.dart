import 'package:flutter/material.dart';
import 'registration_screen.dart';

class StudentEntryScreen extends StatelessWidget {
  const StudentEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Hero Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: const Icon(Icons.school, size: 80, color: Colors.cyanAccent),
                ),
              ),
              
              const SizedBox(height: 48),
              
              const Text(
                'YOUR DIGITAL\nCAMPUS PASS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Generate secure, time-sensitive offline QR codes for campus transit without needing an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              
              const Spacer(),
              
              // Primary CTA
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRegistrationScreen()));
                },
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
                    ]
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'SETUP STUDENT PASS',
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Secondary Action
              TextButton(
                onPressed: () {
                  // Stub for restore
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('RESTORE EXISTING ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
