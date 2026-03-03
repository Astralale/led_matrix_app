import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/constants.dart';
import '../models/led_matrix.dart';
import '../services/ble_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/text_renderer.dart';

class TextModeController extends ChangeNotifier with WidgetsBindingObserver {
  TextModeController() {
    _loadSettings();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _pausedWhileScrolling = false;
  bool _pausedWhileBlinking = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseEffects();
    } else if (state == AppLifecycleState.resumed) {
      _resumeEffects();
    }
  }

  void _pauseEffects() {
    _pausedWhileScrolling = isScrolling;
    _pausedWhileBlinking = blinkEnabled;
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void _resumeEffects() {
    if (_pausedWhileScrolling) {
      if (_scrollSnapshot != null) {
        _startDrawScroll();
      } else if (_currentScrollText.isNotEmpty) {
        _startScrolling();
      }
    }
    if (_pausedWhileBlinking) {
      _restartActiveBlink();
    }
    _pausedWhileScrolling = false;
    _pausedWhileBlinking = false;
  }

  final LedMatrix matrix = LedMatrix();

  int selectedColorIndex = 1;
  int scrollSpeedMs = 60;
  int blinkIntervalMs = 500;
  int brightness = 60;
  String emergencyMessage = 'HELP';

  bool scrollEnabled = false;
  bool blinkEnabled = false;
  bool isScrolling = false;
  bool blinkVisible = true;

  String _currentScrollText = '';
  int _scrollOffset = 0;

  Timer? _scrollTimer;
  Timer? _blinkTimer;
  List<List<int>>? _scrollSnapshot;
  List<List<int>>? _blinkSnapshot;

  void _loadSettings() {
    final storage = StorageService.instance;
    emergencyMessage = storage.emergencyMessage;
    scrollSpeedMs = storage.scrollSpeedMs;
    blinkIntervalMs = storage.blinkIntervalMs;
    brightness = storage.brightness;
    selectedColorIndex = storage.selectedColorIndex;
  }

  void setSelectedColor(int index) {
    selectedColorIndex = index;
    StorageService.instance.selectedColorIndex = index;
    notifyListeners();
  }

  void sendCurrentMatrix() {
    BleService.instance.sendMatrix(matrix.pixels);
  }

  void applyText(String text) {
    if (text.isEmpty) {
      NotificationService.showInfo('Entrez du texte à afficher');
      return;
    }

    _stopScrolling();
    _scrollSnapshot = null;

    if (scrollEnabled) {
      _currentScrollText = text;
      _scrollOffset = AppConstants.matrixWidth;
      _startScrolling();
    } else {
      final centeredX =
          (AppConstants.matrixWidth - TextRenderer.getTextWidth(text)) ~/ 2;
      TextRenderer.drawText(
        matrix,
        text,
        colorIndex: selectedColorIndex,
        startX: centeredX.clamp(0, AppConstants.matrixWidth - 1),
      );
      notifyListeners();
      sendCurrentMatrix();
    }
  }

  void _startScrolling() {
    isScrolling = true;
    _scrollTimer = Timer.periodic(Duration(milliseconds: scrollSpeedMs), (_) {
      if (blinkEnabled && !blinkVisible) return;
      final textWidth = TextRenderer.getTextWidth(_currentScrollText);
      TextRenderer.drawText(
        matrix,
        _currentScrollText,
        colorIndex: selectedColorIndex,
        startX: _scrollOffset,
      );
      _scrollOffset--;
      if (_scrollOffset + textWidth < 0) {
        _scrollOffset = AppConstants.matrixWidth;
      }
      notifyListeners();
      sendCurrentMatrix();
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (isScrolling) {
      isScrolling = false;
      notifyListeners();
    }
  }

  void _stopScrollingAndReset() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSnapshot = null;
    isScrolling = false;
    scrollEnabled = false;
    notifyListeners();
  }

  void toggleScroll(bool value, {String pendingText = ''}) {
    if (value) {
      scrollEnabled = true;
      notifyListeners();
      if (matrix.litPixelCount > 0) {
        _startDrawScroll();
      } else if (pendingText.isNotEmpty) {
        _stopScrolling();
        _scrollSnapshot = null;
        _currentScrollText = pendingText;
        _scrollOffset = AppConstants.matrixWidth;
        _startScrolling();
      }
      if (blinkEnabled) {
        _blinkSnapshot = null;
        _blinkTimer?.cancel();
        blinkVisible = true;
        _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
          _,
        ) {
          blinkVisible = !blinkVisible;
          if (!blinkVisible) {
            matrix.clear();
            sendCurrentMatrix();
          }
          notifyListeners();
        });
      }
    } else {
      final snap = _scrollSnapshot;
      _stopScrolling();
      _scrollSnapshot = null;
      scrollEnabled = false;
      if (snap != null) {
        matrix.updateFrom(snap);
      }
      notifyListeners();
      if (blinkEnabled) {
        _blinkTimer?.cancel();
        blinkVisible = true;
        _blinkSnapshot = matrix.pixels.map((r) => List<int>.from(r)).toList();
        _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
          _,
        ) {
          blinkVisible = !blinkVisible;
          if (blinkVisible) {
            matrix.updateFrom(
              _blinkSnapshot!.map((r) => List<int>.from(r)).toList(),
            );
          } else {
            matrix.clear();
          }
          notifyListeners();
          sendCurrentMatrix();
        });
      }
    }
  }

  void _startDrawScroll() {
    _scrollSnapshot = matrix.pixels.map((r) => List<int>.from(r)).toList();
    int offset = 0;
    isScrolling = true;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(Duration(milliseconds: scrollSpeedMs), (_) {
      if (blinkEnabled && !blinkVisible) return;
      offset++;
      final w = AppConstants.matrixWidth;
      final h = AppConstants.matrixHeight;
      final snap = _scrollSnapshot!;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          matrix.setPixel(x, y, snap[y][(x + offset) % w]);
        }
      }
      notifyListeners();
      sendCurrentMatrix();
    });
  }

  void clearMatrix() {
    _stopScrollingAndReset();
    stopBlinking();
    matrix.clear();
    notifyListeners();
    sendCurrentMatrix();
  }

  void displayHelp() {
    _stopScrollingAndReset();
    stopBlinking();
    const helpColor = 1;
    final text = emergencyMessage.toUpperCase();
    final textWidth = TextRenderer.getTextWidth(text);

    if (textWidth > AppConstants.matrixWidth) {
      selectedColorIndex = helpColor;
      scrollEnabled = true;
      _currentScrollText = text;
      _scrollOffset = AppConstants.matrixWidth;
      notifyListeners();
      _startScrolling();
    } else {
      final centeredX = (AppConstants.matrixWidth - textWidth) ~/ 2;
      matrix.clear();
      TextRenderer.drawText(
        matrix,
        text,
        colorIndex: helpColor,
        startX: centeredX.clamp(0, AppConstants.matrixWidth - 1),
      );
      notifyListeners();
      sendCurrentMatrix();
    }
  }

  void updateFromDrawResult(List<List<int>> result) {
    matrix.updateFrom(result);
    notifyListeners();
    if (scrollEnabled) {
      _startDrawScroll();
    } else {
      sendCurrentMatrix();
    }
  }

  void toggleBlink(bool value) {
    if (value) {
      blinkVisible = true;
      blinkEnabled = true;
      notifyListeners();
      _blinkTimer?.cancel();
      if (isScrolling) {
        _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
          _,
        ) {
          blinkVisible = !blinkVisible;
          if (!blinkVisible) {
            matrix.clear();
            sendCurrentMatrix();
          }
          notifyListeners();
        });
      } else {
        _blinkSnapshot = matrix.pixels.map((r) => List<int>.from(r)).toList();
        _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
          _,
        ) {
          blinkVisible = !blinkVisible;
          if (blinkVisible) {
            matrix.updateFrom(
              _blinkSnapshot!.map((r) => List<int>.from(r)).toList(),
            );
          } else {
            matrix.clear();
          }
          notifyListeners();
          sendCurrentMatrix();
        });
      }
    } else {
      stopBlinking();
      if (!isScrolling && _blinkSnapshot != null) {
        matrix.updateFrom(_blinkSnapshot!);
        notifyListeners();
        sendCurrentMatrix();
      }
      _blinkSnapshot = null;
    }
  }

  void stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (blinkEnabled) {
      blinkEnabled = false;
      blinkVisible = true;
      notifyListeners();
    }
  }

  void updateSettings({
    String? emergencyMessage,
    int? scrollSpeedMs,
    int? blinkIntervalMs,
    int? brightness,
  }) {
    final storage = StorageService.instance;
    if (emergencyMessage != null && emergencyMessage.isNotEmpty) {
      this.emergencyMessage = emergencyMessage.toUpperCase();
      storage.emergencyMessage = this.emergencyMessage;
    }
    if (scrollSpeedMs != null) {
      this.scrollSpeedMs = scrollSpeedMs;
      storage.scrollSpeedMs = scrollSpeedMs;
      if (isScrolling) _restartActiveScroll();
    }
    if (blinkIntervalMs != null) {
      this.blinkIntervalMs = blinkIntervalMs;
      storage.blinkIntervalMs = blinkIntervalMs;
      if (blinkEnabled) _restartActiveBlink();
    }
    if (brightness != null) {
      this.brightness = brightness;
      storage.brightness = brightness;
    }
    notifyListeners();
  }

  void _restartActiveScroll() {
    if (_scrollSnapshot != null) {
      _stopScrolling();
      _startDrawScroll();
    } else if (_currentScrollText.isNotEmpty) {
      _stopScrolling();
      _startScrolling();
    }
  }

  void _restartActiveBlink() {
    _blinkTimer?.cancel();
    blinkVisible = true;
    if (isScrolling) {
      _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
        _,
      ) {
        blinkVisible = !blinkVisible;
        if (!blinkVisible) {
          matrix.clear();
          sendCurrentMatrix();
        }
        notifyListeners();
      });
    } else {
      _blinkSnapshot = matrix.pixels.map((r) => List<int>.from(r)).toList();
      _blinkTimer = Timer.periodic(Duration(milliseconds: blinkIntervalMs), (
        _,
      ) {
        blinkVisible = !blinkVisible;
        if (blinkVisible) {
          matrix.updateFrom(
            _blinkSnapshot!.map((r) => List<int>.from(r)).toList(),
          );
        } else {
          matrix.clear();
        }
        notifyListeners();
        sendCurrentMatrix();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }
}
