import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Responsive Utility
// Usage: context.isTablet, R.pad(context), R.sp(context, 16)
// ─────────────────────────────────────────────

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isTablet => screenWidth >= 600;
  bool get isLargeTablet => screenWidth >= 900;
}

class R {
  R._();

  /// Horizontal page padding — wider on tablets
  static double pad(BuildContext ctx) =>
      ctx.isLargeTablet ? 64 : ctx.isTablet ? 40 : 20;

  /// Max content width for tablets (centres content)
  static double maxWidth(BuildContext ctx) =>
      ctx.isTablet ? 680 : double.infinity;

  /// Scale a font size proportionally
  static double sp(BuildContext ctx, double base) {
    if (ctx.isLargeTablet) return base * 1.25;
    if (ctx.isTablet) return base * 1.12;
    return base;
  }

  /// Scale an icon/spacing size proportionally
  static double sz(BuildContext ctx, double base) {
    if (ctx.isLargeTablet) return base * 1.2;
    if (ctx.isTablet) return base * 1.1;
    return base;
  }

  /// Wrap content in a centred max-width box for tablets
  static Widget constrain(BuildContext ctx, Widget child) {
    if (!ctx.isTablet) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth(ctx)),
        child: child,
      ),
    );
  }
}