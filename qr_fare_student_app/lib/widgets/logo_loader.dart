import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoLoader extends StatefulWidget {
  final double size;
  const LogoLoader({super.key, this.size = 40});

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_controller.value * 2.0 * math.pi),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [Colors.white, Colors.white.withOpacity(0.0)],
              stops: const [0.65, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: Image.asset(
            'assets/images/logo.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.shield,
                color: Theme.of(context).primaryColor,
                size: widget.size,
              );
            },
          ),
        ),
      ),
    );
  }
}
