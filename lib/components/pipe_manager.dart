import 'dart:math';
import 'package:flame/components.dart';
import '../game.dart';
import 'pipe.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// PipeManager – spawns pipe pairs at regular intervals and removes
/// off‑screen pipes to keep memory tidy. Gap size and spawn rate adapt
/// to the current difficulty level via [FlappyBirdGame.currentSpeed].
/// ──────────────────────────────────────────────────────────────────────────────
class PipeManager extends Component with HasGameRef<FlappyBirdGame> {
  PipeManager();

  final Random _rng = Random();
  double _timer = 0;
  final List<Component> _activePipes = [];

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    // Spawn interval shrinks slightly as difficulty increases.
    final interval = PipeConstants.spawnInterval *
        (PipeConstants.baseSpeed / gameRef.currentSpeed);

    _timer += dt;
    if (_timer >= interval) {
      _timer = 0;
      _spawnPipePair();
    }

    // Clean up pipes/zones that have scrolled off the left edge.
    _activePipes.removeWhere((c) {
      if (c is PositionComponent &&
          c.position.x < -(PipeConstants.width + 30)) {
        c.removeFromParent();
        return true;
      }
      return false;
    });
  }

  void _spawnPipePair() {
    final screenH = gameRef.playAreaHeight;

    // Gap shrinks slightly with score (min 120 px).
    final gap =
        (PipeConstants.gapSize - gameRef.score * 1.5).clamp(120.0, PipeConstants.gapSize);

    // Random gap centre between 18% and 82% of the play area.
    final minY = screenH * 0.18 + gap / 2;
    final maxY = screenH * 0.82 - gap / 2;
    final gapCentre = minY + _rng.nextDouble() * (maxY - minY);

    final topHeight = gapCentre - gap / 2;
    final bottomY = gapCentre + gap / 2;
    final bottomHeight = screenH - bottomY;
    final spawnX = gameRef.size.x + 20;

    final topPipe = Pipe(
      pipePosition: Vector2(spawnX, 0),
      pipeSize: Vector2(PipeConstants.width, topHeight),
      isTop: true,
    );

    final bottomPipe = Pipe(
      pipePosition: Vector2(spawnX, bottomY),
      pipeSize: Vector2(PipeConstants.width, bottomHeight),
      isTop: false,
    );

    final scoreZone = PipeScoreZone(
      pos: Vector2(spawnX, gapCentre - gap / 2),
      zoneSize: Vector2(PipeConstants.width, gap),
    );

    gameRef.add(topPipe);
    gameRef.add(bottomPipe);
    gameRef.add(scoreZone);

    _activePipes.addAll([topPipe, bottomPipe, scoreZone]);
  }

  /// Called on game reset to remove all active pipes from the world.
  void clearAllPipes() {
    for (final c in _activePipes) {
      c.removeFromParent();
    }
    _activePipes.clear();
    _timer = 0;
  }
}
