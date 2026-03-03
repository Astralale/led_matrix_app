import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../services/text_renderer.dart';
import '../widgets/matrix_preview.dart';
import '../widgets/color_palette.dart';
import 'draw_mode_screen.dart';
import 'settings_screen.dart';
import '../services/ble_service.dart';

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
  int _scrollSpeedMs = 60;

  // Draw scroll
  List<List<int>>? _scrollSnapshot;

  // Blink animation
  Timer? _blinkTimer;
  bool _blinkEnabled = false;
  bool _blinkVisible = true;
  List<List<int>>? _blinkSnapshot;
  static const int _blinkIntervalMs = 500;

  String _emergencyMessage = 'HELP';
  int _brightness = 60;

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
    _blinkTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _sendCurrentMatrix() {
    BleService.instance.sendMatrix(_matrix.pixels);
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
      _sendCurrentMatrix();
    }
  }

  void _startScrolling() {
    _isScrolling = true;
    _scrollTimer = Timer.periodic(Duration(milliseconds: _scrollSpeedMs), (
      timer,
    ) {
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
      _sendCurrentMatrix();
    });
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
    _scrollTimer = Timer.periodic(Duration(milliseconds: _scrollSpeedMs), (_) {
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
      _sendCurrentMatrix();
    });
  }

  void _clearMatrix() {
    _stopScrollingAndReset();
    _stopBlinking();
    setState(() {
      _matrix.clear();
    });
    _sendCurrentMatrix();
  }

  void _displayHelp() {
    _stopScrollingAndReset();
    _stopBlinking();
    _textController.text = _emergencyMessage.toLowerCase();
    const helpColor = 1;
    final text = _emergencyMessage.toUpperCase();
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
    _sendCurrentMatrix();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          emergencyMessage: _emergencyMessage,
          scrollSpeedMs: _scrollSpeedMs,
          brightness: _brightness,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        final msg = result['emergencyMessage'] as String?;
        if (msg != null && msg.isNotEmpty) {
          _emergencyMessage = msg.toUpperCase();
        }
        final speed = result['scrollSpeedMs'] as int?;
        if (speed != null) {
          _scrollSpeedMs = speed;
          if (_isScrolling) {
            _restartActiveScroll();
          }
        }
        final brightness = result['brightness'] as int?;
        if (brightness != null) {
          _brightness = brightness;
        }
      });
    }
  }

  void _restartActiveScroll() {
    if (_scrollSnapshot != null) {
      _stopScrolling();
      _startDrawScroll();
    } else if (_currentText.isNotEmpty) {
      _stopScrolling();
      _startScrolling();
    }
  }

  void _toggleBlink(bool value) {
    if (value) {
      _blinkSnapshot = _matrix.pixels.map((r) => List<int>.from(r)).toList();
      _blinkVisible = true;
      setState(() => _blinkEnabled = true);
      _blinkTimer?.cancel();
      _blinkTimer = Timer.periodic(
        const Duration(milliseconds: _blinkIntervalMs),
        (_) {
          setState(() {
            _blinkVisible = !_blinkVisible;
            if (_blinkVisible) {
              _matrix.updateFrom(
                _blinkSnapshot!.map((r) => List<int>.from(r)).toList(),
              );
            } else {
              _matrix.clear();
            }
          });
          _sendCurrentMatrix();
        },
      );
    } else {
      _stopBlinking();
      if (_blinkSnapshot != null) {
        setState(() {
          _matrix.updateFrom(_blinkSnapshot!);
        });
        _blinkSnapshot = null;
        _sendCurrentMatrix();
      }
    }
  }

  void _stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (_blinkEnabled) {
      setState(() {
        _blinkEnabled = false;
        _blinkVisible = true;
      });
    }
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

          const SizedBox(height: 10),

          _buildColorSection(),

          const SizedBox(height: 10),

          _buildEffectToggles(),

          const SizedBox(height: 10),

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
          padding: const EdgeInsets.only(right: 4),
          child: ElevatedButton(
            onPressed: _displayHelp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.dangerColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
              ),
            ),
            child: const Icon(Icons.warning_amber_rounded, size: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ElevatedButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Paramètres', style: TextStyle(fontSize: 13)),
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

  Widget _buildEffectToggles() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEffectButton(
              icon: Icons.animation,
              label: 'Défilement',
              isActive: _scrollEnabled,
              onTap: () => _toggleScroll(!_scrollEnabled),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEffectButton(
              icon: Icons.flash_on,
              label: 'Clignotement',
              isActive: _blinkEnabled,
              onTap: () => _toggleBlink(!_blinkEnabled),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppConstants.accentColor
              : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          border: Border.all(
            color: isActive
                ? AppConstants.accentColor
                : AppConstants.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? Colors.white
                  : AppConstants.accentColor.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isActive
                    ? Colors.white
                    : AppConstants.accentColor.withOpacity(0.45),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
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
              _buildPanelHeader(),
              Expanded(child: MatrixPreview(matrix: _matrix, showGlow: true)),
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
          Text(
            'Couleur du texte',
            style: TextStyle(
              color: AppConstants.accentColor.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
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
                  foregroundColor: AppConstants.accentColor.withOpacity(0.7),
                  side: BorderSide(color: AppConstants.borderColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
