import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../services/storage_service.dart';
import '../widgets/matrix_panel.dart';
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

  Future<void> _saveAsTemplate() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceColor,
        title: const Text(
          'Sauvegarder le dessin',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom du template',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        StorageService.instance.saveDesign(name, _matrix.pixels);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '«$name» sauvegardé dans les templates',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
        }
      }
    }
    nameController.dispose();
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
              color: AppConstants.accentColor.withValues(alpha: 0.06),
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
                  const SizedBox(height: 6),
                  _buildSaveAsTemplateButton(),
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

  Widget _buildSaveAsTemplateButton() {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton(
        onPressed: _saveAsTemplate,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          side: BorderSide(
            color: AppConstants.accentColor.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined, size: 14),
            SizedBox(width: 4),
            Text(
              'Template',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppConstants.borderColor.withValues(alpha: 0.6),
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
      height: 42,
      child: TextButton(
        onPressed: _clearMatrix,
        style: TextButton.styleFrom(
          foregroundColor: AppConstants.dangerColor,
          backgroundColor: AppConstants.dangerColor.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallRadius),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 18),
            SizedBox(height: 2),
            Text(
              'Effacer',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingArea() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: MatrixPanel(
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
    );
  }
}
