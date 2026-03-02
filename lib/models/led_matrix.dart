import '../config/constants.dart';

class LedMatrix {
  List<List<int>> _pixels;

  final int width;
  final int height;

  LedMatrix({
    this.width = AppConstants.matrixWidth,
    this.height = AppConstants.matrixHeight,
  }) : _pixels = _createEmptyMatrix(width, height);

  LedMatrix.fromPixels(this._pixels)
    : width = _pixels.isNotEmpty ? _pixels[0].length : AppConstants.matrixWidth,
      height = _pixels.length;

  static List<List<int>> _createEmptyMatrix(int width, int height) {
    return List.generate(height, (_) => List.generate(width, (_) => 0));
  }

  List<List<int>> get pixels => _pixels;

  int getPixel(int x, int y) {
    if (_isValidPosition(x, y)) {
      return _pixels[y][x];
    }
    return 0;
  }

  int get litPixelCount {
    int count = 0;
    for (var row in _pixels) {
      for (var pixel in row) {
        if (pixel != 0) count++;
      }
    }
    return count;
  }

  void setPixel(int x, int y, int colorIndex) {
    if (_isValidPosition(x, y)) {
      _pixels[y][x] = colorIndex.clamp(0, 9);
    }
  }

  void clear() {
    _pixels = _createEmptyMatrix(width, height);
  }

  void fill(int colorIndex) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        _pixels[y][x] = colorIndex.clamp(0, 9);
      }
    }
  }

  bool _isValidPosition(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  LedMatrix copy() {
    List<List<int>> copiedPixels = _pixels
        .map((row) => List<int>.from(row))
        .toList();
    return LedMatrix.fromPixels(copiedPixels);
  }

  void updateFrom(List<List<int>> newPixels) {
    if (newPixels.length == height && newPixels[0].length == width) {
      _pixels = newPixels.map((row) => List<int>.from(row)).toList();
    }
  }
}
