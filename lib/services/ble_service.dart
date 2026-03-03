import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// États possibles de la connexion BLE.
enum BleConnectionState { disconnected, scanning, connecting, connected, error }

/// Service singleton pour communiquer avec l'ESP32 via BLE.
///
/// Protocole de trame :
///   [0xAA, 0x55, pixel_0, pixel_1, ..., pixel_511]  — 514 octets
///   Chaque pixel = index couleur 0-9 (correspond à AppConstants.colorPalette)
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  // ─── UUIDs (doivent correspondre au sketch Arduino) ─────────────────────────
  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _deviceName = 'LED_MATRIX';

  // ─── Constantes de protocole ────────────────────────────────────────────────
  static const int _frameSize = 512; // 32 × 16 pixels
  static const int _chunkSize = 128; // Taille max d'un paquet BLE (safe)
  static const int _chunkDelay = 20; // ms entre deux paquets

  // ─── État interne ───────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _connSub;
  bool _sending = false;

  final StreamController<BleConnectionState> _stateCtrl =
      StreamController<BleConnectionState>.broadcast();

  BleConnectionState _state = BleConnectionState.disconnected;

  /// Flux de l'état de connexion — écouter depuis l'UI.
  Stream<BleConnectionState> get stateStream => _stateCtrl.stream;

  /// État courant (synchrone).
  BleConnectionState get currentState => _state;

  bool get isConnected => _state == BleConnectionState.connected;

  // ─── Gestion de l'état ──────────────────────────────────────────────────────
  void _setState(BleConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  // ─── Connexion ──────────────────────────────────────────────────────────────

  /// Scanne et se connecte à l'appareil nommé [_deviceName].
  Future<void> connect() async {
    if (_state == BleConnectionState.connecting ||
        _state == BleConnectionState.scanning ||
        _state == BleConnectionState.connected)
      return;

    _setState(BleConnectionState.scanning);

    try {
      // Scan
      final completer = Completer<BluetoothDevice>();
      StreamSubscription? scanSub;

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == _deviceName && !completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      });

      final device = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Appareil "$_deviceName" introuvable'),
      );

      await FlutterBluePlus.stopScan();
      await scanSub.cancel();

      _device = device;
      _setState(BleConnectionState.connecting);

      // Connexion
      await device.connect(timeout: const Duration(seconds: 10));

      // MTU élevé pour envoyer plusieurs octets par paquet
      await device.requestMtu(256);

      // Découverte des services
      final services = await device.discoverServices();
      BluetoothCharacteristic? char;

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final c in svc.characteristics) {
            if (c.uuid.toString().toLowerCase() == _charUuid) {
              char = c;
              break;
            }
          }
        }
      }

      if (char == null) {
        throw Exception('Caractéristique BLE "$_charUuid" introuvable');
      }

      _characteristic = char;
      _setState(BleConnectionState.connected);

      // Surveiller la déconnexion
      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _characteristic = null;
          _device = null;
          _connSub?.cancel();
          _setState(BleConnectionState.disconnected);
        }
      });
    } on Exception {
      await FlutterBluePlus.stopScan();
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      rethrow;
    }
  }

  /// Déconnecte l'appareil courant.
  Future<void> disconnect() async {
    _connSub?.cancel();
    _connSub = null;
    await _device?.disconnect();
    _characteristic = null;
    _device = null;
    _setState(BleConnectionState.disconnected);
  }

  // ─── Envoi de la matrix ─────────────────────────────────────────────────────

  /// Envoie la matrix vers l'ESP32.
  ///
  /// [pixels] : liste 16 × 32 d'indices couleur (0-9).
  /// Retourne silencieusement si non connecté ou si un envoi est déjà en cours.
  Future<void> sendMatrix(List<List<int>> pixels) async {
    final char = _characteristic;
    if (char == null || _sending) return;
    _sending = true;

    try {
      final frame = Uint8List(_frameSize + 2);
      frame[0] = 0xAA;
      frame[1] = 0x55;

      for (int y = 0; y < pixels.length && y < 16; y++) {
        for (int x = 0; x < pixels[y].length && x < 32; x++) {
          frame[2 + y * 32 + x] = pixels[y][x];
        }
      }

      int offset = 0;
      while (offset < frame.length) {
        final end = (offset + _chunkSize).clamp(0, frame.length);
        await char.write(frame.sublist(offset, end), withoutResponse: true);
        await Future<void>.delayed(const Duration(milliseconds: _chunkDelay));
        offset = end;
      }
    } catch (_) {
    } finally {
      _sending = false;
    }
  }

  Future<void> sendBrightness(int brightness) async {
    final char = _characteristic;
    if (char == null) return;

    try {
      final frame = Uint8List(3);
      frame[0] = 0xBB;
      frame[1] = 0x55;
      frame[2] = brightness.clamp(0, 255);
      await char.write(frame.toList(), withoutResponse: true);
    } catch (_) {}
  }

  void dispose() {
    _connSub?.cancel();
    _stateCtrl.close();
  }
}
