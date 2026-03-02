// ============================================================================
// 📁 widgets/matrix_preview.dart
// ============================================================================
// Widget réutilisable pour afficher un aperçu de la matrice LED.
// Peut être utilisé en mode mini (texte) ou plein écran (dessin).
// ============================================================================

import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';

class MatrixPreview extends StatelessWidget {
  final LedMatrix matrix;
  final double? cellSize; // Si null, calcul automatique
  final bool showGlow; // Effet de lueur sur les LEDs allumées
  final Function(int x, int y)? onPixelTap; // Callback quand on tape un pixel

  const MatrixPreview({
    super.key,
    required this.matrix,
    this.cellSize,
    this.showGlow = true,
    this.onPixelTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculer la taille des cellules
        final calculatedCellSize = cellSize ?? _calculateCellSize(constraints);
        final cellMargin = calculatedCellSize * 0.04;
        final actualCellSize = calculatedCellSize - (cellMargin * 2);

        return Center(child: _buildGrid(actualCellSize, cellMargin));
      },
    );
  }

  // ============================================================================
  // CALCUL DE LA TAILLE DES CELLULES
  // ============================================================================

  double _calculateCellSize(BoxConstraints constraints) {
    double availableWidth = constraints.maxWidth - 20;
    double availableHeight = constraints.maxHeight - 20;

    double cellWidth = availableWidth / AppConstants.matrixWidth;
    double cellHeight = availableHeight / AppConstants.matrixHeight;

    // Prendre la plus petite pour garder des cellules carrées
    double size = cellWidth < cellHeight ? cellWidth : cellHeight;

    // Limites min/max
    return size.clamp(2.0, 20.0);
  }

  // ============================================================================
  // CONSTRUCTION DE LA GRILLE
  // ============================================================================

  Widget _buildGrid(double cellSize, double cellMargin) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(AppConstants.matrixHeight, (y) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(AppConstants.matrixWidth, (x) {
            return _buildCell(x, y, cellSize, cellMargin);
          }),
        );
      }),
    );
  }

  // ============================================================================
  // CONSTRUCTION D'UNE CELLULE (LED)
  // ============================================================================

  Widget _buildCell(int x, int y, double cellSize, double cellMargin) {
    final colorIndex = matrix.getPixel(x, y);
    final isLit = colorIndex != 0;
    final color = AppConstants.colorPalette[colorIndex];

    Widget cell = Container(
      width: cellSize,
      height: cellSize,
      margin: EdgeInsets.all(cellMargin),
      decoration: BoxDecoration(
        color: isLit ? color : const Color(0xFF141C24),
        borderRadius: BorderRadius.circular(cellSize * 0.25),
        boxShadow: (isLit && showGlow)
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: cellSize * 0.3,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );

    // Si on a un callback, rendre la cellule interactive
    if (onPixelTap != null) {
      return GestureDetector(onTap: () => onPixelTap!(x, y), child: cell);
    }

    return cell;
  }
}

// ============================================================================
// WIDGET INTERACTIF POUR LE DESSIN
// ============================================================================
// Version spéciale avec support du drag pour dessiner

class InteractiveMatrixPreview extends StatefulWidget {
  final LedMatrix matrix;
  final int selectedColorIndex;
  final bool isDrawMode; // true = dessiner, false = effacer
  final VoidCallback onMatrixChanged;

  const InteractiveMatrixPreview({
    super.key,
    required this.matrix,
    required this.selectedColorIndex,
    required this.isDrawMode,
    required this.onMatrixChanged,
  });

  @override
  State<InteractiveMatrixPreview> createState() =>
      _InteractiveMatrixPreviewState();
}

class _InteractiveMatrixPreviewState extends State<InteractiveMatrixPreview> {
  bool _isDrawing = false;

  void _handleInteraction(
    Offset localPosition,
    double cellSize,
    double cellMargin,
  ) {
    double totalCellSize = cellSize + (cellMargin * 2);

    int x = (localPosition.dx / totalCellSize).floor();
    int y = (localPosition.dy / totalCellSize).floor();

    if (x >= 0 &&
        x < AppConstants.matrixWidth &&
        y >= 0 &&
        y < AppConstants.matrixHeight) {
      int colorToSet = widget.isDrawMode ? widget.selectedColorIndex : 0;

      if (widget.matrix.getPixel(x, y) != colorToSet) {
        widget.matrix.setPixel(x, y, colorToSet);
        widget.onMatrixChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculer les dimensions
        double availableWidth = constraints.maxWidth - 16;
        double availableHeight = constraints.maxHeight - 16;

        double cellWidth = availableWidth / AppConstants.matrixWidth;
        double cellHeight = availableHeight / AppConstants.matrixHeight;
        double cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

        double cellMargin = cellSize * 0.04;
        double actualCellSize = cellSize - (cellMargin * 2);

        double totalWidth =
            AppConstants.matrixWidth * (actualCellSize + cellMargin * 2);
        double totalHeight =
            AppConstants.matrixHeight * (actualCellSize + cellMargin * 2);

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              _handleInteraction(
                details.localPosition,
                actualCellSize,
                cellMargin,
              );
            },
            onPanStart: (details) {
              _isDrawing = true;
              _handleInteraction(
                details.localPosition,
                actualCellSize,
                cellMargin,
              );
            },
            onPanUpdate: (details) {
              if (_isDrawing) {
                _handleInteraction(
                  details.localPosition,
                  actualCellSize,
                  cellMargin,
                );
              }
            },
            onPanEnd: (_) => _isDrawing = false,
            child: Container(
              width: totalWidth,
              height: totalHeight,
              color: Colors.transparent,
              child: _buildGrid(actualCellSize, cellMargin),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(double cellSize, double cellMargin) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(AppConstants.matrixHeight, (y) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(AppConstants.matrixWidth, (x) {
            return _buildCell(x, y, cellSize, cellMargin);
          }),
        );
      }),
    );
  }

  Widget _buildCell(int x, int y, double cellSize, double cellMargin) {
    final colorIndex = widget.matrix.getPixel(x, y);
    final isLit = colorIndex != 0;
    final color = AppConstants.colorPalette[colorIndex];

    return Container(
      width: cellSize,
      height: cellSize,
      margin: EdgeInsets.all(cellMargin),
      decoration: BoxDecoration(
        color: isLit ? color : const Color(0xFF141C24),
        borderRadius: BorderRadius.circular(cellSize * 0.25),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: cellSize * 0.3,
                ),
              ]
            : null,
      ),
    );
  }
}
