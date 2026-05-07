import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PulseBadge extends StatelessWidget {
  final String label;
  final bool active;

  const PulseBadge({super.key, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.neonBlue.withValues(alpha: 0.18)
            : AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppColors.neonBlue : AppColors.border,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.neonBlue : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
