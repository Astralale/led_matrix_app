import 'package:flutter/material.dart';

import '../config/constants.dart';
import 'panel_header.dart';

class MatrixPanel extends StatelessWidget {
  final Widget child;

  const MatrixPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3D1010),
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor, width: 1),
      ),
      child: Column(
        children: [
          const PanelHeader(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
