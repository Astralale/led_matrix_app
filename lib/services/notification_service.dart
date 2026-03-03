import 'package:flutter/material.dart';

import '../config/constants.dart';

class NotificationService {
  NotificationService._();

  /// Clé à passer à `MaterialApp.scaffoldMessengerKey`.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void _show(
    String message, {
    required Color backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: duration,
        ),
      );
  }

  static void showSuccess(String message) {
    _show(
      message,
      backgroundColor: AppConstants.successColor,
      icon: Icons.check_circle_outline,
      duration: const Duration(seconds: 2),
    );
  }

  static void showWarning(String message) {
    _show(
      message,
      backgroundColor: AppConstants.warningColor,
      icon: Icons.warning_amber_outlined,
      duration: const Duration(seconds: 3),
    );
  }

  static void showError(String message) {
    _show(
      message,
      backgroundColor: AppConstants.dangerColor,
      icon: Icons.error_outline,
      duration: const Duration(seconds: 4),
    );
  }

  static void showInfo(String message) {
    _show(
      message,
      backgroundColor: AppConstants.accentColor,
      icon: Icons.info_outline,
      duration: const Duration(seconds: 2),
    );
  }
}
