import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'notification_service.dart';
import 'storage_service.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected, error }

class BleService {
  BleService._();
  static final BleService instance = BleService._();

  // ---------------------------------------------------------------------------
  // Protocole
  // ---------------------------------------------------------------------------

  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _deviceName = 'LED_MATRIX';

  static const int _frameSize = 512; // 32 × 16 pixels
  static const int _chunkSize = 128; // Taille max d'un paquet BLE (safe)
  static const int _chunkDelay = 20; // ms entre deux paquets

  /// Headers de trame
  static const int _headerMatrix1 = 0xAA;
  static const int _headerMatrix2 = 0x55;
  static const int _headerBrightness1 = 0xBB;
  static const int _headerBrightness2 = 0x55;

  // ---------------------------------------------------------------------------
  // Reconnexion automatique
  // ---------------------------------------------------------------------------

  static const int _maxReconnectAttempts = 3;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  int _reconnectAttempts = 0;
  bool _userDisconnected = false;

  // ---------------------------------------------------------------------------
  // File d'attente d'envoi
  // ---------------------------------------------------------------------------

  final Queue<Future<void> Function()> _sendQueue = Queue();
  bool _processing = false;

  // ---------------------------------------------------------------------------
  // État interne
  // ---------------------------------------------------------------------------

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _connSub;

  /// Dernière matrice envoyée (pour l'envoi différentiel)
  List<List<int>>? _lastSentPixels;

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

  // ---------------------------------------------------------------------------
  // Logging conditionnel (pas de print en release)
  // ---------------------------------------------------------------------------

  void _log(String message) {
    if (kDebugMode) debugPrint('BLE: $message');
  }

  // ---------------------------------------------------------------------------
  // Connexion
  // ---------------------------------------------------------------------------

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
    } on Exception catch (e) {
      await FlutterBluePlus.stopScan();
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      NotificationService.showError('Connexion échouée : $e');
      rethrow;
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_state == BleConnectionState.connecting ||
        _state == BleConnectionState.connected) {
      return;
    }
    _userDisconnected = false;
    _setState(BleConnectionState.connecting);
    try {
      await _doConnect(device);
    } on Exception catch (e) {
      _characteristic = null;
      _device = null;
      _setState(BleConnectionState.error);
      NotificationService.showError('Connexion échouée : $e');
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
    _reconnectAttempts = 0;
    _lastSentPixels = null;
    _setState(BleConnectionState.connected);

    // Sauvegarder l'ID pour reconnexion rapide
    StorageService.instance.lastDeviceId = device.remoteId.toString();

    NotificationService.showSuccess('Panneau LED connecté');
    _log('Connecté à ${device.platformName} (${device.remoteId})');

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _characteristic = null;
        _connSub?.cancel();
        _lastSentPixels = null;

        if (_userDisconnected) {
          _device = null;
          _setState(BleConnectionState.disconnected);
        } else {
          _setState(BleConnectionState.disconnected);
          NotificationService.showError('Connexion BLE perdue');
          _attemptReconnect();
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reconnexion automatique
  // ---------------------------------------------------------------------------

  Future<void> _attemptReconnect() async {
    final device = _device;
    if (device == null || _userDisconnected) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Reconnexion abandonnée après $_maxReconnectAttempts tentatives');
      _device = null;
      _setState(BleConnectionState.error);
      NotificationService.showError(
        'Reconnexion échouée après $_maxReconnectAttempts tentatives',
      );
      return;
    }

    _reconnectAttempts++;
    final delay = _baseReconnectDelay * _reconnectAttempts;
    _log(
      'Tentative de reconnexion $_reconnectAttempts/$_maxReconnectAttempts '
      'dans ${delay.inSeconds}s...',
    );
    NotificationService.showInfo(
      'Reconnexion $_reconnectAttempts/$_maxReconnectAttempts...',
    );

    await Future<void>.delayed(delay);

    if (_userDisconnected || isConnected) return;

    try {
      _setState(BleConnectionState.connecting);
      await _doConnect(device);
    } catch (e) {
      _log('Reconnexion échouée: $e');
      // _doConnect sets error state; _attemptReconnect is called again
      // from the connectionState listener if it disconnects.
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _attemptReconnect();
      } else {
        _device = null;
        _setState(BleConnectionState.error);
        NotificationService.showError(
          'Reconnexion échouée après $_maxReconnectAttempts tentatives',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Déconnexion
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _userDisconnected = true;
    _connSub?.cancel();
    _connSub = null;
    _lastSentPixels = null;
    await _device?.disconnect();
    _characteristic = null;
    _device = null;
    _setState(BleConnectionState.disconnected);
    NotificationService.showInfo('Déconnecté du panneau LED');
  }

  // ---------------------------------------------------------------------------
  // File d'attente d'envoi
  // ---------------------------------------------------------------------------

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
              _log('Timeout opération BLE');
              throw TimeoutException('BLE operation timeout');
            },
          );
        } catch (e) {
          _log('Erreur file d\'attente: $e');
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Envoi matrice
  // ---------------------------------------------------------------------------

  Future<void> sendMatrix(List<List<int>> pixels) async {
    if (!isConnected || _characteristic == null) {
      _log('Non connecté, envoi ignoré');
      return;
    }

    // Envoi différentiel : ne rien envoyer si la matrice n'a pas changé
    if (_lastSentPixels != null) {
      bool changed = false;
      for (int y = 0; y < pixels.length && !changed; y++) {
        for (int x = 0; x < pixels[y].length && !changed; x++) {
          if (pixels[y][x] != _lastSentPixels![y][x]) changed = true;
        }
      }
      if (!changed) return;
    }

    // Copier pour le cache différentiel
    final copy = pixels.map((r) => List<int>.from(r)).toList();

    await _enqueue(() async {
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
        final end = (offset + _chunkSize).clamp(0, frame.length);
        await char.write(frame.sublist(offset, end), withoutResponse: true);
        await Future<void>.delayed(const Duration(milliseconds: _chunkDelay));
        offset = end;
      }

      _lastSentPixels = copy;
    });
  }

  // ---------------------------------------------------------------------------
  // Envoi luminosité
  // ---------------------------------------------------------------------------

  Future<void> sendBrightness(int brightness) async {
    if (!isConnected || _characteristic == null) return;

    await _enqueue(() async {
      final char = _characteristic;
      if (char == null) return;

      final frame = Uint8List(3);
      frame[0] = _headerBrightness1;
      frame[1] = _headerBrightness2;
      frame[2] = brightness.clamp(0, 255);
      await char.write(frame.toList(), withoutResponse: true);
      _log('Luminosité envoyée: $brightness');
    });
  }

  // ---------------------------------------------------------------------------
  // Nettoyage
  // ---------------------------------------------------------------------------

  void dispose() {
    _connSub?.cancel();
    _stateCtrl.close();
  }
}
