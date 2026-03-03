import 'package:flutter/material.dart';

import '../config/constants.dart';

class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: AppConstants.accentColor.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.defaultRadius - 2),
        ),
      ),
      child: const Text(
        'PANNEAU LED  \u00b7  32 \u00d7 16',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppConstants.backgroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
