class MatrixTemplate {
  final String id;
  final String name;
  final String? assetPreviewPath;
  final List<List<int>> matrix;

  const MatrixTemplate({
    required this.id,
    required this.name,
    required this.matrix,
    this.assetPreviewPath,
  });
}
