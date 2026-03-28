import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game.dart';
import 'pipe.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Player (the "bird") – loads bird.png from assets/images/ via Flame,
/// renders it with a neon glow aura, trail particles, and tilt physics.
///
/// Supports power‑up effects:
///   • Ghost Mode  – semi‑transparent, ignores pipe collisions, blinks before end
///   • Mini‑Bird   – 50 % scale with adjusted hitbox
/// ──────────────────────────────────────────────────────────────────────────────
class Player extends PositionComponent
    with HasGameRef<FlappyBirdGame>, CollisionCallbacks {
  Player()
      : super(
          size: Vector2.all(_baseRadius * 2),
          anchor: Anchor.center,
          priority: 5,
        );

  // ── Tuning ──────────────────────────────────────────────────────────────
  static const double _baseRadius = 22;
  static const double _gravity = 1200;
  static const double _flapVelocity = -420;
  static const double _maxVelocity = 600;

  double _velocityY = 0;
  double _glowPhase = 0;
  double _flapAnim = 0;

  // Trail particles.
  final List<_TrailParticle> _trail = [];
  double _trailTimer = 0;
  final Random _rng = Random();

  // Sprite loaded from assets/images/bird.png.
  ui.Image? _birdImage;

  // ── Power‑up visual state ───────────────────────────────────────────────
  bool _ghostActive = false;
  bool _miniActive = false;
  double _blinkTimer = 0;

  /// Current effective radius (changes for mini‑bird).
  double get _radius => _miniActive ? _baseRadius * 0.5 : _baseRadius;

  CircleHitbox? _hitbox;

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.25, gameRef.size.y * 0.45);
    _velocityY = 0;
    _trail.clear();

    // Load via Flame's image cache (looks in assets/images/).
    _birdImage = await gameRef.images.load('bird.png');

    _hitbox = CircleHitbox(
      radius: _baseRadius * 0.72,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_hitbox!);
  }

  // ── Power‑up callbacks (called from game.dart) ──────────────────────────

  void onGhostModeChanged(bool active) {
    _ghostActive = active;
    _blinkTimer = 0;
  }

  void onMiniBirdChanged(bool active) {
    _miniActive = active;
    _rebuildHitbox();
  }

  void _rebuildHitbox() {
    _hitbox?.removeFromParent();
    final newR = _radius * 0.72;
    final newSize = _radius * 2;
    size = Vector2.all(newSize);
    _hitbox = CircleHitbox(
      radius: newR,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_hitbox!);
  }

  void flap() {
    _velocityY = _flapVelocity;
    _flapAnim = 1.0;

    for (int i = 0; i < 4; i++) {
      _trail.add(_TrailParticle(
        x: position.x - _radius,
        y: position.y + (_rng.nextDouble() - 0.5) * _radius,
        life: 0.4 + _rng.nextDouble() * 0.3,
        vx: -30 - _rng.nextDouble() * 40,
        vy: 20 + _rng.nextDouble() * 30,
        radius: 2 + _rng.nextDouble() * 3,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    _velocityY += _gravity * dt;
    _velocityY = _velocityY.clamp(-_maxVelocity, _maxVelocity);
    position.y += _velocityY * dt;

    angle = (_velocityY / _maxVelocity) * (pi / 4);
    _glowPhase += dt * 4;
    _flapAnim = (_flapAnim - dt * 6).clamp(0.0, 1.0);

    // ── Ghost blink timer ───────────────────────────────────────────────
    if (_ghostActive) {
      _blinkTimer += dt;
    }

    // ── Trail particles ─────────────────────────────────────────────────
    _trailTimer += dt;
    if (_trailTimer > 0.04) {
      _trailTimer = 0;
      _trail.add(_TrailParticle(
        x: position.x - _radius * 0.8,
        y: position.y + (_rng.nextDouble() - 0.5) * 6,
        life: 0.25 + _rng.nextDouble() * 0.2,
        vx: -20 - _rng.nextDouble() * 20,
        vy: (_rng.nextDouble() - 0.5) * 15,
        radius: 1.5 + _rng.nextDouble() * 2,
      ));
    }
    for (final p in _trail) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
    _trail.removeWhere((p) => p.life <= 0);

    // ── Boundary checks ─────────────────────────────────────────────────
    if (position.y + _radius >= gameRef.playAreaHeight) {
      position.y = gameRef.playAreaHeight - _radius;
      gameRef.gameOverSequence();
    }
    if (position.y - _radius < 0) {
      position.y = _radius;
      _velocityY = 0;
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Pipe) {
      // Ghost mode → ignore pipe collisions entirely.
      if (gameRef.ghostMode) return;

      // Otherwise trigger game over (which checks for extra life internally).
      gameRef.gameOverSequence();
    }
  }

  @override
  void render(Canvas canvas) {
    // ── Compute ghost alpha ─────────────────────────────────────────────
    double masterAlpha = 1.0;
    if (_ghostActive) {
      if (gameRef.ghostBlinking) {
        // Rapid blink: 10 Hz toggle
        masterAlpha = (sin(_blinkTimer * 20) > 0) ? 0.8 : 0.15;
      } else {
        masterAlpha = 0.4; // semi‑transparent during ghost
      }
    }

    // ── Derive drawing radius from current state ────────────────────────
    final drawRadius = _radius;
    final center = Offset(size.x / 2, size.y / 2);

    // ── Trail particles ─────────────────────────────────────────────────
    for (final p in _trail) {
      final dx = p.x - position.x;
      final dy = p.y - position.y;
      final alpha = (p.life / 0.45).clamp(0.0, 1.0);

      // Ghost‑mode trail colour shifts to cyan.
      final trailColor = _ghostActive
          ? const Color(0xFF00FFFF)
          : const Color(0xFFFF4444);

      canvas.drawCircle(
        Offset(center.dx + dx, center.dy + dy),
        p.radius * alpha,
        Paint()
          ..color = trailColor.withOpacity(alpha * 0.6 * masterAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    final glowIntensity = 0.6 + 0.4 * sin(_glowPhase);

    // Ghost‑mode aura shifts to cyan, normal is red.
    final auraColor =
        _ghostActive ? const Color(0xFF00FFFF) : const Color(0xFFFF0000);

    // ── Outer neon glow aura ────────────────────────────────────────────
    canvas.drawCircle(
      center,
      drawRadius * 1.8,
      Paint()
        ..shader = ui.Gradient.radial(center, drawRadius * 1.8, [
          auraColor.withOpacity(0.0),
          auraColor.withOpacity(0.18 * glowIntensity * masterAlpha),
          auraColor.withOpacity(0.0),
        ], [0.0, 0.55, 1.0])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Bird sprite ─────────────────────────────────────────────────────
    if (_birdImage != null) {
      final bounceY = _flapAnim * -4;
      final spriteSize = drawRadius * 2;

      final src = Rect.fromLTWH(
        0, 0,
        _birdImage!.width.toDouble(),
        _birdImage!.height.toDouble(),
      );
      final dst = Rect.fromCenter(
        center: center + Offset(0, bounceY),
        width: spriteSize,
        height: spriteSize,
      );

      final paint = Paint();
      if (masterAlpha < 1.0) {
        paint.color = Color.fromRGBO(255, 255, 255, masterAlpha);
      }

      canvas.drawImageRect(_birdImage!, src, dst, paint);
    } else {
      // Fallback while image loads.
      canvas.drawCircle(
          center,
          drawRadius,
          Paint()
            ..color =
                const Color(0xFFFF2222).withOpacity(masterAlpha));
    }
  }
}

class _TrailParticle {
  double x, y, life, vx, vy, radius;
  _TrailParticle({
    required this.x, required this.y, required this.life,
    required this.vx, required this.vy, required this.radius,
  });
}
