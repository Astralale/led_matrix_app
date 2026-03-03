import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class MjpegRecorder {
  MjpegRecorder({required this.streamUrl, this.fps = 10});

  final String streamUrl;
  final int fps;

  bool _recording = false;

  bool get isRecording => _recording;

  http.Client? _client;
  StreamSubscription<List<int>>? _sub;

  Directory? _framesDir;
  int _frameIndex = 0;
  final BytesBuilder _buf = BytesBuilder(copy: false);

  DateTime? _lastFrameWrite;

  Duration get _minFrameInterval =>
      Duration(milliseconds: (1000 / fps).round());

  Future<Directory> _createFramesDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(
      '${tmp.path}/mjpeg_frames_${DateTime.now().millisecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Start recording: reads MJPEG stream and writes jpeg frames to temp dir.
  Future<void> start() async {
    if (_recording) return;
    _recording = true;

    _framesDir = await _createFramesDir();
    _frameIndex = 0;
    _lastFrameWrite = null;

    _client = http.Client();

    final req = http.Request('GET', Uri.parse(streamUrl));
    final resp = await _client!.send(req).timeout(const Duration(seconds: 5));

    if (resp.statusCode != 200) {
      await stop(discard: true);
      throw Exception('MJPEG stream HTTP ${resp.statusCode}');
    }

    _sub = resp.stream.listen(
      (chunk) {
        if (!_recording) return;
        _consume(chunk);
      },
      onError: (_) async {
        await stop(discard: true);
      },
      cancelOnError: true,
    );
  }

  void _consume(List<int> chunk) {
    _buf.add(chunk);
    final data = _buf.toBytes();
    int start = _indexOfJpegStart(data, 0);
    if (start < 0) {
      _buf.clear();
      _buf.add(data);
      return;
    }

    int searchFrom = start;
    while (true) {
      final end = _indexOfJpegEnd(data, searchFrom);
      if (end < 0) break;

      final jpeg = Uint8List.sublistView(
        Uint8List.fromList(data),
        start,
        end + 2,
      );

      _maybeWriteFrame(jpeg);

      searchFrom = end + 2;
      start = _indexOfJpegStart(data, searchFrom);
      if (start < 0) {
        final remaining = data.sublist(searchFrom);
        _buf.clear();
        _buf.add(remaining);
        return;
      }
    }
    final remaining = data.sublist(start);
    _buf.clear();
    _buf.add(remaining);
  }

  int _indexOfJpegStart(List<int> data, int from) {
    for (int i = from; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD8) return i;
    }
    return -1;
  }

  int _indexOfJpegEnd(List<int> data, int from) {
    for (int i = from; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD9) return i;
    }
    return -1;
  }

  Future<void> _maybeWriteFrame(Uint8List jpeg) async {
    if (_framesDir == null) return;

    final now = DateTime.now();
    if (_lastFrameWrite != null &&
        now.difference(_lastFrameWrite!) < _minFrameInterval) {
      return; // throttle FPS
    }
    _lastFrameWrite = now;

    final name = _frameIndex.toString().padLeft(6, '0');
    final file = File('${_framesDir!.path}/frame_$name.jpg');
    _frameIndex++;
    // ignore: unawaited_futures
    file.writeAsBytes(jpeg, flush: false);
  }

  /// Stop recording.
  /// If discard=true -> deletes frames and does not produce video.
  /// Returns saved video asset id (or null if discarded).
  Future<String?> stop({bool discard = false}) async {
    if (!_recording) return null;
    _recording = false;

    await _sub?.cancel();
    _sub = null;

    _client?.close();
    _client = null;

    final framesDir = _framesDir;
    _framesDir = null;

    if (framesDir == null) return null;

    if (discard || _frameIndex < 2) {
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      return null;
    }

    final tmp = await getTemporaryDirectory();
    final outFile = File(
      '${tmp.path}/esp32cam_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final inputPattern = '${framesDir.path}/frame_%06d.jpg';
    final cmd =
        '-y -framerate $fps -i "$inputPattern" -c:v libx264 -preset veryfast -pix_fmt yuv420p "${outFile.path}"';

    await FFmpegKit.execute(cmd);

    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      return null;
    }

    final asset = await PhotoManager.editor.saveVideo(
      outFile,
      title: outFile.uri.pathSegments.last,
    );
    if (await framesDir.exists()) {
      await framesDir.delete(recursive: true);
    }

    return asset.id;
  }
}
