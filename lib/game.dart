import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'components/background.dart';
import 'components/player.dart';
import 'components/pipe.dart';
import 'components/pipe_manager.dart';
import 'components/ground.dart';
import 'components/flash_overlay.dart';
import 'components/audio_manager.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Game states
/// ──────────────────────────────────────────────────────────────────────────────
enum GameState { menu, playing, gameOver }

/// ──────────────────────────────────────────────────────────────────────────────
/// Main Flame game class – orchestrates all components and state transitions.
///
///  Render priority guide:
///    0  – NeonBackground
///    2  – Pipes
///    5  – Player
///   10  – Ground
///   20  – FlashOverlay (death effect)
/// ──────────────────────────────────────────────────────────────────────────────
class FlappyBirdGame extends FlameGame
    with TapCallbacks, HasCollisionDetection {
  FlappyBirdGame({required this.onGameOver});

  /// Callback fired when the game ends (passes current score to Flutter).
  final void Function(int score) onGameOver;

  // ── Audio ───────────────────────────────────────────────────────────────
  final AudioManager audio = AudioManager();

  // ── State ────────────────────────────────────────────────────────────────
  GameState state = GameState.menu;
  int score = 0;

  /// Exposed to Flutter overlay via [ValueListenableBuilder].
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

  // ── Difficulty ───────────────────────────────────────────────────────────
  double get currentSpeed {
    return (PipeConstants.baseSpeed + score * 3.8).clamp(200.0, 350.0);
  }

  // ── Components (nullable to avoid late-init crashes) ────────────────────
  NeonBackground? _background;
  Ground? _ground;
  Player? _player;
  PipeManager? _pipeManager;
  FlashOverlay? _flash;

  bool _loaded = false;

  // ── Configuration ───────────────────────────────────────────────────────
  static const double groundHeight = 80;
  double get playAreaHeight => size.y - groundHeight;

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    // Initialise audio (synthesises WAV buffers — fast, ~2 ms).
    await audio.init();

    _background = NeonBackground();
    _ground = Ground(gameSize: size);
    await add(_background!);
    await add(_ground!);

    _loaded = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_loaded) {
      _ground?.onParentResize(size);
    }
  }

  // ── Public API (called from Flutter overlays) ───────────────────────────

  void startGame() {
    _player?.removeFromParent();
    _pipeManager?.clearAllPipes();
    _pipeManager?.removeFromParent();
    _flash?.removeFromParent();

    score = 0;
    scoreNotifier.value = 0;
    state = GameState.playing;

    _player = Player();
    _pipeManager = PipeManager();
    add(_player!);
    add(_pipeManager!);

    overlays.add('ScoreHUD');
  }

  void resetToMenu() {
    _player?.removeFromParent();
    _pipeManager?.clearAllPipes();
    _pipeManager?.removeFromParent();
    _flash?.removeFromParent();
    _player = null;
    _pipeManager = null;
    state = GameState.menu;
    overlays.remove('ScoreHUD');
  }

  void gameOverSequence() {
    if (state == GameState.gameOver) return;
    state = GameState.gameOver;

    // ★ Death sound + heavy haptic.
    audio.playDeath();

    _flash = FlashOverlay(gameSize: size);
    add(_flash!);

    onGameOver(score);

    Future.delayed(const Duration(milliseconds: 350), () {
      overlays.remove('ScoreHUD');
      overlays.add('GameOver');
    });
  }

  // ── Scoring ─────────────────────────────────────────────────────────────
  void incrementScore() {
    score++;
    scoreNotifier.value = score;

    // ★ Score ding + medium haptic.
    audio.playScore();
  }

  // ── Input ───────────────────────────────────────────────────────────────
  @override
  void onTapDown(TapDownEvent event) {
    if (state == GameState.playing) {
      _player?.flap();
      // ★ Flap chirp + light haptic.
      audio.playFlap();
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded) return;
    _background?.scrolling = (state == GameState.playing);
    _ground?.scrolling = (state == GameState.playing);
  }

  @override
  Color backgroundColor() => const Color(0xFF0D0221);
}
