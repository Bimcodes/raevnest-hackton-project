import 'package:flutter/material.dart';

void showGlassSnackBar(BuildContext context, String message, {bool isError = false, bool isWarning = false}) {
  final color = isError ? Colors.redAccent : (isWarning ? Colors.orangeAccent : Colors.cyanAccent);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
      ),
      elevation: 10,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    ),
  );
}
