import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Ground – the scrolling neon‑grid floor at the bottom of the screen.
/// Matches pipe speed so the grid scrolls in sync with obstacles.
/// ──────────────────────────────────────────────────────────────────────────────
class Ground extends PositionComponent with HasGameRef<FlappyBirdGame> {
  Ground({required Vector2 gameSize})
      : super(
          position: Vector2(0, gameSize.y - FlappyBirdGame.groundHeight),
          size: Vector2(gameSize.x, FlappyBirdGame.groundHeight),
          priority: 10,
        );

  bool scrolling = false;
  double _scrollX = 0;

  void onParentResize(Vector2 newSize) {
    position = Vector2(0, newSize.y - FlappyBirdGame.groundHeight);
    size = Vector2(newSize.x, FlappyBirdGame.groundHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (scrolling) {
      // ★ Uses effectiveSpeed so Time Warp also slows the ground.
      _scrollX += gameRef.effectiveSpeed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Base gradient.
    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, h),
        [const Color(0xFF0A001A), const Color(0xFF1A0533)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), basePaint);

    // Top edge neon line (magenta).
    canvas.drawLine(
      Offset(0, 1),
      Offset(w, 1),
      Paint()
        ..color = const Color(0xFFFF00FF)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Wider softer glow underneath.
    canvas.drawLine(
      Offset(0, 1),
      Offset(w, 1),
      Paint()
        ..color = const Color(0xFFFF00FF).withOpacity(0.25)
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Grid lines (retro‑futuristic synthwave ground).
    final gridPaint = Paint()
      ..color = const Color(0xFF6B1D6E).withOpacity(0.4)
      ..strokeWidth = 1;

    // Horizontal lines.
    for (double y = 12; y < h; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Vertical lines (scrolling with pipe speed).
    const spacing = 30.0;
    final startX = -(_scrollX % spacing);
    for (double x = startX; x < w + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
  }
}
