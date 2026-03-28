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
import 'components/power_up.dart';
import 'components/power_up_manager.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Game states
/// ──────────────────────────────────────────────────────────────────────────────
enum GameState { menu, playing, gameOver }

/// ──────────────────────────────────────────────────────────────────────────────
/// Active power‑up info exposed to the Flutter HUD layer.
/// ──────────────────────────────────────────────────────────────────────────────
class ActivePower {
  final PowerUpType type;
  final double remaining; // seconds left
  final double total;     // original duration
  ActivePower(this.type, this.remaining, this.total);
}

/// ──────────────────────────────────────────────────────────────────────────────
/// Main Flame game class – orchestrates all components and state transitions.
///
///  Render priority guide:
///    0  – NeonBackground
///    2  – Pipes
///    3  – PowerUps
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

  // ── Power‑up state ──────────────────────────────────────────────────────
  bool ghostMode = false;
  bool timeWarp = false;
  bool miniBird = false;
  bool hasExtraLife = false;

  double _ghostTimer = 0;
  double _timeWarpTimer = 0;
  double _miniBirdTimer = 0;

  static const double _powerDuration = 8.0;

  /// Ghost mode is blinking in the last 2 seconds.
  bool get ghostBlinking => ghostMode && _ghostTimer <= 2.0;

  /// Notifier that pushes active powers + extra life status to HUD.
  final ValueNotifier<List<ActivePower>> activePowersNotifier =
      ValueNotifier<List<ActivePower>>([]);
  final ValueNotifier<bool> extraLifeNotifier = ValueNotifier<bool>(false);

  // ── Difficulty ───────────────────────────────────────────────────────────
  double get currentSpeed {
    return (PipeConstants.baseSpeed + score * 3.8).clamp(200.0, 350.0);
  }

  /// Effective speed after time‑warp modifier. Used by pipes, ground,
  /// power‑ups, and background scrolling.
  double get effectiveSpeed => currentSpeed * speedMultiplier;

  /// 1.0 normally, 0.5 during Time Warp.
  double get speedMultiplier => timeWarp ? 0.5 : 1.0;

  // ── Components (nullable to avoid late-init crashes) ────────────────────
  NeonBackground? _background;
  Ground? _ground;
  Player? _player;
  PipeManager? _pipeManager;
  PowerUpManager? _powerUpManager;
  FlashOverlay? _flash;

  bool _loaded = false;

  // ── Configuration ───────────────────────────────────────────────────────
  static const double groundHeight = 80;
  double get playAreaHeight => size.y - groundHeight;

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    // Initialise audio.
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
    _powerUpManager?.clearAll();
    _powerUpManager?.removeFromParent();
    _flash?.removeFromParent();

    // Reset power‑up state.
    _clearAllPowers();

    score = 0;
    scoreNotifier.value = 0;
    state = GameState.playing;

    _player = Player();
    _pipeManager = PipeManager();
    _powerUpManager = PowerUpManager();
    add(_player!);
    add(_pipeManager!);
    add(_powerUpManager!);

    overlays.add('ScoreHUD');
    overlays.add('PowerUpHUD');
  }

  void resetToMenu() {
    _player?.removeFromParent();
    _pipeManager?.clearAllPipes();
    _pipeManager?.removeFromParent();
    _powerUpManager?.clearAll();
    _powerUpManager?.removeFromParent();
    _flash?.removeFromParent();
    _player = null;
    _pipeManager = null;
    _powerUpManager = null;
    _clearAllPowers();
    state = GameState.menu;
    overlays.remove('ScoreHUD');
    overlays.remove('PowerUpHUD');
  }

  void gameOverSequence() {
    if (state == GameState.gameOver) return;

    // ── Extra Life check ──────────────────────────────────────────────
    if (hasExtraLife) {
      hasExtraLife = false;
      extraLifeNotifier.value = false;

      // Grant 2 seconds of ghost mode so the player doesn't die again.
      ghostMode = true;
      _ghostTimer = 2.0;
      _player?.onGhostModeChanged(true);
      _updatePowerNotifiers();
      return; // Don't trigger game over!
    }

    state = GameState.gameOver;

    // ★ Death sound + heavy haptic.
    audio.playDeath();

    _flash = FlashOverlay(gameSize: size);
    add(_flash!);

    onGameOver(score);

    Future.delayed(const Duration(milliseconds: 350), () {
      overlays.remove('ScoreHUD');
      overlays.remove('PowerUpHUD');
      overlays.add('GameOver');
    });
  }

  // ── Power‑Up Activation ─────────────────────────────────────────────────

  void activatePowerUp(PowerUpType type) {
    audio.playScore(); // re‑use score ding for pick‑up feedback

    switch (type) {
      case PowerUpType.ghostMode:
        ghostMode = true;
        _ghostTimer = _powerDuration;
        _player?.onGhostModeChanged(true);
        break;

      case PowerUpType.timeWarp:
        timeWarp = true;
        _timeWarpTimer = _powerDuration;
        break;

      case PowerUpType.miniBird:
        miniBird = true;
        _miniBirdTimer = _powerDuration;
        _player?.onMiniBirdChanged(true);
        break;

      case PowerUpType.extraLife:
        hasExtraLife = true;
        extraLifeNotifier.value = true;
        break;
    }
    _updatePowerNotifiers();
  }

  void _clearAllPowers() {
    ghostMode = false;
    timeWarp = false;
    miniBird = false;
    hasExtraLife = false;
    _ghostTimer = 0;
    _timeWarpTimer = 0;
    _miniBirdTimer = 0;
    activePowersNotifier.value = [];
    extraLifeNotifier.value = false;
  }

  void _updatePowerNotifiers() {
    final list = <ActivePower>[];
    if (ghostMode) {
      list.add(ActivePower(PowerUpType.ghostMode, _ghostTimer, _powerDuration));
    }
    if (timeWarp) {
      list.add(ActivePower(PowerUpType.timeWarp, _timeWarpTimer, _powerDuration));
    }
    if (miniBird) {
      list.add(ActivePower(PowerUpType.miniBird, _miniBirdTimer, _powerDuration));
    }
    activePowersNotifier.value = list;
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

    if (state != GameState.playing) return;

    // ── Tick power‑up timers ────────────────────────────────────────────
    bool changed = false;

    if (ghostMode) {
      _ghostTimer -= dt;
      changed = true;
      if (_ghostTimer <= 0) {
        ghostMode = false;
        _ghostTimer = 0;
        _player?.onGhostModeChanged(false);
      }
    }

    if (timeWarp) {
      _timeWarpTimer -= dt;
      changed = true;
      if (_timeWarpTimer <= 0) {
        timeWarp = false;
        _timeWarpTimer = 0;
      }
    }

    if (miniBird) {
      _miniBirdTimer -= dt;
      changed = true;
      if (_miniBirdTimer <= 0) {
        miniBird = false;
        _miniBirdTimer = 0;
        _player?.onMiniBirdChanged(false);
      }
    }

    if (changed) _updatePowerNotifiers();
  }

  @override
  Color backgroundColor() => const Color(0xFF0D0221);
}
