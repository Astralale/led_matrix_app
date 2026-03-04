import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:led_matrix_app/models/matrix_template.dart';
import 'package:led_matrix_app/screens/templates_screen.dart';

import '../config/constants.dart';
import '../services/text_mode_controller.dart';
import '../widgets/ble_status_indicator.dart';
import '../widgets/color_palette.dart';
import '../widgets/matrix_panel.dart';
import '../widgets/matrix_preview.dart';
import 'draw_mode_screen.dart';

class TextModeScreen extends StatefulWidget {
  final TextModeController controller;

  const TextModeScreen({super.key, required this.controller});

  @override
  State<TextModeScreen> createState() => _TextModeScreenState();
}

class _TextModeScreenState extends State<TextModeScreen> {
  TextModeController get _controller => widget.controller;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _applyText() {
    _controller.applyText(_textController.text);
  }

  void _displayHelp() {
    _textController.text = _controller.emergencyMessage.toLowerCase();
    _controller.displayHelp();
  }

  Future<void> _openTemplatesScreen() async {
    _controller.toggleScroll(false);
    _controller.toggleBlink(false);

    final selected = await Navigator.push<MatrixTemplate>(
      context,
      MaterialPageRoute(builder: (_) => const TemplatesScreen()),
    );

    if (selected != null) {
      _controller.updateFromDrawResult(
        selected.matrix.map((row) => List<int>.from(row)).toList(),
      );
    }
  }

  Future<void> _openDrawMode() async {
    _controller.toggleScroll(false);
    final result = await Navigator.push<List<List<int>>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DrawModeScreen(initialMatrix: _controller.matrix.pixels),
      ),
    );

    if (result != null) {
      _controller.updateFromDrawResult(result);
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
              color: AppConstants.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppConstants.accentColor.withValues(alpha: 0.2),
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
            'Femmes',
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
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: BleStatusIndicator(),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
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
              isActive: _controller.scrollEnabled,
              onTap: () => _controller.toggleScroll(
                !_controller.scrollEnabled,
                pendingText: _textController.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEffectButton(
              icon: Icons.flash_on,
              label: 'Clignotement',
              isActive: _controller.blinkEnabled,
              onTap: () => _controller.toggleBlink(!_controller.blinkEnabled),
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
                  : AppConstants.accentColor.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isActive
                    ? Colors.white
                    : AppConstants.accentColor.withValues(alpha: 0.45),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixPreview() {
    return Flexible(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: MatrixPanel(
          child: MatrixPreview(matrix: _controller.matrix, showGlow: true),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
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
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () => _textController.clear(),
                  ),
                ),
                onSubmitted: (_) => _applyText(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openDrawMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.borderColor,
                foregroundColor: AppConstants.accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultRadius,
                  ),
                ),
              ),
              child: const Icon(Icons.brush, size: 20),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openTemplatesScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.borderColor,
                foregroundColor: AppConstants.accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultRadius,
                  ),
                ),
              ),
              child: const Icon(Icons.image, size: 20),
            ),
          ],
        ),
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
              color: AppConstants.accentColor.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          HorizontalColorPalette(
            selectedColorIndex: _controller.selectedColorIndex,
            onColorSelected: _controller.setSelectedColor,
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
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _controller.clearMatrix,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Effacer', style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.accentColor.withValues(
                    alpha: 0.7,
                  ),
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
