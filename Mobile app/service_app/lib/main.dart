import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';
import 'screens/splash_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/google_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://whjqloftamimugscbbun.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndoanFsb2Z0YW1pbXVnc2NiYnVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzI4MzIsImV4cCI6MjA5MjkwODgzMn0.s6ttZ20EeCRmsrWkvLuqz9EogjpSBriAE7YH1fn2up8',
  );

  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// Theme Notifier — persists dark/light mode
// ─────────────────────────────────────────────

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
    notifyListeners();
    // Update status bar icons to match theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    notifyListeners();
  }
}

// Global theme notifier instance — accessible anywhere
final themeNotifier = ThemeNotifier();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GigNation',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeNotifier.mode,
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Auth Gate — checks profile_complete for ALL auth methods
// ─────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Listen for auth changes (e.g. email confirmation redirect)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    setState(() => _checking = true);

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Not logged in — show welcome screen
      setState(() {
        _destination = const HomeScreen();
        _checking = false;
      });
      return;
    }

    // Logged in — check if profile is complete
    try {
      final userId = session.user.id;
      final response = await Supabase.instance.client
          .from('profile')
          .select('profile_complete')
          .eq('id', userId)
          .maybeSingle();

      final isComplete = response?['profile_complete'] == true;

      setState(() {
        _destination = isComplete
            ? const HomePage()
            : const ProfileSetupScreen();
        _checking = false;
      });
    } catch (_) {
      // If profile row doesn't exist yet, send to setup
      setState(() {
        _destination = const ProfileSetupScreen();
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: GigColors.backgroundOf(context),
        body: Center(
          child: CircularProgressIndicator(
            color: GigColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return _destination!;
  }
}

// ─────────────────────────────────────────────
// Color System — Dark & Light
// ─────────────────────────────────────────────

class GigColors {
  GigColors._();

  // ── Brand accent — Gold/Amber ──
  static const primary = Color(0xFFD4A017);
  static const primaryDark = Color(0xFFB8880E);
  static const primaryLight = Color(0xFFFFF8E7);
  static const accent = Color(0xFFF5C842);

  // ── Static fallbacks used by splash & const widgets ──
  static const background = Color(0xFF0F0F0F);  // always dark for splash

  // ── Dark mode ──
  static const darkBackground = Color(0xFF0F0F0F);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkCard = Color(0xFF222222);
  static const darkBorder = Color(0xFF2E2E2E);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFF9E9E9E);
  static const darkTextHint = Color(0xFF616161);

  // ── Light mode ──
  static const lightBackground = Color(0xFFFAF9F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE8E4DC);
  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF6B6B6B);
  static const lightTextHint = Color(0xFFABABAB);

  // ── Semantic ──
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);

  // ── Context-aware helpers ──
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorder
          : lightBorder;
}

// ─────────────────────────────────────────────
// Legacy AppColors alias — keeps existing screens working
// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  static const primary = GigColors.primary;
  static const primaryDark = GigColors.primaryDark;
  static const primaryLight = GigColors.primaryLight;
  static const accent = GigColors.accent;
  static const surface = GigColors.lightSurface;
  static const background = GigColors.lightBackground;
  static const card = GigColors.lightCard;
  static const textPrimary = GigColors.lightTextPrimary;
  static const textSecondary = GigColors.lightTextSecondary;
  static const textHint = GigColors.lightTextHint;
  static const border = GigColors.lightBorder;
  static const error = GigColors.error;
  static const success = GigColors.success;
  static const gradientStart = GigColors.primary;
  static const gradientEnd = GigColors.accent;
}

// ─────────────────────────────────────────────
// Text Styles
// ─────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: Colors.white,
  );
}

// ─────────────────────────────────────────────
// App Theme — Light & Dark
// ─────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? GigColors.darkBackground : GigColors.lightBackground;
    final surface = isDark ? GigColors.darkSurface : GigColors.lightSurface;
    final border = isDark ? GigColors.darkBorder : GigColors.lightBorder;
    final textPrimary =
        isDark ? GigColors.darkTextPrimary : GigColors.lightTextPrimary;
    final textHint =
        isDark ? GigColors.darkTextHint : GigColors.lightTextHint;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GigColors.primary,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: isDark ? GigColors.darkCard : GigColors.lightCard,
      dividerColor: border,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: GigColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GigColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: textHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GigColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GigColors.error, width: 1),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary),
        displayLarge: TextStyle(color: textPrimary),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GigColors.primary, GigColors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: GigColors.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, style: AppTextStyles.buttonText),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixWidget;
  final TextInputType keyboardType;
  final String? errorText;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixWidget,
    this.keyboardType = TextInputType.text,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = GigColors.textPrimaryOf(context);
    final textHint = Theme.of(context).brightness == Brightness.dark
        ? GigColors.darkTextHint
        : GigColors.lightTextHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(color: GigColors.textSecondaryOf(context))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(prefixIcon, size: 20, color: textHint),
            suffixIcon: suffixWidget,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Theme Toggle Widget — drop anywhere in your app
// ─────────────────────────────────────────────

class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    return GestureDetector(
      onTap: themeNotifier.toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? GigColors.primary : GigColors.lightBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 13,
              color: isDark ? GigColors.primary : GigColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Home / Welcome Screen
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGoogleLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final error = await GoogleAuthService.signIn();
    if (!mounted) return;
    if (error != null && error != 'Sign-in cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: GigColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    // AuthGate rebuilds automatically and checks profile_complete
    setState(() => _isGoogleLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = GigColors.backgroundOf(context);
    final textPrimary = GigColors.textPrimaryOf(context);
    final textSecondary = GigColors.textSecondaryOf(context);
    final surfaceColor = GigColors.surfaceOf(context);
    final borderColor = GigColors.borderOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background glow circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    GigColors.primary.withOpacity(0.12),
                    GigColors.accent.withOpacity(0.04),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GigColors.accent.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme toggle top right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: const ThemeToggle(),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GigColors.primary, GigColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: GigColors.primary.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Services,\nOn Demand.',
                    style: AppTextStyles.displayLarge
                        .copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Connect with skilled professionals for\nany job — fast, reliable, and trusted.',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: textSecondary),
                  ),
                  const Spacer(flex: 3),
                  Row(
                    children: [
                      _FeatureChip(icon: Icons.verified_rounded, label: 'Verified'),
                      const SizedBox(width: 8),
                      _FeatureChip(icon: Icons.flash_on_rounded, label: 'Fast'),
                      const SizedBox(width: 8),
                      _FeatureChip(icon: Icons.star_rounded, label: 'Top-Rated'),
                    ],
                  ),
                  const SizedBox(height: 36),
                  GradientButton(
                    label: 'Login',
                    onPressed: () => Navigator.push(
                        context, _fadeRoute(const LoginScreen())),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                          context, _fadeRoute(const RegisterScreen())),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor, width: 1.5),
                      ),
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: GigColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _isGoogleLoading
                      ? const Center(
                          child: SizedBox(
                            height: 52,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: GigColors.primary),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _signInWithGoogle,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.g_mobiledata_rounded,
                                    size: 24, color: textPrimary),
                                const SizedBox(width: 10),
                                Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? GigColors.darkTextHint
                              : GigColors.lightTextHint),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: GigColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: GigColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GigColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    );