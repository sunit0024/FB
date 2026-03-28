import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game.dart';
import 'player.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Power‑up types and their visual identity.
/// ──────────────────────────────────────────────────────────────────────────────
enum PowerUpType {
  ghostMode,   // Cyan diamond   – pass through pipes
  timeWarp,    // Purple clock   – slow everything down
  miniBird,    // Yellow star    – shrink the bird
  extraLife,   // Pink heart     – one free hit
}

/// ──────────────────────────────────────────────────────────────────────────────
/// PowerUp – a collectible item that floats in the play area.
/// Renders as a glowing geometric shape with a distinct colour per type.
/// Moves left at the same speed as pipes and is removed when off‑screen.
/// ──────────────────────────────────────────────────────────────────────────────
class PowerUp extends PositionComponent
    with HasGameRef<FlappyBirdGame>, CollisionCallbacks {
  PowerUp({required this.type, required Vector2 spawnPosition})
      : super(
          position: spawnPosition,
          size: Vector2.all(_itemSize),
          anchor: Anchor.center,
          priority: 3,
        );

  final PowerUpType type;

  static const double _itemSize = 32;
  double _glowPhase = 0;
  double _bobPhase = 0;
  final double _bobSpeed = 3.0;

  /// Colour palette per power‑up type.
  Color get baseColor {
    switch (type) {
      case PowerUpType.ghostMode:
        return const Color(0xFF00FFFF); // cyan
      case PowerUpType.timeWarp:
        return const Color(0xFFBB66FF); // purple
      case PowerUpType.miniBird:
        return const Color(0xFFFFDD00); // yellow
      case PowerUpType.extraLife:
        return const Color(0xFFFF69B4); // pink
    }
  }

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(
      radius: _itemSize * 0.45,
      anchor: Anchor.center,
      position: size / 2,
    ));
    _bobPhase = Random().nextDouble() * pi * 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;

    // Move left at the effective game speed (respects time warp).
    position.x -= gameRef.effectiveSpeed * dt;
    _glowPhase += dt * 5;
    _bobPhase += dt * _bobSpeed;

    // Gentle vertical bob.
    position.y += sin(_bobPhase) * 0.4;

    // Remove if off‑screen.
    if (position.x < -_itemSize) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      gameRef.activatePowerUp(type);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final glowIntensity = 0.5 + 0.5 * sin(_glowPhase);
    final r = _itemSize / 2;

    // ── Outer glow aura ─────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r * 1.8,
      Paint()
        ..shader = ui.Gradient.radial(center, r * 1.8, [
          baseColor.withOpacity(0.0),
          baseColor.withOpacity(0.2 * glowIntensity),
          baseColor.withOpacity(0.0),
        ], [0.0, 0.5, 1.0])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── Shape per type ──────────────────────────────────────────────────
    switch (type) {
      case PowerUpType.ghostMode:
        _drawDiamond(canvas, center, r);
        break;
      case PowerUpType.timeWarp:
        _drawClock(canvas, center, r);
        break;
      case PowerUpType.miniBird:
        _drawStar(canvas, center, r);
        break;
      case PowerUpType.extraLife:
        _drawHeart(canvas, center, r);
        break;
    }
  }

  // ── Diamond (Ghost Mode) ────────────────────────────────────────────────
  void _drawDiamond(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.7, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.7, c.dy)
      ..close();

    canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));
  }

  // ── Clock shape (Time Warp) ─────────────────────────────────────────────
  void _drawClock(Canvas canvas, Offset c, double r) {
    // Circle
    canvas.drawCircle(
        c,
        r * 0.7,
        Paint()
          ..color = baseColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(
        c,
        r * 0.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));

    // Clock hands
    final handPaint = Paint()
      ..color = baseColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, Offset(c.dx, c.dy - r * 0.45), handPaint);
    canvas.drawLine(c, Offset(c.dx + r * 0.35, c.dy), handPaint);
  }

  // ── Five‑pointed star (Mini‑Bird) ───────────────────────────────────────
  void _drawStar(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + (2 * pi * i / 5);
      final innerAngle = outerAngle + pi / 5;
      final ox = c.dx + r * 0.8 * cos(outerAngle);
      final oy = c.dy + r * 0.8 * sin(outerAngle);
      final ix = c.dx + r * 0.35 * cos(innerAngle);
      final iy = c.dy + r * 0.35 * sin(innerAngle);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));
  }

  // ── Heart (Extra Life) ──────────────────────────────────────────────────
  void _drawHeart(Canvas canvas, Offset c, double r) {
    final path = Path();
    final s = r * 0.8;
    path.moveTo(c.dx, c.dy + s * 0.7);
    path.cubicTo(
        c.dx - s * 1.2, c.dy - s * 0.2,
        c.dx - s * 0.6, c.dy - s * 1.0,
        c.dx, c.dy - s * 0.3);
    path.cubicTo(
        c.dx + s * 0.6, c.dy - s * 1.0,
        c.dx + s * 1.2, c.dy - s * 0.2,
        c.dx, c.dy + s * 0.7);
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));
  }
}
