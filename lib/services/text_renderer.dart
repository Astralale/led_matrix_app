import '../models/led_matrix.dart';
import '../utils/bitmap_font.dart';
import '../config/constants.dart';

class TextRenderer {
  TextRenderer._();

  static void drawText(
    LedMatrix matrix,
    String text, {
    int colorIndex = 1,
    int startX = 1,
    bool clearFirst = true,
  }) {
    if (clearFirst) {
      matrix.clear();
    }

    int cursorX = startX;

    int startY = (AppConstants.matrixHeight - BitmapFont.charHeight) ~/ 2;

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      if (char == ' ') {
        cursorX += BitmapFont.spaceWidth;
      } else {
        final charPattern = BitmapFont.getCharacter(char);

        if (charPattern != null) {
          _drawCharacter(matrix, charPattern, cursorX, startY, colorIndex);
          cursorX += charPattern[0].length + BitmapFont.charSpacing;
        }
      }

      if (cursorX >= AppConstants.matrixWidth) {
        break;
      }
    }
  }

  static void _drawCharacter(
    LedMatrix matrix,
    List<List<int>> pattern,
    int startX,
    int startY,
    int colorIndex,
  ) {
    for (int row = 0; row < pattern.length; row++) {
      for (int col = 0; col < pattern[row].length; col++) {
        if (pattern[row][col] == 1) {
          int x = startX + col;
          int y = startY + row;

          if (x < AppConstants.matrixWidth && y < AppConstants.matrixHeight) {
            matrix.setPixel(x, y, colorIndex);
          }
        }
      }
    }
  }

  static bool textFits(String text, {int startX = 1}) {
    int totalWidth = BitmapFont.calculateTextWidth(text) + startX;
    return totalWidth <= AppConstants.matrixWidth;
  }

  static int getTextWidth(String text) => BitmapFont.calculateTextWidth(text);
}
