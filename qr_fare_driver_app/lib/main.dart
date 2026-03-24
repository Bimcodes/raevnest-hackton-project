import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const DriverApp(),
    ),
  );
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'QR Fare - Driver',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          // Light Mode Mesh Target Configurations
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF6F8FA),
            primaryColor: const Color(0xFF00ACC1), // Deep Cyan for contrast
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF6F8FA),
              elevation: 0,
              foregroundColor: Color(0xFF121212),
            ),
            cardColor: Colors.white.withOpacity(0.5),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00ACC1),
              secondary: Color(0xFF00ACC1),
              surface: Colors.white,
            ),
          ),
          // Dark Mode Exact Fintech Target
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            primaryColor: Colors.cyanAccent,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0A0A0A),
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            cardColor: const Color(0xFF1A1A1A),
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              secondary: Colors.cyanAccent,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          home: const DriverSplashScreen(),
        );
      },
    );
  }
}
