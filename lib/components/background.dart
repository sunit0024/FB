import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// NeonBackground – a multi‑layered parallax background drawn entirely
/// with Canvas (no sprites needed). Layers from back to front:
///   1. Gradient sky (deep purple → sunset orange)
///   2. Twinkling stars
///   3. Distant mountain silhouettes (slow scroll)
///   4. Procedural city skyline with lit windows (medium scroll)
///   5. Soft glowing clouds (varied scroll)
/// ──────────────────────────────────────────────────────────────────────────────
class NeonBackground extends PositionComponent
    with HasGameRef<FlappyBirdGame> {
  NeonBackground() : super(priority: 0);

  bool scrolling = false;

  // Scroll offsets for each parallax layer.
  double _starsOffset = 0;
  double _mountainOffset = 0;
  double _cloudOffset = 0;
  double _cityOffset = 0;

  // Pre‑generated star positions (normalised 0‑1).
  final List<_Star> _stars = [];
  final Random _rng = Random(42);

  // Accumulated time for twinkle animation.
  double _time = 0;

  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    for (int i = 0; i < 90; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.60,
        radius: 0.5 + _rng.nextDouble() * 1.8,
        twinkleSpeed: 1 + _rng.nextDouble() * 3,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (!scrolling) return;

    // ★ Apply speed multiplier so Time Warp slows background too.
    final sm = gameRef.speedMultiplier;
    _starsOffset += 10 * dt * sm;
    _mountainOffset += 25 * dt * sm;
    _cloudOffset += 50 * dt * sm;
    _cityOffset += 70 * dt * sm;
  }

  @override
  void render(Canvas canvas) {
    final w = gameRef.size.x;
    final h = gameRef.size.y;

    // ── 1. Sky gradient ─────────────────────────────────────────────────
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        [
          const Color(0xFF0D0221),
          const Color(0xFF1A0533),
          const Color(0xFF2D1B69),
          const Color(0xFF6B1D6E),
          const Color(0xFFFF6B35),
        ],
        [0.0, 0.25, 0.5, 0.78, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // ── 2. Stars ────────────────────────────────────────────────────────
    for (final star in _stars) {
      final sx = ((star.x * w) - _starsOffset) % w;
      final sy = star.y * h;
      final twinkle =
          0.4 + 0.6 * ((sin(_time * star.twinkleSpeed + star.phase) + 1) / 2);
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(twinkle * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(sx, sy), star.radius, starPaint);
    }

    // ── 3. Distant mountains (slow layer) ───────────────────────────────
    _drawMountains(canvas, w, h, _mountainOffset, h * 0.55, h * 0.20,
        const Color(0xFF1A0533).withOpacity(0.8), 200);
    _drawMountains(canvas, w, h, _mountainOffset * 1.3, h * 0.60, h * 0.15,
        const Color(0xFF2D1B69).withOpacity(0.6), 150);

    // ── 4. City silhouette (mid layer) ──────────────────────────────────
    _drawCitySilhouette(canvas, w, h, _cityOffset);

    // ── 5. Glowing clouds ───────────────────────────────────────────────
    _drawCloud(canvas, w, _cloudOffset, h * 0.22, 120, 35,
        const Color(0xFFFF69B4).withOpacity(0.18));
    _drawCloud(canvas, w, _cloudOffset * 0.7, h * 0.35, 160, 40,
        const Color(0xFFFF00FF).withOpacity(0.12));
    _drawCloud(canvas, w, _cloudOffset * 1.2, h * 0.15, 100, 28,
        const Color(0xFF00FFFF).withOpacity(0.10));
  }

  // ── Helper: sine‑wave mountain range ────────────────────────────────────
  void _drawMountains(Canvas canvas, double w, double h, double offset,
      double baseY, double peakHeight, Color color, double wavelength) {
    final path = Path()..moveTo(0, h);
    for (double x = 0; x <= w + wavelength; x += 4) {
      final nx = (x + offset) / wavelength;
      final y = baseY -
          peakHeight *
              (sin(nx * pi) * 0.5 + sin(nx * pi * 2.3) * 0.3 + 0.2)
                  .clamp(0, 1);
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // ── Helper: procedural city skyline ─────────────────────────────────────
  void _drawCitySilhouette(
      Canvas canvas, double w, double h, double offset) {
    final baseY = h * 0.70;
    final buildingColor = const Color(0xFF120025).withOpacity(0.9);
    final windowColor = const Color(0xFFFFAA00).withOpacity(0.5);

    const buildingWidth = 38.0;
    const spacing = 12.0;
    final totalW = w + buildingWidth + spacing;
    final startX = -(offset % (buildingWidth + spacing));

    for (double x = startX; x < totalW; x += buildingWidth + spacing) {
      final slot = ((x + offset) / (buildingWidth + spacing)).floor();
      final bRng = Random(slot * 17 + 3);
      final bHeight = 40 + bRng.nextDouble() * 100;
      final rect = Rect.fromLTWH(
          x, baseY - bHeight, buildingWidth, bHeight + 200);
      canvas.drawRect(rect, Paint()..color = buildingColor);

      canvas.drawLine(
        Offset(x, baseY - bHeight),
        Offset(x + buildingWidth, baseY - bHeight),
        Paint()
          ..color = const Color(0xFF00FFFF).withOpacity(0.3)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      for (double wy = baseY - bHeight + 8; wy < baseY - 8; wy += 12) {
        for (double wx = x + 6; wx < x + buildingWidth - 6; wx += 10) {
          if (bRng.nextDouble() > 0.4) {
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 5, 6),
              Paint()..color = windowColor,
            );
          }
        }
      }
    }
  }

  // ── Helper: soft blurred cloud cluster ──────────────────────────────────
  void _drawCloud(Canvas canvas, double screenW, double offset, double y,
      double cloudW, double cloudH, Color color) {
    final cx = (screenW - (offset % (screenW + cloudW * 2))) + cloudW;
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cloudH * 0.6);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, y), width: cloudW, height: cloudH),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - cloudW * 0.3, y + 5),
            width: cloudW * 0.6,
            height: cloudH * 0.7),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + cloudW * 0.3, y + 3),
            width: cloudW * 0.5,
            height: cloudH * 0.5),
        paint);
  }
}

/// Data class for a single star in the background.
class _Star {
  final double x, y, radius, twinkleSpeed, phase;
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.twinkleSpeed,
    required this.phase,
  });
}
