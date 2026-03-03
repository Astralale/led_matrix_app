import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../services/text_renderer.dart';
import '../widgets/matrix_preview.dart';
import '../widgets/color_palette.dart';
import 'draw_mode_screen.dart';

class TextModeScreen extends StatefulWidget {
  const TextModeScreen({super.key});

  @override
  State<TextModeScreen> createState() => _TextModeScreenState();
}

class _TextModeScreenState extends State<TextModeScreen> {
  final LedMatrix _matrix = LedMatrix();

  final TextEditingController _textController = TextEditingController();

  int _selectedColorIndex = 1;

  // Scroll animation
  Timer? _scrollTimer;
  int _scrollOffset = 0;
  String _currentText = '';
  bool _isScrolling = false;
  bool _scrollEnabled = false;
  static const int _scrollSpeedMs = 60;

  // Draw scroll
  List<List<int>>? _scrollSnapshot;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _applyText() {
    if (_textController.text.isEmpty) return;

    final text = _textController.text;
    _stopScrolling();
    _scrollSnapshot = null; // abandon le scroll dessin si actif

    if (_scrollEnabled) {
      // Scroll mode → start scrolling from the right
      _currentText = text;
      _scrollOffset = AppConstants.matrixWidth;
      _startScrolling();
    } else {
      // Static mode → center horizontally
      final centeredX =
          (AppConstants.matrixWidth - TextRenderer.getTextWidth(text)) ~/ 2;
      setState(() {
        TextRenderer.drawText(
          _matrix,
          text,
          colorIndex: _selectedColorIndex,
          startX: centeredX.clamp(0, AppConstants.matrixWidth - 1),
        );
      });
    }
  }

  void _startScrolling() {
    _isScrolling = true;
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: _scrollSpeedMs),
      (timer) {
        final textWidth = TextRenderer.getTextWidth(_currentText);
        setState(() {
          TextRenderer.drawText(
            _matrix,
            _currentText,
            colorIndex: _selectedColorIndex,
            startX: _scrollOffset,
          );
          _scrollOffset--;
          // Loop: restart from the right once the text is fully off-screen
          if (_scrollOffset + textWidth < 0) {
            _scrollOffset = AppConstants.matrixWidth;
          }
        });
      },
    );
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (_isScrolling) {
      setState(() => _isScrolling = false);
    }
  }

  void _stopScrollingAndReset() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSnapshot = null;
    setState(() {
      _isScrolling = false;
      _scrollEnabled = false;
    });
  }

  void _toggleScroll(bool value) {
    if (value) {
      setState(() => _scrollEnabled = true);
      // Si du texte est saisi, lancer le scroll texte (même si texte trop long)
      if (_textController.text.isNotEmpty) {
        _stopScrolling();
        _scrollSnapshot = null;
        _currentText = _textController.text;
        _scrollOffset = AppConstants.matrixWidth;
        _startScrolling();
      } else if (_matrix.litPixelCount > 0) {
        // Sinon, scroller le dessin courant
        _startDrawScroll();
      }
    } else {
      // Désactiver : restaurer le snapshot si dessin
      final snap = _scrollSnapshot;
      _stopScrolling();
      _scrollSnapshot = null;
      setState(() {
        _scrollEnabled = false;
        if (snap != null) {
          _matrix.updateFrom(snap);
        }
      });
    }
  }

  void _startDrawScroll() {
    _scrollSnapshot = _matrix.pixels.map((r) => List<int>.from(r)).toList();
    int offset = 0;
    _isScrolling = true;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: _scrollSpeedMs),
      (_) {
        offset++;
        final w = AppConstants.matrixWidth;
        final h = AppConstants.matrixHeight;
        final snap = _scrollSnapshot!;
        setState(() {
          for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
              _matrix.setPixel(x, y, snap[y][(x + offset) % w]);
            }
          }
        });
      },
    );
  }

  void _clearMatrix() {
    _stopScrollingAndReset();
    setState(() {
      _matrix.clear();
    });
  }

  void _displayHelp() {
    _stopScrollingAndReset();
    _textController.text = 'HELP';
    const helpColor = 1; // Rouge
    const text = 'HELP';
    final centeredX =
        (AppConstants.matrixWidth - TextRenderer.getTextWidth(text)) ~/ 2;
    setState(() {
      _matrix.clear();
      TextRenderer.drawText(
        _matrix,
        text,
        colorIndex: helpColor,
        startX: centeredX.clamp(0, AppConstants.matrixWidth - 1),
      );
    });
  }

  Future<void> _openDrawMode() async {
    _stopScrollingAndReset();
    final result = await Navigator.push<List<List<int>>>(
      context,
      MaterialPageRoute(
        builder: (context) => DrawModeScreen(initialMatrix: _matrix.pixels),
      ),
    );

    if (result != null) {
      setState(() {
        _matrix.updateFrom(result);
      });
      // Si le défilement est déjà activé, lancer le scroll dessin immédiatement
      if (_scrollEnabled) {
        _startDrawScroll();
      }
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMatrixPreview(),

          _buildTextField(),

          const SizedBox(height: 12),

          _buildColorSection(),

          const SizedBox(height: 8),

          _buildScrollToggle(),

          const SizedBox(height: 8),

          _buildHelpButton(),

          const SizedBox(height: 8),

          _buildActionButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppConstants.borderColor),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppConstants.accentColor.withOpacity(0.2),
              ),
            ),
            child: const Icon(
              Icons.grid_on,
              color: AppConstants.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Collection femmes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppConstants.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: _openDrawMode,
            icon: const Icon(Icons.brush, size: 16),
            label: const Text('Dessiner', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.borderColor,
              foregroundColor: AppConstants.accentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: GestureDetector(
        onTap: () => _toggleScroll(!_scrollEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _scrollEnabled
                ? AppConstants.accentColor.withOpacity(0.06)
                : AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            border: Border.all(
              color: _scrollEnabled
                  ? AppConstants.accentColor.withOpacity(0.5)
                  : AppConstants.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.animation,
                size: 18,
                color: _scrollEnabled
                    ? AppConstants.accentColor
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Text(
                'Défilement',
                style: TextStyle(
                  fontSize: 13,
                  color: _scrollEnabled
                      ? AppConstants.accentColor
                      : const Color(0xFF5A3A3A),
                  fontWeight: _scrollEnabled
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              const Spacer(),
              Switch(
                value: _scrollEnabled,
                onChanged: _toggleScroll,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixPreview() {
    return Flexible(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3D1010),
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            border: Border.all(color: AppConstants.borderColor, width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.10),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConstants.defaultRadius - 2),
                  ),
                ),
                child: const Text(
                  'PANNEAU LED  ·  32 × 16',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.backgroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppConstants.defaultRadius - 2),
                  ),
                  child: MatrixPreview(matrix: _matrix, showGlow: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: TextField(
        controller: _textController,
        style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Entrez votre texte...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          filled: true,
          fillColor: AppConstants.surfaceColor,
          prefixIcon: const Icon(
            Icons.text_fields,
            color: AppConstants.accentColor,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
            onPressed: () => _textController.clear(),
          ),
        ),
        onSubmitted: (_) => _applyText(),
      ),
    );
  }

  Widget _buildColorSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couleur du texte :',
            style: TextStyle(
              color: Color(0xFF5A3A3A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          HorizontalColorPalette(
            selectedColorIndex: _selectedColorIndex,
            onColorSelected: (index) {
              setState(() => _selectedColorIndex = index);
            },
            availableColors: AppConstants.textModeColors,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _displayHelp,
          icon: const Icon(Icons.warning_amber_rounded, size: 22),
          label: const Text(
            'Urgence',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.defaultPadding,
        right: AppConstants.defaultPadding,
        bottom: AppConstants.defaultPadding,
      ),
      child: Row(
        children: [
          // Bouton Appliquer avec dégradé
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _applyText,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Appliquer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton Effacer
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _clearMatrix,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Effacer', style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.dangerColor,
                  side: BorderSide(
                    color: AppConstants.dangerColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
