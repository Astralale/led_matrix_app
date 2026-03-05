import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageResizer {
	static const Size matrixSize = Size(32, 16);

	static Future<Uint8List> resizeToMatrix32x16(
		Uint8List imageBytes,
	) async {
		final ui.Codec codec = await ui.instantiateImageCodec(
			imageBytes,
			targetWidth: matrixSize.width.toInt(),
			targetHeight: matrixSize.height.toInt(),
		);
		final ui.FrameInfo frameInfo = await codec.getNextFrame();
		final ByteData? byteData = await frameInfo.image.toByteData(
			format: ui.ImageByteFormat.png,
		);

		if (byteData == null) {
			throw StateError('Unable to resize image to 32x16 matrix format.');
		}

		return byteData.buffer.asUint8List();
	}
}
