import 'package:flutter/material.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _taglineController;
  late final AnimationController _barController;
  late final AnimationController _glowController;

  // ── Logo: fade + slide up ──
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;

  // ── Wordmark: slide in from left ──
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;

  // ── Tagline: fade in ──
  late final Animation<double> _taglineOpacity;

  // ── Progress bar ──
  late final Animation<double> _barProgress;

  // ── Glow pulse ──
  late final Animation<double> _glowScale;

  @override
  void initState() {
    super.initState();

    // Logo controller — 600ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Wordmark controller — 500ms, starts at 200ms
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Tagline controller — 400ms, starts at 500ms
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Progress bar — 2000ms, starts at 600ms
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Glow pulse — repeating
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // ── Logo animations ──
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // ── Wordmark animations ──
    _wordmarkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(-0.15, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // ── Tagline animation ──
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );

    // ── Progress bar ──
    _barProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeInOut),
    );

    // ── Glow ──
    _glowScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ── Sequence ──
    _runSequence();
  }

  Future<void> _runSequence() async {
    // Logo drops in
    await _logoController.forward();

    // Wordmark slides in (200ms after logo starts)
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();

    // Tagline fades in
    await Future.delayed(const Duration(milliseconds: 80));
    _taglineController.forward();

    // Progress bar fills
    await Future.delayed(const Duration(milliseconds: 150));
    await _barController.forward();

    // Navigate
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _barController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GigColors.background,
      body: SizedBox.expand(
        child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Animated glow behind logo ──
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            child: AnimatedBuilder(
              animation: _glowScale,
              builder: (_, __) => Transform.scale(
                scale: _glowScale.value,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GigColors.primary.withOpacity(0.12),
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo icon
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: GigColors.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: GigColors.background,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Wordmark
              SlideTransition(
                position: _wordmarkSlide,
                child: FadeTransition(
                  opacity: _wordmarkOpacity,
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Gig',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        TextSpan(
                          text: 'Nation',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: GigColors.primary,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              FadeTransition(
                opacity: _taglineOpacity,
                child: const Text(
                  "NIGERIA'S FREELANCE PLATFORM",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                    letterSpacing: 0.14,
                  ),
                ),
              ),
            ],
          ),

          // ── Progress bar at bottom ──
          // ── Progress bar at bottom ──
          Positioned(
            bottom: 64,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _barProgress,
                  builder: (_, __) => Container(
                    width: 130,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _barProgress.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: GigColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white24,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ),
          ),
        ],        // closes Stack children
      ),          // closes Stack
    ),            // closes SizedBox.expand
    );            // closes Scaffold
  }
}