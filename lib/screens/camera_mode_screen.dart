import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../config/constants.dart';
import '../services/esp32_cam_service.dart';
import '../services/mjpeg_recorder.dart';
import '../services/notification_service.dart';
import '../widgets/ble_status_indicator.dart';

class CameraModeScreen extends StatefulWidget {
  const CameraModeScreen({super.key});

  @override
  State<CameraModeScreen> createState() => _CameraModeScreenState();
}

class _CameraModeScreenState extends State<CameraModeScreen> {
  final _cam = Esp32CamService.instance;

  bool _streamActive = true;

  Uint8List? _lastStill;
  late final MjpegRecorder _recorder = MjpegRecorder(
    streamUrl: _cam.streamUrl,
    fps: 10,
  );
  bool _isRecording = false;

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
      if (id != null) {
        NotificationService.showSuccess('Vidéo enregistrée dans la galerie.');
      } else {
        NotificationService.showWarning(
          'Enregistrement arrêté (non sauvegardé).',
        );
      }
    } else {
      // START
      try {
        await _recorder.start();
        if (!mounted) return;
        setState(() => _isRecording = true);
        NotificationService.showInfo('Enregistrement démarré…');
      } catch (_) {
        if (!mounted) return;
        NotificationService.showError(
          "Impossible de démarrer l'enregistrement (stream non accessible).",
        );
      }
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
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: BleStatusIndicator(),
        ),
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
      color: Colors.black.withValues(alpha: 0.25),
      child: Text(
        'Stream en pause',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _previewError() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(16),
      child: Text(
        'Impossible d’afficher le flux.\nVérifie que tu es connecté au Wi-Fi de l’ESP32.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
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
        color: AppConstants.accentColor.withValues(alpha: 0.10),
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

  Widget _buildActions() {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _toggleRecording,
        icon: Icon(
          _isRecording ? Icons.stop : Icons.fiber_manual_record,
          size: 18,
        ),
        label: Text(
          _isRecording ? 'Arrêter' : 'Enregistrer',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRecording
              ? AppConstants.dangerColor
              : AppConstants.accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          ),
        ),
      ),
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
}
