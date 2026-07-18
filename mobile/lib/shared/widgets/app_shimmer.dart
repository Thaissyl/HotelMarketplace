import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width;
            final slide = width * 2 * _controller.value - width;

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE9EDF3),
                Color(0xFFF7F9FC),
                Color(0xFFE9EDF3),
              ],
              stops: const [0.22, 0.5, 0.78],
              transform: _SlidingGradientTransform(slide),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(slidePercent, 0, 0);
  }
}
