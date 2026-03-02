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
    setState(() {
      _isScrolling = false;
      _scrollEnabled = false;
    });
  }

  void _clearMatrix() {
    _stopScrollingAndReset();
    setState(() {
      _matrix.clear();
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

          _buildActionButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), AppConstants.surfaceColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppConstants.accentColor,
                AppConstants.secondaryAccent,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppConstants.accentColor,
                  AppConstants.secondaryAccent,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.accentColor.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.grid_on, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppConstants.accentColor, AppConstants.secondaryAccent],
            ).createShader(bounds),
            child: const Text(
              'LED Matrix',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 1,
              ),
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
              backgroundColor: AppConstants.successColor.withOpacity(0.85),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        onTap: () => setState(() => _scrollEnabled = !_scrollEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _scrollEnabled
                ? AppConstants.secondaryAccent.withOpacity(0.18)
                : AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            border: Border.all(
              color: _scrollEnabled
                  ? AppConstants.secondaryAccent
                  : AppConstants.borderColor,
              width: _scrollEnabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.animation,
                size: 18,
                color: _scrollEnabled
                    ? AppConstants.secondaryAccent
                    : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                'Défilement',
                style: TextStyle(
                  fontSize: 13,
                  color: _scrollEnabled
                      ? AppConstants.secondaryAccent
                      : Colors.white54,
                  fontWeight: _scrollEnabled
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const Spacer(),
              Switch(
                value: _scrollEnabled,
                onChanged: (v) => setState(() => _scrollEnabled = v),
                activeColor: AppConstants.secondaryAccent,
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
            color: const Color(0xFF080B0F),
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            border: Border.all(
              color: AppConstants.accentColor.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.accentColor.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: AppConstants.secondaryAccent.withOpacity(0.06),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConstants.defaultRadius - 2),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppConstants.accentColor.withOpacity(0.2),
                    ),
                  ),
                ),
                child: const Text(
                  'PANNEAU LED  ·  32 × 16',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
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
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Entrez votre texte...',
          hintStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: AppConstants.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(
              color: AppConstants.accentColor,
              width: 2,
            ),
          ),
          prefixIcon: const Icon(
            Icons.text_fields,
            color: AppConstants.accentColor,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
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
            style: TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Row(
        children: [
          // Bouton Appliquer avec dégradé
          Expanded(
            flex: 2,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppConstants.accentColor,
                    AppConstants.secondaryAccent,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.accentColor.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _applyText,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Appliquer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultRadius,
                    ),
                  ),
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
                    color: AppConstants.dangerColor.withOpacity(0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultRadius,
                    ),
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
