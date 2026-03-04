import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../data/matrix_templates.dart';
import '../models/led_matrix.dart';
import '../models/matrix_template.dart';
import '../widgets/ble_status_indicator.dart';
import '../widgets/matrix_panel.dart';
import '../widgets/matrix_preview.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                Icons.auto_awesome_mosaic,
                color: AppConstants.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Templates',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppConstants.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: BleStatusIndicator(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: GridView.builder(
          itemCount: kMatrixTemplates.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final t = kMatrixTemplates[index];
            return _TemplateCard(
              template: t,
              onTap: () => Navigator.pop(context, t),
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

  const _TemplateCard({required this.template, required this.onTap});

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
