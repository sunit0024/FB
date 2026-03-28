import 'dart:math';
import 'package:flame/components.dart';
import '../game.dart';
import 'pipe.dart';
import 'power_up.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// PowerUpManager – randomly spawns power‑up collectibles in the play area.
///
/// A power‑up is spawned every [_baseInterval] ± random jitter, positioned
/// at a random Y within the safe play area. Only one power‑up of the same
/// type can exist on screen at a time.
/// ──────────────────────────────────────────────────────────────────────────────
class PowerUpManager extends Component with HasGameRef<FlappyBirdGame> {
  final Random _rng = Random();
  double _timer = 0;
  final List<PowerUp> _active = [];

  /// Average seconds between spawns.
  static const double _baseInterval = 7.0;

  /// Spawn chance jitter (±).
  static const double _jitter = 3.0;

  double _nextSpawnAt = 5.0; // first spawn a bit early

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    _timer += dt;
    if (_timer >= _nextSpawnAt) {
      _timer = 0;
      _nextSpawnAt = _baseInterval + (_rng.nextDouble() * 2 - 1) * _jitter;
      _spawnRandomPowerUp();
    }

    // Prune removed power‑ups from tracking list.
    _active.removeWhere((p) => p.isRemoved);
  }

  void _spawnRandomPowerUp() {
    // Pick a random type, weighted so extra life is rarer.
    final roll = _rng.nextDouble();
    PowerUpType type;
    if (roll < 0.30) {
      type = PowerUpType.ghostMode;
    } else if (roll < 0.55) {
      type = PowerUpType.timeWarp;
    } else if (roll < 0.80) {
      type = PowerUpType.miniBird;
    } else {
      type = PowerUpType.extraLife;
    }

    // Don't spawn if one of the same type is already on screen.
    if (_active.any((p) => !p.isRemoved && p.type == type)) return;

    // Position: right edge, random Y within safe play area.
    final screenH = gameRef.playAreaHeight;
    final minY = screenH * 0.12;
    final maxY = screenH * 0.88;
    final y = minY + _rng.nextDouble() * (maxY - minY);
    final x = gameRef.size.x + 40;

    final powerUp = PowerUp(type: type, spawnPosition: Vector2(x, y));
    _active.add(powerUp);
    gameRef.add(powerUp);
  }

  /// Remove all active power‑ups (called on game reset).
  void clearAll() {
    for (final p in _active) {
      p.removeFromParent();
    }
    _active.clear();
    _timer = 0;
    _nextSpawnAt = 5.0;
  }
}
