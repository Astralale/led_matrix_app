import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected, error }

class BleService {
  BleService._();
  static final BleService instance = BleService._();

  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _deviceName = 'LED_MATRIX';

  static const int _frameSize = 512; // 32 × 16 pixels
  static const int _chunkSize = 128; // Taille max d'un paquet BLE (safe)
  static const int _chunkDelay = 20; // ms entre deux paquets

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _connSub;
  bool _sending = false;

  final StreamController<BleConnectionState> _stateCtrl =
      StreamController<BleConnectionState>.broadcast();

  BleConnectionState _state = BleConnectionState.disconnected;

  Stream<BleConnectionState> get stateStream => _stateCtrl.stream;

  BleConnectionState get currentState => _state;

  bool get isConnected => _state == BleConnectionState.connected;

  void _setState(BleConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<void> connect() async {
    if (_state == BleConnectionState.connecting ||
        _state == BleConnectionState.scanning ||
        _state == BleConnectionState.connected) {
      return;
    }

    _setState(BleConnectionState.scanning);

    try {
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

      await _doConnect(device);
    } on Exception {
      await FlutterBluePlus.stopScan();
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      rethrow;
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_state == BleConnectionState.connecting ||
        _state == BleConnectionState.connected) {
      return;
    }
    _setState(BleConnectionState.connecting);
    try {
      await _doConnect(device);
    } on Exception {
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      rethrow;
    }
  }

  Future<List<ScanResult>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final resultsMap = <String, ScanResult>{};

    await FlutterBluePlus.startScan(timeout: timeout);

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        resultsMap[r.device.remoteId.toString()] = r;
      }
    });

    await FlutterBluePlus.isScanning.where((v) => v == false).first;
    await sub.cancel();

    return resultsMap.values.toList();
  }

  Future<void> _doConnect(BluetoothDevice device) async {
    _device = device;
    _setState(BleConnectionState.connecting);

    await device.connect(timeout: const Duration(seconds: 10));
    await device.requestMtu(256);

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

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _characteristic = null;
        _device = null;
        _connSub?.cancel();
        _setState(BleConnectionState.disconnected);
      }
    });
  }

  Future<void> disconnect() async {
    _connSub?.cancel();
    _connSub = null;
    await _device?.disconnect();
    _characteristic = null;
    _device = null;
    _setState(BleConnectionState.disconnected);
  }

  Future<void> sendMatrix(List<List<int>> pixels) async {
    final char = _characteristic;
    if (char == null) {
      print('BLE: Pas de caractéristique, non connecté');
      return;
    }
    if (_sending) {
      print('BLE: Envoi déjà en cours');
      return;
    }
    _sending = true;

    try {
      print('BLE: Préparation de la trame...');
      final frame = Uint8List(_frameSize + 2);
      frame[0] = 0xAA;
      frame[1] = 0x55;

      for (int y = 0; y < pixels.length && y < 16; y++) {
        for (int x = 0; x < pixels[y].length && x < 32; x++) {
          frame[2 + y * 32 + x] = pixels[y][x];
        }
      }

      print('BLE: Envoi de ${frame.length} octets...');
      int offset = 0;
      int chunkNum = 0;
      while (offset < frame.length) {
        final end = (offset + _chunkSize).clamp(0, frame.length);
        await char.write(frame.sublist(offset, end), withoutResponse: true);
        await Future<void>.delayed(const Duration(milliseconds: _chunkDelay));
        chunkNum++;
        offset = end;
      }
      print('BLE: Envoi terminé ($chunkNum chunks)');
    } catch (e) {
      print('BLE: Erreur envoi: $e');
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
