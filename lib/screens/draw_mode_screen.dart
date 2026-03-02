import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../widgets/matrix_preview.dart';
import '../widgets/color_palette.dart';

class DrawModeScreen extends StatefulWidget {
  final List<List<int>> initialMatrix;

  const DrawModeScreen({
    super.key,
    required this.initialMatrix,
  });

  @override
  State<DrawModeScreen> createState() => _DrawModeScreenState();
}

class _DrawModeScreenState extends State<DrawModeScreen> {
  late LedMatrix _matrix;
  int _selectedColorIndex = 1;
  bool _isDrawMode = true;

  @override
  void initState() {
    super.initState();

    _matrix = LedMatrix.fromPixels(
      widget.initialMatrix.map((row) => List<int>.from(row)).toList(),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _clearMatrix() {
    setState(() {
      _matrix.clear();
    });
  }

  void _saveAndGoBack() {
    Navigator.pop(context, _matrix.pixels);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            _buildControlPanel(),

            Expanded(
              child: _buildDrawingArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppConstants.surfaceColor,
        border: Border(
          right: BorderSide(color: AppConstants.borderColor, width: 2),
        ),
      ),
      child: Column(
        children: [
          _buildSaveButton(),

          const SizedBox(height: 8),
          const Divider(color: AppConstants.borderColor, height: 1),
          const SizedBox(height: 8),

          _buildModeButton(
            icon: Icons.brush,
            label: 'Draw',
            isSelected: _isDrawMode,
            onTap: () => setState(() => _isDrawMode = true),
          ),
          const SizedBox(height: 4),
          _buildModeButton(
            icon: Icons.auto_fix_high,
            label: 'Erase',
            isSelected: !_isDrawMode,
            onTap: () => setState(() => _isDrawMode = false),
          ),

          const SizedBox(height: 8),
          const Divider(color: AppConstants.borderColor, height: 1),
          const SizedBox(height: 4),

          Expanded(
            child: GridColorPalette(
              selectedColorIndex: _selectedColorIndex,
              onColorSelected: (index) {
                setState(() {
                  _selectedColorIndex = index;
                  if (index != 0) _isDrawMode = true;
                });
              },
              useExtendedPalette: true,
            ),
          ),

          const Divider(color: AppConstants.borderColor, height: 1),
          const SizedBox(height: 4),

          _buildClearButton(),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saveAndGoBack,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('OK', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          border: Border.all(
            color: isSelected ? AppConstants.accentColor : AppConstants.borderColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _clearMatrix,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.dangerColor.withOpacity(0.2),
          foregroundColor: AppConstants.dangerColor,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: const Icon(Icons.delete, size: 20),
      ),
    );
  }

  Widget _buildDrawingArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius - 2),
        child: InteractiveMatrixPreview(
          matrix: _matrix,
          selectedColorIndex: _selectedColorIndex % 10, // Limiter à 0-9 pour ESP32
          isDrawMode: _isDrawMode,
          onMatrixChanged: () => setState(() {}),
        ),
      ),
    );
  }
}