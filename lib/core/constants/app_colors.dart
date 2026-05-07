import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF040915);
  static const Color surface = Color(0xFF0E172C);
  static const Color panel = Color(0xFF111B34);
  static const Color neonBlue = Color(0xFF4FD8FF);
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonAccent = Color(0xFF5EEAD4);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB8C3DA);
  static const Color border = Color(0xFF243257);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xFF020917)],
  );
}
