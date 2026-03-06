import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/constants.dart';

class ImageResizer {
  ImageResizer._();

  static const int matrixWidth = 32;
  static const int matrixHeight = 16;

  static Future<List<List<int>>> imageToMatrix(Uint8List imageBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: matrixWidth,
      targetHeight: matrixHeight,
    );

    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    final ByteData? byteData = await frameInfo.image.toByteData(
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

        final int r = pixels[pixelIndex];
        final int g = pixels[pixelIndex + 1];
        final int b = pixels[pixelIndex + 2];
        final int a = pixels[pixelIndex + 3];

        // Si le pixel est très transparent, on l'éteint
        if (a < 40) {
          matrix[y][x] = 0;
          continue;
        }

        matrix[y][x] = _findClosestPaletteIndex(r, g, b);
      }
    }

    return matrix;
  }

  static Future<Uint8List> resizeAndQuantizeToPng(Uint8List imageBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: matrixWidth,
      targetHeight: matrixHeight,
    );

    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw StateError('Unable to decode image to RGBA format.');
    }

    final Uint8List pixels = byteData.buffer.asUint8List();
    final Uint8List output = Uint8List(pixels.length);

    for (int i = 0; i < pixels.length; i += 4) {
      final int r = pixels[i];
      final int g = pixels[i + 1];
      final int b = pixels[i + 2];
      final int a = pixels[i + 3];

      if (a < 40) {
        output[i] = 0;
        output[i + 1] = 0;
        output[i + 2] = 0;
        output[i + 3] = 0;
        continue;
      }

      final int paletteIndex = _findClosestPaletteIndex(r, g, b);
      final Color c = AppConstants.colorPalette[paletteIndex];

      output[i] = c.red;
      output[i + 1] = c.green;
      output[i + 2] = c.blue;
      output[i + 3] = 255;
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

    final ui.Codec pngCodec = await descriptor.instantiateCodec();
    final ui.FrameInfo pngFrame = await pngCodec.getNextFrame();
    final ByteData? pngBytes = await pngFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (pngBytes == null) {
      throw StateError('Unable to encode quantized image to PNG.');
    }

    return pngBytes.buffer.asUint8List();
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
