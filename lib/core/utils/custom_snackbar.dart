import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    // Media query to check if it's a wide screen
    final isWide = MediaQuery.of(context).size.width > 600;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: backgroundColor.withValues(alpha: 0.85),
          behavior: SnackBarBehavior.floating,
          width: isWide ? 350 : null,
          margin: isWide ? null : const EdgeInsets.only(bottom: 30, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green.shade600,
      icon: Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.blue.shade600,
      icon: Icons.info_outline,
    );
  }
}
