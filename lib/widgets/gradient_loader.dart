import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A branded spinning loader using the ZenSort circular logo SVG.
class GradientLoader extends StatefulWidget {
  const GradientLoader({super.key, this.size = 40.0});

  final double size;

  @override
  State<GradientLoader> createState() => _GradientLoaderState();
}

class _GradientLoaderState extends State<GradientLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: SvgPicture.asset(
          'assets/images/zensort_logo.svg',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}
