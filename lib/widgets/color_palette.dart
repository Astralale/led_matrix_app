import 'package:flutter/material.dart';

import '../config/constants.dart';

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: itemSize,
              height: itemSize,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppConstants.colorPalette[colorIndex],
                border: Border.all(
                  color: isSelected
                      ? AppConstants.accentColor
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected && colorIndex != 0
                    ? [
                        BoxShadow(
                          color: AppConstants.colorPalette[colorIndex]
                              .withValues(alpha: 0.7),
                          blurRadius: 10,
                          spreadRadius: 2,
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
              color: index == 0 ? AppConstants.surfaceColor : palette[index],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? AppConstants.accentColor
                    : index == 0
                    ? AppConstants.borderColor
                    : AppConstants.borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected && index != 0
                  ? [
                      BoxShadow(
                        color: palette[index].withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Center(child: _buildCellContent(index, isSelected)),
          ),
        );
      },
    );
  }

  Widget? _buildCellContent(int index, bool isSelected) {
    if (index == 0) {
      return Icon(
        Icons.auto_fix_high,
        color: isSelected ? AppConstants.accentColor : Colors.grey.shade500,
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
