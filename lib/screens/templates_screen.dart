import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../data/matrix_templates.dart';
import '../models/led_matrix.dart';
import '../models/matrix_template.dart';
import '../services/storage_service.dart';
import '../widgets/ble_status_indicator.dart';
import '../widgets/matrix_panel.dart';
import '../widgets/matrix_preview.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<Map<String, dynamic>> _savedDesigns = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDesigns();
  }

  void _loadSavedDesigns() {
    setState(() {
      _savedDesigns = StorageService.instance.savedDesigns;
    });
  }

  void _deleteDesign(int index) {
    StorageService.instance.deleteDesign(index);
    _loadSavedDesigns();
  }

  MatrixTemplate _savedDesignToTemplate(int index, Map<String, dynamic> d) {
    final rawPixels = d['pixels'] as List;
    final pixels = rawPixels
        .map((row) => (row as List).map((v) => v as int).toList())
        .toList();
    return MatrixTemplate(
      id: 'saved_$index',
      name: d['name'] as String,
      matrix: normalize32x16(pixels),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedTemplates = List.generate(
      _savedDesigns.length,
      (i) => _savedDesignToTemplate(i, _savedDesigns[i]),
    );
    final allTemplates = [...savedTemplates, ...kMatrixTemplates];

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppConstants.borderColor),
        ),
        title: const Text(
          'Templates',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppConstants.accentColor,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: BleStatusIndicator(),
          ),
        ],
      ),
      body: allTemplates.isEmpty
          ? const Center(
              child: Text(
                'Aucun template disponible',
                style: TextStyle(color: AppConstants.secondaryAccent),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: GridView.builder(
                itemCount: allTemplates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final t = allTemplates[index];
                  final isSaved = index < savedTemplates.length;
                  return _TemplateCard(
                    template: t,
                    canDelete: isSaved,
                    onTap: () => Navigator.pop(context, t),
                    onDelete: isSaved ? () => _deleteDesign(index) : null,
                  );
                },
              ),
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final MatrixTemplate template;
  final VoidCallback onTap;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          border: Border.all(color: AppConstants.borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.defaultRadius),
                ),
                border: Border(
                  bottom: BorderSide(color: AppConstants.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppConstants.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (canDelete)
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppConstants.dangerColor,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: MatrixPanel(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultRadius - 2,
                    ),
                    child: template.assetPreviewPath != null
                        ? Image.asset(
                            template.assetPreviewPath!,
                            fit: BoxFit.cover,
                          )
                        : _MatrixTemplatePreview(matrix: template.matrix),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Afficher',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
    );
  }
}

class _MatrixTemplatePreview extends StatelessWidget {
  final List<List<int>> matrix;

  const _MatrixTemplatePreview({required this.matrix});

  @override
  Widget build(BuildContext context) {
    final ledMatrix = LedMatrix.fromPixels(
      matrix.map((row) => List<int>.from(row)).toList(),
    );
    return Center(child: MatrixPreview(matrix: ledMatrix, showGlow: true));
  }
}
