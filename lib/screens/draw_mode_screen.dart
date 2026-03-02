import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../widgets/matrix_preview.dart';
import '../widgets/color_palette.dart';

class DrawModeScreen extends StatefulWidget {
  final List<List<int>> initialMatrix;

  const DrawModeScreen({super.key, required this.initialMatrix});

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
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            _buildControlPanel(),
            Expanded(child: _buildDrawingArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        border: Border(
          right: BorderSide(color: AppConstants.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withOpacity(0.06),
              border: Border(
                bottom: BorderSide(color: AppConstants.borderColor),
              ),
            ),
            child: const Text(
              'DESSIN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppConstants.accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _buildSaveButton(),
                  const SizedBox(height: 8),
                  _buildDivider(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GridColorPalette(
                      selectedColorIndex: _selectedColorIndex,
                      onColorSelected: (index) {
                        setState(() {
                          _selectedColorIndex = index;
                          _isDrawMode = index != 0;
                        });
                      },
                      useExtendedPalette: true,
                    ),
                  ),
                  _buildDivider(),
                  const SizedBox(height: 4),
                  _buildClearButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppConstants.borderColor.withOpacity(0.6),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton(
        onPressed: _saveAndGoBack,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14),
            SizedBox(width: 4),
            Text(
              'OK',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: OutlinedButton(
        onPressed: _clearMatrix,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.dangerColor,
          side: BorderSide(color: AppConstants.dangerColor.withOpacity(0.4)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          ),
        ),
        child: const Icon(Icons.delete_outline, size: 18),
      ),
    );
  }

  Widget _buildDrawingArea() {
    return Padding(
      padding: const EdgeInsets.all(8),
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
                child: InteractiveMatrixPreview(
                  matrix: _matrix,
                  selectedColorIndex: _selectedColorIndex % 10,
                  isDrawMode: _isDrawMode,
                  onMatrixChanged: () => setState(() {}),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
