import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'notification_service.dart';
import 'storage_service.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected, error }

class BleService {
  BleService._();

  static final BleService instance = BleService._();

  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _deviceName = 'LED_MATRIX';

  static const int _frameSize = 512;
  static const int _chunkSize = 100;
  static const int _headerMatrix1 = 0xAA;
  static const int _headerMatrix2 = 0x55;
  static const int _headerBrightness1 = 0xBB;
  static const int _headerBrightness2 = 0x55;

  static const int _maxReconnectAttempts = 3;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  int _reconnectAttempts = 0;
  bool _userDisconnected = false;

  final Queue<Future<void> Function()> _sendQueue = Queue();
  bool _processing = false;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _connSub;
  bool _connecting = false;
  bool _reconnecting = false;

  List<List<int>>? _lastSentPixels;
  List<List<int>>? _nextMatrix;

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

  void _log(String message) {
    if (kDebugMode) debugPrint('BLE: $message');
  }

  Future<void> connect() async {
    if (_state == BleConnectionState.connecting ||
        _state == BleConnectionState.scanning ||
        _state == BleConnectionState.connected) {
      return;
    }

    _userDisconnected = false;
    _setState(BleConnectionState.scanning);

    try {
      final completer = Completer<BluetoothDevice>();
      StreamSubscription? scanSub;

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == _deviceName && !completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

      final device = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Device "$_deviceName" not found'),
      );

      await FlutterBluePlus.stopScan();
      await scanSub.cancel();

      await _doConnect(device);
    } on Exception catch (_) {
      await FlutterBluePlus.stopScan();
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      NotificationService.showError('Connexion échouée');
      rethrow;
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    _userDisconnected = false;
    await _doConnect(device);
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
    if (_connecting) return;
    _connecting = true;

    try {
      _device = device;
      _setState(BleConnectionState.connecting);

      if (Platform.isAndroid) {
        try {
          await device.disconnect();
        } catch (_) {}
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      await device.connectionState.firstWhere(
        (s) => s == BluetoothConnectionState.connected,
      );

      // Android only
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(256);
        } catch (_) {}
      }
      await Future<void>.delayed(
        Platform.isAndroid
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 800),
      );
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
        throw Exception('BLE characteristic "$_charUuid" not found');
      }

      _characteristic = char;
      _reconnectAttempts = 0;
      _lastSentPixels = null;
      _setState(BleConnectionState.connected);

      StorageService.instance.lastDeviceId = device.remoteId.toString();
      NotificationService.showSuccess('LED panel connected');
      _log('Connecté à ${device.platformName} (${device.remoteId})');

      await _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _characteristic = null;
          _lastSentPixels = null;
          _nextMatrix = null;

          if (_userDisconnected) {
            _device = null;
            _setState(BleConnectionState.disconnected);
          } else {
            _setState(BleConnectionState.disconnected);
            NotificationService.showWarning('Connexion BLE perdue');
            _attemptReconnect(); // protégé par _reconnecting
          }
        }
      });
    } finally {
      _connecting = false;
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;

    try {
      final device = _device;
      if (device == null || _userDisconnected) return;

      while (!_userDisconnected &&
          !isConnected &&
          _reconnectAttempts < _maxReconnectAttempts) {
        _reconnectAttempts++;
        final delay = _baseReconnectDelay * _reconnectAttempts;

        _log(
          'Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s...',
        );
        NotificationService.showWarning(
          'Reconnexion $_reconnectAttempts/$_maxReconnectAttempts...',
        );

        await Future<void>.delayed(delay);
        if (_userDisconnected || isConnected) return;

        try {
          await _doConnect(device);
        } catch (e) {
          _log('Reconnection failed: $e');
        }
      }

      if (!isConnected && !_userDisconnected) {
        _device = null;
        _setState(BleConnectionState.error);
        NotificationService.showError(
          'Reconnection failed after $_maxReconnectAttempts attempts',
        );
      }
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _connSub?.cancel();
    _connSub = null;
    _lastSentPixels = null;
    _nextMatrix = null;
    await _device?.disconnect();
    _characteristic = null;
    _device = null;
    _setState(BleConnectionState.disconnected);
    NotificationService.showInfo('Disconnected from LED panel');
  }

  Future<void> _enqueue(Future<void> Function() task) async {
    _sendQueue.add(task);
    if (_processing) return;
    _processing = true;

    try {
      while (_sendQueue.isNotEmpty) {
        final next = _sendQueue.removeFirst();
        try {
          await next().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _log('BLE operation timeout');
              throw TimeoutException('BLE operation timeout');
            },
          );
        } catch (e) {
          _log('Send queue error: $e');
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> sendMatrix(List<List<int>> pixels) async {
    if (!isConnected || _characteristic == null) {
      _log('Not connected, send ignored');
      return;
    }

    if (_lastSentPixels != null) {
      bool changed = false;
      for (int y = 0; y < pixels.length && !changed; y++) {
        for (int x = 0; x < pixels[y].length && !changed; x++) {
          if (pixels[y][x] != _lastSentPixels![y][x]) changed = true;
        }
      }
      if (!changed) return;
    }

    _nextMatrix = pixels.map((r) => List<int>.from(r)).toList();

    if (_processing) return;

    await _enqueue(() async {
      while (_nextMatrix != null) {
        final toSend = _nextMatrix!;
        _nextMatrix = null;
        await _doMatrixWrite(toSend);
      }
    });
  }

  Future<void> _doMatrixWrite(List<List<int>> copy) async {
    final char = _characteristic;
    if (char == null) return;

    final frame = Uint8List(_frameSize + 2);
    frame[0] = _headerMatrix1;
    frame[1] = _headerMatrix2;

    for (int y = 0; y < copy.length && y < 16; y++) {
      for (int x = 0; x < copy[y].length && x < 32; x++) {
        frame[2 + y * 32 + x] = copy[y][x];
      }
    }

    int offset = 0;
    while (offset < frame.length) {
      final iosChunk = 180;
      final effectiveChunk = Platform.isAndroid ? _chunkSize : iosChunk;
      final end = (offset + effectiveChunk).clamp(0, frame.length);
      await char.write(
        frame.sublist(offset, end),
        withoutResponse: Platform.isAndroid,
      );
      offset = end;
    }

    _lastSentPixels = copy;
  }

  Future<void> sendBrightness(int brightness) async {
    if (!isConnected || _characteristic == null) return;

    await _enqueue(() async {
      final char = _characteristic;
      if (char == null) return;

      final frame = Uint8List(3);
      frame[0] = _headerBrightness1;
      frame[1] = _headerBrightness2;
      frame[2] = brightness.clamp(0, 255);
      await char.write(frame.toList(), withoutResponse: false);
      _log('Brightness sent: $brightness');
    });
  }

  void dispose() {
    _connSub?.cancel();
    _stateCtrl.close();
  }
}
