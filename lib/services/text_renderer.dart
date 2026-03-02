// ============================================================================
// 📁 services/text_renderer.dart
// ============================================================================
// Service qui dessine du texte sur la matrice LED.
// Sépare la logique de rendu de l'interface utilisateur.
// ============================================================================

import '../models/led_matrix.dart';
import '../utils/bitmap_font.dart';
import '../config/constants.dart';

class TextRenderer {
  // Empêche l'instanciation
  TextRenderer._();

  // ============================================================================
  // DESSINER DU TEXTE SUR LA MATRICE
  // ============================================================================
  /// Dessine le texte sur la matrice avec la couleur spécifiée.
  /// Le texte est centré verticalement.
  ///
  /// [matrix] : la matrice à modifier
  /// [text] : le texte à afficher
  /// [colorIndex] : l'index de la couleur (0-9)
  /// [startX] : position X de départ (défaut: 1)
  /// [clearFirst] : effacer la matrice avant de dessiner (défaut: true)

  static void drawText(
    LedMatrix matrix,
    String text, {
    int colorIndex = 1,
    int startX = 1,
    bool clearFirst = true,
  }) {
    // Effacer si demandé
    if (clearFirst) {
      matrix.clear();
    }

    // Position de départ
    int cursorX = startX;

    // Centrer verticalement
    int startY = (AppConstants.matrixHeight - BitmapFont.charHeight) ~/ 2;

    // Parcourir chaque caractère
    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      if (char == ' ') {
        // Espace : avancer le curseur
        cursorX += BitmapFont.spaceWidth;
      } else {
        // Obtenir le motif du caractère
        final charPattern = BitmapFont.getCharacter(char);

        if (charPattern != null) {
          // Dessiner le caractère pixel par pixel
          _drawCharacter(matrix, charPattern, cursorX, startY, colorIndex);

          // Avancer le curseur
          cursorX += charPattern[0].length + BitmapFont.charSpacing;
        }
      }

      // Arrêter si on dépasse la matrice
      if (cursorX >= AppConstants.matrixWidth) {
        break;
      }
    }
  }

  // ============================================================================
  // DESSINER UN CARACTÈRE
  // ============================================================================

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

          // Vérifier les limites
          if (x < AppConstants.matrixWidth && y < AppConstants.matrixHeight) {
            matrix.setPixel(x, y, colorIndex);
          }
        }
      }
    }
  }

  // ============================================================================
  // VÉRIFIER SI LE TEXTE RENTRE DANS LA MATRICE
  // ============================================================================

  static bool textFits(String text, {int startX = 1}) {
    int totalWidth = BitmapFont.calculateTextWidth(text) + startX;
    return totalWidth <= AppConstants.matrixWidth;
  }

  // ============================================================================
  // OBTENIR LA LARGEUR DU TEXTE
  // ============================================================================

  static int getTextWidth(String text) {
    return BitmapFont.calculateTextWidth(text);
  }
}
