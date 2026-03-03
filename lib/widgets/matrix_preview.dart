import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/led_matrix.dart';

class MatrixPreview extends StatelessWidget {
  final LedMatrix matrix;
  final bool showGlow;

  const MatrixPreview({super.key, required this.matrix, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MatrixPainter(matrix: matrix, showGlow: showGlow),
      ),
    );
  }
}

class InteractiveMatrixPreview extends StatefulWidget {
  final LedMatrix matrix;
  final int selectedColorIndex;
  final bool isDrawMode;
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

  void _handleInteraction(Offset localPosition, Size size) {
    final metrics = _CellMetrics.fromSize(size);
    final x = ((localPosition.dx - metrics.offsetX) / metrics.cellSize).floor();
    final y = ((localPosition.dy - metrics.offsetY) / metrics.cellSize).floor();

    if (x >= 0 &&
        x < AppConstants.matrixWidth &&
        y >= 0 &&
        y < AppConstants.matrixHeight) {
      final colorToSet = widget.isDrawMode ? widget.selectedColorIndex : 0;
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
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) => _handleInteraction(d.localPosition, size),
          onPanStart: (d) {
            _isDrawing = true;
            _handleInteraction(d.localPosition, size);
          },
          onPanUpdate: (d) {
            if (_isDrawing) {
              _handleInteraction(d.localPosition, size);
            }
          },
          onPanEnd: (_) => _isDrawing = false,
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _MatrixPainter(matrix: widget.matrix, showGlow: true),
            ),
          ),
        );
      },
    );
  }
}

class _CellMetrics {
  final double cellSize;
  final double offsetX;
  final double offsetY;

  const _CellMetrics({
    required this.cellSize,
    required this.offsetX,
    required this.offsetY,
  });

  factory _CellMetrics.fromSize(Size size) {
    final cellWidth = size.width / AppConstants.matrixWidth;
    final cellHeight = size.height / AppConstants.matrixHeight;
    final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
    final totalWidth = AppConstants.matrixWidth * cellSize;
    final totalHeight = AppConstants.matrixHeight * cellSize;
    return _CellMetrics(
      cellSize: cellSize,
      offsetX: (size.width - totalWidth) / 2,
      offsetY: (size.height - totalHeight) / 2,
    );
  }
}

class _MatrixPainter extends CustomPainter {
  final LedMatrix matrix;
  final bool showGlow;

  _MatrixPainter({required this.matrix, this.showGlow = true});

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = _CellMetrics.fromSize(size);
    final margin = metrics.cellSize * 0.04;
    final actualSize = metrics.cellSize - (margin * 2);
    final borderRadius = actualSize * 0.25;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < AppConstants.matrixHeight; y++) {
      for (int x = 0; x < AppConstants.matrixWidth; x++) {
        final colorIndex = matrix.getPixel(x, y);
        final isLit = colorIndex != 0;
        final color = isLit
            ? AppConstants.colorPalette[colorIndex]
            : const Color(0xFF5C1F1F);

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            metrics.offsetX + x * metrics.cellSize + margin,
            metrics.offsetY + y * metrics.cellSize + margin,
            actualSize,
            actualSize,
          ),
          Radius.circular(borderRadius),
        );

        if (isLit && showGlow) {
          paint
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, actualSize * 0.15);
          canvas.drawRRect(rect, paint);
          paint.maskFilter = null;
        }

        paint.color = color;
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter oldDelegate) => true;
}
