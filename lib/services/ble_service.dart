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
  static const String _alertCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';
  static const String deviceName = 'LED_MATRIX';

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

  Function()? onAlertReceived;
  StreamSubscription? _alertSub;

  final Queue<Future<void> Function()> _sendQueue = Queue();
  bool _processing = false;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  BluetoothCharacteristic? _alertCharacteristic;
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
          if (r.device.platformName == deviceName && !completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

      final device = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Device "$deviceName" not found'),
      );

      await FlutterBluePlus.stopScan();
      await scanSub.cancel();

      await _doConnect(device);
    } on Exception catch (_) {
      await FlutterBluePlus.stopScan();
      _characteristic = null;
      _alertCharacteristic = null;
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

      try {
        await device.requestMtu(256);
      } catch (_) {}

      await Future<void>.delayed(
        Platform.isAndroid
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 800),
      );

      final services = await device.discoverServices();

      BluetoothCharacteristic? char;
      BluetoothCharacteristic? alertChar;

      for (final svc in services) {
        final svcUuid = svc.uuid.toString().toLowerCase();

        if (svcUuid == _serviceUuid) {
          for (final c in svc.characteristics) {
            final charUuid = c.uuid.toString().toLowerCase();

            if (charUuid == _charUuid) {
              char = c;
            }

            if (charUuid == _alertCharUuid) {
              alertChar = c;
            }
          }
        }
      }

      if (char == null) {
        throw Exception('BLE characteristic not found');
      }

      _characteristic = char;
      _alertCharacteristic = alertChar;

      if (alertChar != null) {
        await _subscribeToAlerts(alertChar);
      }

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
          _alertCharacteristic = null;
          _alertSub?.cancel();
          _alertSub = null;
          _lastSentPixels = null;
          _nextMatrix = null;

          if (_userDisconnected) {
            _device = null;
            _setState(BleConnectionState.disconnected);
          } else {
            _setState(BleConnectionState.disconnected);
            NotificationService.showWarning('Connexion BLE perdue');
            _attemptReconnect();
          }
        }
      });
    } finally {
      _connecting = false;
    }
  }

  Future<void> _subscribeToAlerts(BluetoothCharacteristic alertChar) async {
    try {
      await _alertSub?.cancel();
      await alertChar.setNotifyValue(true);

      _alertSub = alertChar.lastValueStream.listen((value) {
        if (value.length >= 2 && value[0] == 0xCC && value[1] == 0xAA) {
          onAlertReceived?.call();
        }
      });
    } catch (e) {
      _log('Error subscribing to alerts: $e');
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
    _alertSub?.cancel();
    _alertSub = null;
    _lastSentPixels = null;
    _nextMatrix = null;
    await _device?.disconnect();
    _characteristic = null;
    _alertCharacteristic = null;
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
      final effectiveChunk = Platform.isIOS ? 180 : _chunkSize;
      final end = (offset + effectiveChunk).clamp(0, frame.length);
      await char.write(frame.sublist(offset, end), withoutResponse: true);
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
    });
  }

  void dispose() {
    _connSub?.cancel();
    _alertSub?.cancel();
    _stateCtrl.close();
  }
}
