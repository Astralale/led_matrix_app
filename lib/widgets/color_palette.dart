// ============================================================================
// 📁 widgets/color_palette.dart
// ============================================================================
// Widget réutilisable pour sélectionner une couleur.
// Deux variantes : horizontale (texte) et grille (dessin).
// ============================================================================

import 'package:flutter/material.dart';
import '../config/constants.dart';

// ============================================================================
// 🎨 PALETTE HORIZONTALE (Mode Texte)
// ============================================================================

class HorizontalColorPalette extends StatelessWidget {
  final int selectedColorIndex;
  final ValueChanged<int> onColorSelected;
  final List<int>? availableColors; // Si null, toutes les couleurs
  final double itemSize;

  const HorizontalColorPalette({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
    this.availableColors,
    this.itemSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final colors = availableColors ?? List.generate(10, (i) => i);

    return SizedBox(
      height: itemSize,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final colorIndex = colors[index];
          final isSelected = selectedColorIndex == colorIndex;

          return GestureDetector(
            onTap: () => onColorSelected(colorIndex),
            child: Container(
              width: itemSize,
              height: itemSize,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppConstants.colorPalette[colorIndex],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected && colorIndex != 0
                    ? [
                  BoxShadow(
                    color: AppConstants.colorPalette[colorIndex].withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
                    : null,
              ),
              child: _buildCellContent(colorIndex, isSelected),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildCellContent(int colorIndex, bool isSelected) {
    if (colorIndex == 0) {
      return Icon(
        Icons.not_interested,
        color: Colors.grey.shade600,
        size: itemSize * 0.5,
      );
    }
    if (isSelected) {
      return Icon(
        Icons.check,
        color: colorIndex == 7 ? Colors.black : Colors.white,
        size: itemSize * 0.45,
      );
    }
    return null;
  }
}

// ============================================================================
// 🎨 PALETTE EN GRILLE (Mode Dessin)
// ============================================================================

class GridColorPalette extends StatelessWidget {
  final int selectedColorIndex;
  final ValueChanged<int> onColorSelected;
  final int crossAxisCount;
  final bool useExtendedPalette;

  const GridColorPalette({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
    this.crossAxisCount = 2,
    this.useExtendedPalette = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppConstants.colorPalette;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: palette.length,
      itemBuilder: (context, index) {
        final isSelected = selectedColorIndex == index;

        return GestureDetector(
          onTap: () => onColorSelected(index),
          child: Container(
            decoration: BoxDecoration(
              color: palette[index],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected && index != 0
                  ? [
                BoxShadow(
                  color: palette[index].withOpacity(0.5),
                  blurRadius: 4,
                ),
              ]
                  : null,
            ),
            child: Center(
              child: _buildCellContent(index, isSelected),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildCellContent(int index, bool isSelected) {
    if (index == 0) {
      return Icon(
        Icons.not_interested,
        color: Colors.grey.shade600,
        size: 12,
      );
    }
    if (isSelected) {
      return Icon(
        Icons.check,
        color: index == 7 ? Colors.black : Colors.white,
        size: 12,
      );
    }
    return null;
  }
}