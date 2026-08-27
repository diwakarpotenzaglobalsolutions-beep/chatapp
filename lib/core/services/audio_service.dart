import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _currentRecordingPath;

  AudioRecorder get recorder => _recorder;
  AudioPlayer get player => _player;

  Future<bool> checkPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (await checkPermission()) {
      final directory = await getTemporaryDirectory();
      _currentRecordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> playAudio(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http') || pathOrUrl.startsWith('https')) {
      await _player.setUrl(pathOrUrl);
    } else {
      await _player.setFilePath(pathOrUrl);
    }
    await _player.play();
  }

  Future<void> pauseAudio() async {
    await _player.pause();
  }

  Future<void> stopAudio() async {
    await _player.stop();
  }

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
