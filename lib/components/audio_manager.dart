import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// AudioManager – synthesises retro‑neon sound effects as WAV files written
/// to the device's temp directory, then plays them via [DeviceFileSource].
///
/// [BytesSource] is unreliable on Android so we persist WAV to disk instead.
///
/// Sounds:
///   • Flap   – short rising chirp  (80 ms, 500→1800 Hz)
///   • Score  – two‑tone ding       (180 ms, 880 Hz → 1320 Hz)
///   • Death  – descending buzz     (350 ms, 400→60 Hz, distorted)
///   • Click  – tiny UI tap         (50 ms, 1000→1200 Hz)
///
/// Haptics (always fire, even when muted):
///   • Flap   – lightImpact
///   • Score  – mediumImpact
///   • Death  – heavyImpact
///   • Click  – selectionClick
/// ──────────────────────────────────────────────────────────────────────────────
class AudioManager {
  // ── Singleton ───────────────────────────────────────────────────────────
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // Dedicated player per sound type so they can overlap.
  final AudioPlayer _flapPlayer = AudioPlayer();
  final AudioPlayer _scorePlayer = AudioPlayer();
  final AudioPlayer _deathPlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();

  // File paths on disk (populated during init).
  String? _flapPath;
  String? _scorePath;
  String? _deathPath;
  String? _clickPath;

  bool _ready = false;
  bool _muted = false;

  void _log(String msg) {
    if (kDebugMode) print('[AudioManager] $msg');
  }

  /// Call once at app startup. Synthesises WAV files into temp directory.
  Future<void> init() async {
    if (_ready) return;

    try {
      final dir = await getTemporaryDirectory();
      final soundDir = Directory('${dir.path}/neon_flappy_sounds');
      if (!await soundDir.exists()) {
        await soundDir.create(recursive: true);
      }

      _flapPath = '${soundDir.path}/flap.wav';
      _scorePath = '${soundDir.path}/score.wav';
      _deathPath = '${soundDir.path}/death.wav';
      _clickPath = '${soundDir.path}/click.wav';

      // ── Synthesise and persist each sound ─────────────────────────────
      await File(_flapPath!).writeAsBytes(_synthSweep(
        startHz: 500, endHz: 1800,
        durationSec: 0.08, volume: 0.50, sampleRate: 44100,
      ));
      _log('Wrote flap.wav (${File(_flapPath!).lengthSync()} bytes)');

      await File(_scorePath!).writeAsBytes(_synthTwoTone(
        freq1: 880, freq2: 1320,
        durationSec: 0.18, volume: 0.45, sampleRate: 44100,
      ));
      _log('Wrote score.wav (${File(_scorePath!).lengthSync()} bytes)');

      await File(_deathPath!).writeAsBytes(_synthSweep(
        startHz: 400, endHz: 60,
        durationSec: 0.35, volume: 0.55, sampleRate: 44100,
        distortion: true,
      ));
      _log('Wrote death.wav (${File(_deathPath!).lengthSync()} bytes)');

      await File(_clickPath!).writeAsBytes(_synthSweep(
        startHz: 1000, endHz: 1200,
        durationSec: 0.05, volume: 0.35, sampleRate: 44100,
      ));
      _log('Wrote click.wav (${File(_clickPath!).lengthSync()} bytes)');

      // ── Configure players ─────────────────────────────────────────────
      await _flapPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _scorePlayer.setPlayerMode(PlayerMode.lowLatency);
      await _deathPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _clickPlayer.setPlayerMode(PlayerMode.lowLatency);

      await _flapPlayer.setVolume(1.0);
      await _scorePlayer.setVolume(1.0);
      await _deathPlayer.setVolume(1.0);
      await _clickPlayer.setVolume(1.0);

      // Verify files exist.
      for (final p in [_flapPath!, _scorePath!, _deathPath!, _clickPath!]) {
        if (!File(p).existsSync()) {
          _log('WARNING: $p does not exist after write!');
        }
      }

      _ready = true;
      _log('Audio init complete ✓');
    } catch (e, stack) {
      _log('Audio init failed: $e\n$stack');
      _ready = false;
    }
  }

  bool toggleMute() {
    _muted = !_muted;
    return _muted;
  }

  bool get isMuted => _muted;

  // ── Public play methods ─────────────────────────────────────────────────

  void playFlap() {
    HapticFeedback.lightImpact();
    _playFile(_flapPlayer, _flapPath);
  }

  void playScore() {
    HapticFeedback.mediumImpact();
    _playFile(_scorePlayer, _scorePath);
  }

  void playDeath() {
    HapticFeedback.heavyImpact();
    _playFile(_deathPlayer, _deathPath);
  }

  void playClick() {
    HapticFeedback.selectionClick();
    _playFile(_clickPlayer, _clickPath);
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────
  void dispose() {
    _flapPlayer.dispose();
    _scorePlayer.dispose();
    _deathPlayer.dispose();
    _clickPlayer.dispose();
  }

  // ── Private: play from file path ────────────────────────────────────────

  Future<void> _playFile(AudioPlayer player, String? path) async {
    if (!_ready || _muted || path == null) return;
    try {
      // Ensure the player is stopped before replaying.
      await player.stop();
      final source = DeviceFileSource(path);
      await player.play(source);
      _log('Playing: $path');
    } catch (e) {
      _log('Play error for $path: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  WAV SYNTHESIS  –  generates 16‑bit PCM mono WAV byte arrays
  // ═══════════════════════════════════════════════════════════════════════

  Uint8List _synthSweep({
    required double startHz,
    required double endHz,
    required double durationSec,
    required double volume,
    required int sampleRate,
    bool distortion = false,
  }) {
    final numSamples = (sampleRate * durationSec).round();
    final samples = Int16List(numSamples);
    double phase = 0;
    final rng = Random(42);

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      final freq = startHz + (endHz - startHz) * t;
      final env = _envelope(t);

      double sample = sin(phase) * env * volume;

      if (distortion) {
        sample = (sample * 3.5).clamp(-1.0, 1.0) * 0.6;
        sample += (rng.nextDouble() - 0.5) * 0.12 * env;
      }

      samples[i] = (sample * 32767).round().clamp(-32768, 32767);
      phase += 2 * pi * freq / sampleRate;
    }

    return _encodeWav(samples, sampleRate);
  }

  Uint8List _synthTwoTone({
    required double freq1,
    required double freq2,
    required double durationSec,
    required double volume,
    required int sampleRate,
  }) {
    final numSamples = (sampleRate * durationSec).round();
    final half = numSamples ~/ 2;
    final samples = Int16List(numSamples);
    double phase1 = 0, phase2 = 0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      final env = _envelope(t);
      double sample;

      if (i < half) {
        sample = sin(phase1) * 0.7 + sin(phase2) * 0.3;
        phase1 += 2 * pi * freq1 / sampleRate;
        phase2 += 2 * pi * freq2 / sampleRate;
      } else {
        sample = sin(phase2);
        phase2 += 2 * pi * freq2 / sampleRate;
      }

      samples[i] = (sample * env * volume * 32767).round().clamp(-32768, 32767);
    }

    return _encodeWav(samples, sampleRate);
  }

  double _envelope(double t) {
    if (t < 0.05) return t / 0.05;
    if (t < 0.70) return 1.0;
    return (1.0 - t) / 0.30;
  }

  Uint8List _encodeWav(Int16List samples, int sampleRate) {
    const bitsPerSample = 16;
    const numChannels = 1;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * blockAlign;
    final fileSize = 36 + dataSize;

    final wav = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(wav);

    // RIFF header
    wav[0] = 0x52; wav[1] = 0x49; wav[2] = 0x46; wav[3] = 0x46;
    bd.setUint32(4, fileSize, Endian.little);
    wav[8] = 0x57; wav[9] = 0x41; wav[10] = 0x56; wav[11] = 0x45;

    // fmt sub‑chunk
    wav[12] = 0x66; wav[13] = 0x6D; wav[14] = 0x74; wav[15] = 0x20;
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // data sub‑chunk
    wav[36] = 0x64; wav[37] = 0x61; wav[38] = 0x74; wav[39] = 0x61;
    bd.setUint32(40, dataSize, Endian.little);

    // PCM samples
    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return wav;
  }
}
