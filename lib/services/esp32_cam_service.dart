import 'dart:typed_data';

import 'package:http/http.dart' as http;

class Esp32CamService {
  Esp32CamService._();

  static final instance = Esp32CamService._();

  final String baseHost = '192.168.4.1';

  String get streamUrl => 'http://$baseHost:81/stream';

  String get controlBaseUrl => 'http://$baseHost/control';

  String get captureUrl => 'http://$baseHost/capture';

  Future<void> setVar(String variable, int value) async {
    final uri = Uri.parse('$controlBaseUrl?var=$variable&val=$value');
    final resp = await http.get(uri).timeout(const Duration(seconds: 2));
    if (resp.statusCode != 200) {
      throw Exception('ESP32-CAM control failed: ${resp.statusCode}');
    }
  }

  Future<Uint8List> getStill() async {
    final uri = Uri.parse(captureUrl);
    final resp = await http.get(uri).timeout(const Duration(seconds: 4));
    if (resp.statusCode != 200) {
      throw Exception('ESP32-CAM capture failed: ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }
}
