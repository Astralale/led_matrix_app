import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/constants.dart';

enum MatrixImageFit { contain, cover, stretch }

class ImageResizer {
  ImageResizer._();

  static const int matrixWidth = 32;
  static const int matrixHeight = 16;

  static Future<List<List<int>>> imageToMatrix(
    Uint8List imageBytes, {
    MatrixImageFit fit = MatrixImageFit.contain,
    int alphaThreshold = 40,
    int darkThreshold = 18,
    bool turnNearBlackToOff = true,
    double contrast = 1.08,
    double saturation = 1.10,
  }) async {
    final ui.Image image = await _decodeImage(imageBytes);

    final ui.Image rendered = await _renderToMatrixImage(image, fit: fit);

    final ByteData? byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw StateError('Unable to decode image to RGBA format.');
    }

    final Uint8List pixels = byteData.buffer.asUint8List();

    final List<List<int>> matrix = List.generate(
      matrixHeight,
      (_) => List.filled(matrixWidth, 0),
    );

    for (int y = 0; y < matrixHeight; y++) {
      for (int x = 0; x < matrixWidth; x++) {
        final int pixelIndex = (y * matrixWidth + x) * 4;

        int r = pixels[pixelIndex];
        int g = pixels[pixelIndex + 1];
        int b = pixels[pixelIndex + 2];
        final int a = pixels[pixelIndex + 3];

        if (a < alphaThreshold) {
          matrix[y][x] = 0;
          continue;
        }

        final _Rgb enhanced = _enhanceColor(
          r,
          g,
          b,
          contrast: contrast,
          saturation: saturation,
        );

        r = enhanced.r;
        g = enhanced.g;
        b = enhanced.b;

        if (turnNearBlackToOff && _isNearBlack(r, g, b, darkThreshold)) {
          matrix[y][x] = 0;
          continue;
        }

        matrix[y][x] = _findClosestPaletteIndex(r, g, b);
      }
    }

    return matrix;
  }

  static Future<Uint8List> resizeAndQuantizeToPng(
    Uint8List imageBytes, {
    MatrixImageFit fit = MatrixImageFit.contain,
    int alphaThreshold = 40,
    int darkThreshold = 18,
    bool turnNearBlackToOff = true,
    double contrast = 1.08,
    double saturation = 1.10,
  }) async {
    final List<List<int>> matrix = await ImageResizer.imageToMatrix(
      imageBytes,
      fit: fit,
      alphaThreshold: alphaThreshold,
      darkThreshold: darkThreshold,
      turnNearBlackToOff: turnNearBlackToOff,
      contrast: contrast,
      saturation: saturation,
    );

    final Uint8List output = Uint8List(matrixWidth * matrixHeight * 4);

    int i = 0;
    for (int y = 0; y < matrixHeight; y++) {
      for (int x = 0; x < matrixWidth; x++) {
        final int paletteIndex = matrix[y][x];
        final Color c = AppConstants.colorPalette[paletteIndex];

        output[i] = c.red;
        output[i + 1] = c.green;
        output[i + 2] = c.blue;
        output[i + 3] = paletteIndex == 0 ? 0 : 255;
        i += 4;
      }
    }

    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      output,
    );

    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: matrixWidth,
      height: matrixHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );

    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    final ByteData? pngBytes = await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (pngBytes == null) {
      throw StateError('Unable to encode quantized image to PNG.');
    }

    return pngBytes.buffer.asUint8List();
  }

  static Future<ui.Image> _decodeImage(Uint8List imageBytes) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      imageBytes,
    );
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
      buffer,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  static Future<ui.Image> _renderToMatrixImage(
    ui.Image source, {
    required MatrixImageFit fit,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.medium;

    final Size dstSize = Size(matrixWidth.toDouble(), matrixHeight.toDouble());

    final Rect dstRect = Offset.zero & dstSize;
    final Rect srcRect = _computeSourceRect(source, fit);
    final Rect drawRect = _computeDestinationRect(source, fit);

    canvas.drawColor(Colors.transparent, BlendMode.clear);

    if (fit == MatrixImageFit.stretch) {
      canvas.drawImageRect(source, srcRect, dstRect, paint);
    } else {
      canvas.drawImageRect(source, srcRect, drawRect, paint);
    }

    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(matrixWidth, matrixHeight);
  }

  static Rect _computeSourceRect(ui.Image image, MatrixImageFit fit) {
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    if (fit != MatrixImageFit.cover) {
      return Rect.fromLTWH(0, 0, srcW, srcH);
    }

    const double dstRatio = matrixWidth / matrixHeight;
    final double srcRatio = srcW / srcH;

    if (srcRatio > dstRatio) {
      final double newWidth = srcH * dstRatio;
      final double left = (srcW - newWidth) / 2;
      return Rect.fromLTWH(left, 0, newWidth, srcH);
    } else {
      final double newHeight = srcW / dstRatio;
      final double top = (srcH - newHeight) / 2;
      return Rect.fromLTWH(0, top, srcW, newHeight);
    }
  }

  static Rect _computeDestinationRect(ui.Image image, MatrixImageFit fit) {
    final double dstW = matrixWidth.toDouble();
    final double dstH = matrixHeight.toDouble();

    if (fit == MatrixImageFit.stretch || fit == MatrixImageFit.cover) {
      return Rect.fromLTWH(0, 0, dstW, dstH);
    }

    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    final double scale = math.min(dstW / srcW, dstH / srcH);
    final double drawW = srcW * scale;
    final double drawH = srcH * scale;
    final double dx = (dstW - drawW) / 2;
    final double dy = (dstH - drawH) / 2;

    return Rect.fromLTWH(dx, dy, drawW, drawH);
  }

  static _Rgb _enhanceColor(
    int r,
    int g,
    int b, {
    required double contrast,
    required double saturation,
  }) {
    double rf = r.toDouble();
    double gf = g.toDouble();
    double bf = b.toDouble();

    rf = ((rf - 128.0) * contrast + 128.0);
    gf = ((gf - 128.0) * contrast + 128.0);
    bf = ((bf - 128.0) * contrast + 128.0);

    final double gray = 0.299 * rf + 0.587 * gf + 0.114 * bf;

    rf = gray + (rf - gray) * saturation;
    gf = gray + (gf - gray) * saturation;
    bf = gray + (bf - gray) * saturation;

    return _Rgb(_clamp255(rf), _clamp255(gf), _clamp255(bf));
  }

  static int _clamp255(double value) {
    return value.clamp(0, 255).round();
  }

  static bool _isNearBlack(int r, int g, int b, int threshold) {
    final int maxChannel = math.max(r, math.max(g, b));
    return maxChannel <= threshold;
  }

  static int _findClosestPaletteIndex(int r, int g, int b) {
    int bestIndex = 1;
    double bestDistance = double.infinity;

    for (int i = 1; i < AppConstants.colorPalette.length; i++) {
      final Color color = AppConstants.colorPalette[i];

      final double distance = _colorDistance(
        r.toDouble(),
        g.toDouble(),
        b.toDouble(),
        color.red.toDouble(),
        color.green.toDouble(),
        color.blue.toDouble(),
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  static double _colorDistance(
    double r1,
    double g1,
    double b1,
    double r2,
    double g2,
    double b2,
  ) {
    final double rMean = (r1 + r2) / 2.0;
    final double r = r1 - r2;
    final double g = g1 - g2;
    final double b = b1 - b2;

    return math.sqrt(
      ((2 + rMean / 256) * r * r) +
          (4 * g * g) +
          ((2 + (255 - rMean) / 256) * b * b),
    );
  }
}

class _Rgb {
  final int r;
  final int g;
  final int b;

  const _Rgb(this.r, this.g, this.b);
}
