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
/// ──────────────────────────────────────────────────────────────────────────────
class Player extends PositionComponent
    with HasGameRef<FlappyBirdGame>, CollisionCallbacks {
  Player()
      : super(
          size: Vector2.all(_radius * 2),
          anchor: Anchor.center,
          priority: 5,
        );

  // ── Tuning ──────────────────────────────────────────────────────────────
  static const double _radius = 22;
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

  @override
  Future<void> onLoad() async {
    position = Vector2(gameRef.size.x * 0.25, gameRef.size.y * 0.45);
    _velocityY = 0;
    _trail.clear();

    // Load via Flame's image cache (looks in assets/images/).
    _birdImage = await gameRef.images.load('bird.png');

    add(CircleHitbox(
      radius: _radius * 0.72,
      anchor: Anchor.center,
      position: size / 2,
    ));
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
      gameRef.gameOverSequence();
    }
  }

  @override
  void render(Canvas canvas) {
    // ── Trail particles ─────────────────────────────────────────────────
    for (final p in _trail) {
      final dx = p.x - position.x;
      final dy = p.y - position.y;
      final alpha = (p.life / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(_radius + dx, _radius + dy),
        p.radius * alpha,
        Paint()
          ..color = const Color(0xFFFF4444).withOpacity(alpha * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    final center = Offset(_radius, _radius);
    final glowIntensity = 0.6 + 0.4 * sin(_glowPhase);

    // ── Outer neon glow aura ────────────────────────────────────────────
    canvas.drawCircle(
      center,
      _radius * 1.8,
      Paint()
        ..shader = ui.Gradient.radial(center, _radius * 1.8, [
          const Color(0xFFFF0000).withOpacity(0.0),
          const Color(0xFFFF4444).withOpacity(0.18 * glowIntensity),
          const Color(0xFFFF0000).withOpacity(0.0),
        ], [0.0, 0.55, 1.0])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Bird sprite ─────────────────────────────────────────────────────
    if (_birdImage != null) {
      final bounceY = _flapAnim * -4;
      final spriteSize = _radius * 2;

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

      canvas.drawImageRect(_birdImage!, src, dst, Paint());
    } else {
      // Fallback while image loads.
      canvas.drawCircle(center, _radius, Paint()..color = const Color(0xFFFF2222));
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
