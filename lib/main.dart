import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'components/audio_manager.dart';
import 'components/power_up.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Entry‑point  –  wraps the Flame [GameWidget] with Flutter overlay widgets
/// for the Main Menu, Score HUD, Power‑Up HUD, and Game‑Over screen.
/// ──────────────────────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FlappyBirdApp());
}

class FlappyBirdApp extends StatelessWidget {
  const FlappyBirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final FlappyBirdGame _game;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _game = FlappyBirdGame(onGameOver: _onGameOver);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _highScore = prefs.getInt('high_score') ?? 0);
  }

  Future<void> _saveHighScore(int score) async {
    if (score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('high_score', score);
      if (mounted) setState(() => _highScore = score);
    }
  }

  void _onGameOver(int score) => _saveHighScore(score);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<FlappyBirdGame>(
        game: _game,
        overlayBuilderMap: {
          'MainMenu': (context, game) => _MainMenuOverlay(
                onPlay: () {
                  game.audio.playClick();
                  game.overlays.remove('MainMenu');
                  game.startGame();
                },
                highScore: _highScore,
                audio: game.audio,
              ),
          'ScoreHUD': (context, game) => _ScoreHUD(game: game),
          'PowerUpHUD': (context, game) => _PowerUpHUD(game: game),
          'GameOver': (context, game) => _GameOverOverlay(
                score: game.score,
                highScore: _highScore,
                onRestart: () {
                  game.audio.playClick();
                  game.overlays.remove('GameOver');
                  game.startGame();
                },
                onMenu: () {
                  game.audio.playClick();
                  game.overlays.remove('GameOver');
                  game.overlays.add('MainMenu');
                  game.resetToMenu();
                },
              ),
        },
        initialActiveOverlays: const ['MainMenu'],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED STYLE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

TextStyle _neonStyle(double size, Color color,
    {FontWeight weight = FontWeight.bold}) {
  return GoogleFonts.orbitron(
    fontSize: size,
    fontWeight: weight,
    color: color,
    shadows: [
      Shadow(color: color.withOpacity(0.9), blurRadius: 12),
      Shadow(color: color.withOpacity(0.6), blurRadius: 30),
      Shadow(color: color.withOpacity(0.3), blurRadius: 60),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN MENU
// ═══════════════════════════════════════════════════════════════════════════════

class _MainMenuOverlay extends StatefulWidget {
  final VoidCallback onPlay;
  final int highScore;
  final AudioManager audio;
  const _MainMenuOverlay({
    required this.onPlay,
    required this.highScore,
    required this.audio,
  });

  @override
  State<_MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<_MainMenuOverlay> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.85),
            Colors.black.withOpacity(0.80),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // ── Mute toggle (top‑right) ─────────────────────────────────
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => widget.audio.toggleMute());
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00FFFF).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.audio.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: const Color(0xFF00FFFF),
                    size: 24,
                  ),
                ),
              ),
            ),
            // ── Centre content ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NEON',
                      style: _neonStyle(52, const Color(0xFF00FFFF))),
                  Text('FLAPPY',
                      style: _neonStyle(46, const Color(0xFFFF00FF))),
                  const SizedBox(height: 16),
                  const _PulsingText(),
                  const SizedBox(height: 40),
                  _NeonButton(
                      label: 'PLAY',
                      color: const Color(0xFF00FF88),
                      onTap: widget.onPlay),
                  const SizedBox(height: 24),
                  if (widget.highScore > 0)
                    Text('HIGH SCORE: ${widget.highScore}',
                        style: _neonStyle(18, const Color(0xFFFFAA00))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text widget that gently pulses opacity for a "breathing" effect.
class _PulsingText extends StatefulWidget {
  const _PulsingText();
  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.3, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text('TAP TO FLAP',
          style:
              _neonStyle(14, const Color(0xFF00FF88), weight: FontWeight.w400)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SCORE HUD
// ═══════════════════════════════════════════════════════════════════════════════

class _ScoreHUD extends StatelessWidget {
  final FlappyBirdGame game;
  const _ScoreHUD({required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<int>(
            valueListenable: game.scoreNotifier,
            builder: (_, value, __) =>
                Text('$value', style: _neonStyle(48, Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  POWER‑UP HUD  –  Extra Life indicator  +  active power countdown bars
// ═══════════════════════════════════════════════════════════════════════════════

class _PowerUpHUD extends StatelessWidget {
  final FlappyBirdGame game;
  const _PowerUpHUD({required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // ── Extra Life indicator (top‑left) ─────────────────────────────
          Positioned(
            top: 18,
            left: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: game.extraLifeNotifier,
              builder: (_, hasLife, __) {
                return AnimatedOpacity(
                  opacity: hasLife ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFF69B4).withOpacity(0.7),
                          width: 1.5),
                      color: const Color(0xFFFF69B4).withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF69B4).withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite,
                            color: Color(0xFFFF69B4), size: 18),
                        const SizedBox(width: 5),
                        Text(
                          'EXTRA LIFE',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF69B4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Active power countdown bars (top‑centre, below score) ───────
          Positioned(
            top: 76,
            left: 24,
            right: 24,
            child: ValueListenableBuilder<List<ActivePower>>(
              valueListenable: game.activePowersNotifier,
              builder: (_, powers, __) {
                if (powers.isEmpty) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: powers.map((p) => _PowerBar(power: p)).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single shrinking progress bar for an active timed power‑up.
class _PowerBar extends StatelessWidget {
  final ActivePower power;
  const _PowerBar({required this.power});

  Color get _color {
    switch (power.type) {
      case PowerUpType.ghostMode:
        return const Color(0xFF00FFFF);
      case PowerUpType.timeWarp:
        return const Color(0xFFBB66FF);
      case PowerUpType.miniBird:
        return const Color(0xFFFFDD00);
      case PowerUpType.extraLife:
        return const Color(0xFFFF69B4);
    }
  }

  String get _label {
    switch (power.type) {
      case PowerUpType.ghostMode:
        return 'GHOST';
      case PowerUpType.timeWarp:
        return 'SLOW';
      case PowerUpType.miniBird:
        return 'MINI';
      case PowerUpType.extraLife:
        return 'LIFE';
    }
  }

  IconData get _icon {
    switch (power.type) {
      case PowerUpType.ghostMode:
        return Icons.visibility_off;
      case PowerUpType.timeWarp:
        return Icons.slow_motion_video;
      case PowerUpType.miniBird:
        return Icons.compress;
      case PowerUpType.extraLife:
        return Icons.favorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        (power.remaining / power.total).clamp(0.0, 1.0);
    final isLow = power.remaining <= 2.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Icon + label
          Icon(_icon, color: _color, size: 14),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: Text(
              _label,
              style: GoogleFonts.orbitron(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Progress bar
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: _color.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: isLow
                        ? _color.withOpacity(0.9)
                        : _color.withOpacity(0.7),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withOpacity(isLow ? 0.8 : 0.4),
                        blurRadius: isLow ? 10 : 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Seconds remaining
          SizedBox(
            width: 28,
            child: Text(
              '${power.remaining.ceil()}s',
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isLow ? Colors.redAccent : _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GAME OVER
// ═══════════════════════════════════════════════════════════════════════════════

class _GameOverOverlay extends StatefulWidget {
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.score,
    required this.highScore,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _scale = Tween(begin: 0.7, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_ctrl);
    _opacity = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final best =
        widget.score > widget.highScore ? widget.score : widget.highScore;
    final isNewBest = widget.score > widget.highScore;

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GAME OVER',
                    style: _neonStyle(42, const Color(0xFFFF2255))),
                const SizedBox(height: 30),
                Text('SCORE', style: _neonStyle(18, Colors.white70)),
                Text('${widget.score}',
                    style: _neonStyle(52, const Color(0xFF00FFFF))),
                const SizedBox(height: 12),
                Text('BEST', style: _neonStyle(18, Colors.white70)),
                Text('$best',
                    style: _neonStyle(36, const Color(0xFFFFAA00))),
                if (isNewBest) ...[
                  const SizedBox(height: 8),
                  Text('★ NEW HIGH SCORE ★',
                      style: _neonStyle(16, const Color(0xFFFFDD00))),
                ],
                const SizedBox(height: 40),
                _NeonButton(
                    label: 'RETRY',
                    color: const Color(0xFF00FF88),
                    onTap: widget.onRestart),
                const SizedBox(height: 16),
                _NeonButton(
                    label: 'MENU',
                    color: const Color(0xFFFF00FF),
                    onTap: widget.onMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  REUSABLE NEON BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NeonButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 16,
                spreadRadius: 1),
          ],
        ),
        child: Text(label, style: _neonStyle(22, color)),
      ),
    );
  }
}
