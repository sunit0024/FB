import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// FlashOverlay – a brief full‑screen white flash that plays on death,
/// then fades out and removes itself. Gives satisfying "impact" feedback.
/// ──────────────────────────────────────────────────────────────────────────────
class FlashOverlay extends PositionComponent {
  FlashOverlay({required Vector2 gameSize})
      : super(
          size: gameSize,
          position: Vector2.zero(),
          priority: 20, // render on top of everything
        );

  double _alpha = 0.8;
  static const double _fadeSpeed = 3.0; // fully transparent in ~0.27s

  @override
  void update(double dt) {
    super.update(dt);
    _alpha -= _fadeSpeed * dt;
    if (_alpha <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_alpha <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.white.withOpacity(_alpha.clamp(0.0, 1.0)),
    );
  }
}
