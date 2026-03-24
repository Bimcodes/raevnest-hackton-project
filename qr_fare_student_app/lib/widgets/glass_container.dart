import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 28,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.isDark;

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent, // Base must be transparent to allow blur to show through
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: theme.pGlassShadow,
            blurRadius: isDark ? 20 : 30, // Much softer shadows for light mode glass
            spreadRadius: isDark ? 2 : 0,
            offset: isDark ? Offset.zero : const Offset(0, 10), // directional light for light mode
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 0.0 : 25.0, // Disable expensive blur in pure dark mode unless explicitly needed
            sigmaY: isDark ? 0.0 : 25.0,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: theme.pGlassBackground,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: theme.pGlassBorder,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
