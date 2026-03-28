import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// A single pipe segment (top or bottom). Rendered as a neon glowing pillar.
/// ──────────────────────────────────────────────────────────────────────────────
class Pipe extends PositionComponent with HasGameRef<FlappyBirdGame> {
  Pipe({
    required Vector2 pipePosition,
    required Vector2 pipeSize,
    required this.isTop,
  }) : super(
          position: pipePosition,
          size: pipeSize,
          anchor: Anchor.topLeft,
          priority: 2, // above background (0), below player (5)
        );

  final bool isTop;

  // Neon palette.
  static const Color _pipeColor = Color(0xFF00FF88);
  static const Color _pipeEdge = Color(0xFF00FFAA);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.x -= gameRef.currentSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Gradient fill – central highlight for a 3D tubular look.
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.x, 0),
        [
          _pipeColor.withOpacity(0.4),
          _pipeEdge,
          _pipeColor.withOpacity(0.4),
        ],
        [0.0, 0.5, 1.0],
      );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, bodyPaint);

    // Inner vertical stripe highlights.
    final stripePaint = Paint()
      ..color = const Color(0xFF66FFCC).withOpacity(0.12)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(size.x * 0.3, 0), Offset(size.x * 0.3, size.y), stripePaint);
    canvas.drawLine(
        Offset(size.x * 0.7, 0), Offset(size.x * 0.7, size.y), stripePaint);

    // Neon edge glow.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _pipeEdge
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawRRect(rrect, edgePaint);

    // Cap (lip at the pipe opening).
    const capHeight = 26.0;
    const capExtrude = 9.0;
    final Rect capRect;
    if (isTop) {
      capRect = Rect.fromLTWH(-capExtrude, size.y - capHeight,
          size.x + capExtrude * 2, capHeight);
    } else {
      capRect =
          Rect.fromLTWH(-capExtrude, 0, size.x + capExtrude * 2, capHeight);
    }
    final capRRect =
        RRect.fromRectAndRadius(capRect, const Radius.circular(5));

    // Cap body gradient.
    final capPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(capRect.left, 0),
        Offset(capRect.right, 0),
        [
          _pipeEdge.withOpacity(0.5),
          const Color(0xFFAAFFDD),
          _pipeEdge.withOpacity(0.5),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(capRRect, capPaint);

    // Cap glow stroke.
    canvas.drawRRect(
      capRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _pipeEdge
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────────
/// An invisible scoring zone placed between a pipe pair.
/// Uses position‑based detection (no hitbox needed) to increment score.
/// ──────────────────────────────────────────────────────────────────────────────
class PipeScoreZone extends PositionComponent
    with HasGameRef<FlappyBirdGame> {
  PipeScoreZone({required Vector2 pos, required Vector2 zoneSize})
      : super(position: pos, size: zoneSize, anchor: Anchor.topLeft);

  bool _scored = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state != GameState.playing) return;
    position.x -= gameRef.currentSpeed * dt;

    // Score when the trailing edge of the pipe passes the player X.
    final playerX = gameRef.size.x * 0.25;
    if (!_scored && position.x + size.x < playerX) {
      _scored = true;
      gameRef.incrementScore();
    }
  }
}

/// Shared pipe constants.
abstract class PipeConstants {
  static const double baseSpeed = 200; // px/s (starting speed)
  static const double width = 64;
  static const double gapSize = 160; // vertical gap between pipes
  static const double spawnInterval = 1.8; // seconds between pairs
}
