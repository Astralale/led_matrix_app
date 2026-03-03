import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../config/constants.dart';
import '../services/esp32_cam_service.dart';
import '../services/mjpeg_recorder.dart';

class CameraModeScreen extends StatefulWidget {
  const CameraModeScreen({super.key});

  @override
  State<CameraModeScreen> createState() => _CameraModeScreenState();
}

class _CameraModeScreenState extends State<CameraModeScreen> {
  final _cam = Esp32CamService.instance;

  int _framesize = 6; // VGA
  int _quality = 12; // 10-63 (plus bas = meilleure qualité)
  int _brightness = 0; // -2..2 ou -3..3 selon build
  int _contrast = 0; // -2..2 ou -3..3
  int _saturation = 0; // -2..2 ou -4..4

  bool _hMirror = false; // hmirror
  bool _vFlip = false; // vflip

  bool _awb = true; // awb
  bool _aec = true; // aec
  bool _agc = true; // agc
  bool _nightMode = false; // aec2
  bool _lenc = true; // lenc (lens correction)

  bool _streamActive = true;

  Uint8List? _lastStill;
  bool _loadingStill = false;
  late final MjpegRecorder _recorder = MjpegRecorder(
    streamUrl: _cam.streamUrl,
    fps: 10,
  );
  bool _isRecording = false;
  static const Map<int, String> _resolutions = {
    10: 'UXGA (1600×1200)',
    9: 'SVGA (800×600)',
    8: 'XGA (1024×768)',
    7: 'SXGA (1280×1024)',
    6: 'VGA (640×480)',
    5: 'CIF (352×288)',
    4: 'QVGA (320×240)',
    3: 'HQVGA (240×176)',
    0: 'QQVGA (160×120)',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // STOP -> encode + save
      setState(() => _isRecording = false);
      final id = await _recorder.stop();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            id != null
                ? "Vidéo enregistrée dans la galerie."
                : "Enregistrement arrêté (non sauvegardé).",
          ),
          backgroundColor: id != null
              ? AppConstants.successColor
              : AppConstants.dangerColor,
        ),
      );
    } else {
      // START
      try {
        await _recorder.start();
        if (!mounted) return;
        setState(() => _isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Enregistrement démarré…"),
            backgroundColor: AppConstants.accentColor,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Impossible de démarrer l’enregistrement (stream non accessible).",
            ),
            backgroundColor: AppConstants.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _setCam(String varName, int value) async {
    try {
      await _cam.setVar(varName, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Échec envoi réglage caméra (ESP32 non joignable ?)",
          ),
          backgroundColor: AppConstants.dangerColor,
        ),
      );
    }
  }

  Future<void> _getStill() async {
    if (_loadingStill) return;
    setState(() => _loadingStill = true);
    try {
      final bytes = await _cam.getStill();
      if (!mounted) return;
      setState(() => _lastStill = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Capture impossible (/capture)"),
          backgroundColor: AppConstants.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingStill = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          _buildCameraPreviewCard(),
          const SizedBox(height: 12),
          _buildPrimaryControls(),
          const SizedBox(height: 12),
          _buildImageControls(),
          const SizedBox(height: 12),
          _buildToggles(),
          const SizedBox(height: 12),
          _buildActions(),
          if (_lastStill != null) ...[
            const SizedBox(height: 12),
            _buildStillCard(_lastStill!),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppConstants.borderColor),
      ),
      title: Row(
        children: [
          const SizedBox(width: 12),
          const Text(
            'Caméra',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppConstants.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: () => setState(() => _streamActive = !_streamActive),
            style: ElevatedButton.styleFrom(
              backgroundColor: _streamActive
                  ? AppConstants.accentColor
                  : AppConstants.borderColor,
              foregroundColor: _streamActive
                  ? Colors.white
                  : AppConstants.accentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
              ),
            ),
            child: Icon(
              _streamActive ? Icons.pause : Icons.play_arrow,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3D1010),
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildCardHeader('RETROUR CAMÉRA  ·  MJPEG'),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppConstants.defaultRadius - 2),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _streamActive
                  ? Mjpeg(
                      stream: _cam.streamUrl,
                      isLive: true,
                      timeout: const Duration(seconds: 4),
                      error: (context, error, stack) => _previewError(),
                    )
                  : _previewPaused(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPaused() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withOpacity(0.25),
      child: Text(
        'Stream en pause',
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _previewError() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withOpacity(0.25),
      padding: const EdgeInsets.all(16),
      child: Text(
        'Impossible d’afficher le flux.\nVérifie que tu es connecté au Wi-Fi de l’ESP32.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: AppConstants.accentColor.withOpacity(0.10),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.defaultRadius - 2),
        ),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppConstants.backgroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildPrimaryControls() {
    return _sectionCard(
      title: 'Réglages principaux',
      icon: Icons.tune,
      child: Column(
        children: [
          _dropdownTile(
            label: 'Résolution',
            value: _framesize,
            items: _resolutions,
            onChanged: (v) {
              setState(() => _framesize = v);
              _setCam('framesize', v);
            },
          ),
          const SizedBox(height: 10),
          _sliderTile(
            label: 'Qualité (plus bas = meilleur)',
            value: _quality.toDouble(),
            min: 4,
            max: 63,
            display: '$_quality',
            onChanged: (v) => setState(() => _quality = v.round()),
            onChangeEnd: (v) => _setCam('quality', v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildImageControls() {
    return _sectionCard(
      title: 'Image',
      icon: Icons.photo,
      child: Column(
        children: [
          _sliderTile(
            label: 'Luminosité',
            value: _brightness.toDouble(),
            min: -3,
            max: 3,
            display: '$_brightness',
            onChanged: (v) => setState(() => _brightness = v.round()),
            onChangeEnd: (v) => _setCam('brightness', v.round()),
          ),
          const SizedBox(height: 10),
          _sliderTile(
            label: 'Contraste',
            value: _contrast.toDouble(),
            min: -3,
            max: 3,
            display: '$_contrast',
            onChanged: (v) => setState(() => _contrast = v.round()),
            onChangeEnd: (v) => _setCam('contrast', v.round()),
          ),
          const SizedBox(height: 10),
          _sliderTile(
            label: 'Saturation',
            value: _saturation.toDouble(),
            min: -4,
            max: 4,
            display: '$_saturation',
            onChanged: (v) => setState(() => _saturation = v.round()),
            onChangeEnd: (v) => _setCam('saturation', v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildToggles() {
    return _sectionCard(
      title: 'Options',
      icon: Icons.toggle_on,
      child: Column(
        children: [
          _switchTile(
            label: 'AWB (balance des blancs auto)',
            value: _awb,
            onChanged: (v) {
              setState(() => _awb = v);
              _setCam('awb', v ? 1 : 0);
            },
          ),
          _switchTile(
            label: 'AEC (exposition auto)',
            value: _aec,
            onChanged: (v) {
              setState(() => _aec = v);
              _setCam('aec', v ? 1 : 0);
            },
          ),
          _switchTile(
            label: 'AGC (gain auto)',
            value: _agc,
            onChanged: (v) {
              setState(() => _agc = v);
              _setCam('agc', v ? 1 : 0);
            },
          ),
          _switchTile(
            label: 'Night mode',
            value: _nightMode,
            onChanged: (v) {
              setState(() => _nightMode = v);
              _setCam('aec2', v ? 1 : 0);
            },
          ),
          _switchTile(
            label: 'Lens correction',
            value: _lenc,
            onChanged: (v) {
              setState(() => _lenc = v);
              _setCam('lenc', v ? 1 : 0);
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _switchCompact(
                  label: 'H-Mirror',
                  value: _hMirror,
                  onChanged: (v) {
                    setState(() => _hMirror = v);
                    _setCam('hmirror', v ? 1 : 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _switchCompact(
                  label: 'V-Flip',
                  value: _vFlip,
                  onChanged: (v) {
                    setState(() => _vFlip = v);
                    _setCam('vflip', v ? 1 : 0);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(
                _isRecording ? Icons.stop : Icons.fiber_manual_record,
                size: 18,
              ),
              label: Text(
                _isRecording ? 'Arrêter' : 'Enregistrer',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording
                    ? AppConstants.dangerColor
                    : AppConstants.accentColor,
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
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _framesize = 6;
                  _quality = 12;
                  _brightness = 0;
                  _contrast = 0;
                  _saturation = 0;
                  _awb = true;
                  _aec = true;
                  _agc = true;
                  _nightMode = false;
                  _lenc = true;
                  _hMirror = false;
                  _vFlip = false;
                });
                _setCam('framesize', _framesize);
                _setCam('quality', _quality);
                _setCam('brightness', _brightness);
                _setCam('contrast', _contrast);
                _setCam('saturation', _saturation);
                _setCam('awb', 1);
                _setCam('aec', 1);
                _setCam('agc', 1);
                _setCam('aec2', 0);
                _setCam('lenc', 1);
                _setCam('hmirror', 0);
                _setCam('vflip', 0);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Init.', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.accentColor.withOpacity(0.7),
                side: BorderSide(color: AppConstants.borderColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStillCard(Uint8List bytes) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Column(
        children: [
          _buildCardHeader('CAPTURE  ·  JPEG'),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppConstants.defaultRadius - 2),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppConstants.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppConstants.accentColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppConstants.accentColor.withOpacity(0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                color: AppConstants.accentColor.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppConstants.accentColor,
            inactiveTrackColor: AppConstants.borderColor,
            thumbColor: AppConstants.accentColor,
            overlayColor: AppConstants.accentColor.withOpacity(0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.accentColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppConstants.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _switchCompact({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.accentColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppConstants.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _dropdownTile({
    required String label,
    required int value,
    required Map<int, String> items,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppConstants.accentColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox.shrink(),
            dropdownColor: AppConstants.surfaceColor,
            style: const TextStyle(
              color: AppConstants.accentColor,
              fontWeight: FontWeight.w700,
            ),
            items: items.entries
                .map(
                  (e) =>
                      DropdownMenuItem<int>(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
