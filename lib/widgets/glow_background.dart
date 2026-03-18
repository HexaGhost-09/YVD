import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlowBackground extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;
  final double opacity;

  const GlowBackground({
    super.key,
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.color,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
       .scale(duration: 5.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
       .blurXY(begin: 80, end: 120),
    );
  }
}
