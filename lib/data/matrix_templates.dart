import '../models/matrix_template.dart';

const int kW = 32;
const int kH = 16;

List<List<int>> normalize32x16(List<List<int>> m) {
  final out = List.generate(kH, (_) => List.filled(kW, 0));
  for (int y = 0; y < kH && y < m.length; y++) {
    for (int x = 0; x < kW && x < m[y].length; x++) {
      final v = m[y][x];
      out[y][x] = (v < 0 || v > 15) ? 0 : v;
    }
  }
  return out;
}

// Palette référence :
//  0 = éteint      1 = rouge       2 = vert        3 = bleu
//  4 = jaune       5 = magenta     6 = cyan        7 = blanc
//  8 = orange      9 = violet     10 = rose       11 = rouge-orange
// 12 = vert lime  13 = bleu ciel  14 = or         15 = turquoise

final List<MatrixTemplate> kMatrixTemplates = [];
