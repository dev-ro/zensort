import 'package:flutter/material.dart';
import 'package:zensort/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedGradientAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  const AnimatedGradientAppBar({super.key});

  @override
  State<AnimatedGradientAppBar> createState() => _AnimatedGradientAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AnimatedGradientAppBarState extends State<AnimatedGradientAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(); // No reverse, for continuous left-to-right motion

    // Animate from 0 to -1 to slide the gradient to the left, which creates a
    // rightward motion effect.
    _animation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(_controller); // Linear curve for constant speed
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return AppBar(
          title: SvgPicture.asset(
            'assets/images/zensort_logo_wordmark_white.svg',
            height: 45,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ZenSortTheme.appBarGradient.colors
                    .map((color) => color.withOpacity(0.7))
                    .toList(),
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                tileMode: TileMode.repeated,
                transform: _SlideGradientTransform(percent: _animation.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A gradient transform that slides the gradient horizontally.
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform({required this.percent});

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0.0, 0.0);
  }
}
