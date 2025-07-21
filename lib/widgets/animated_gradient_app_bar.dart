import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zensort/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class AnimatedGradientAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;

  const AnimatedGradientAppBar({super.key, this.title, this.leading});

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
      duration: const Duration(seconds: 20),
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
          leading: widget.leading,
          iconTheme: const IconThemeData(color: Colors.white),
          title: null, // We'll handle title in flexibleSpace
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Stack(
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ZenSortTheme.appBarGradient.colors
                        .map((color) => color.withOpacity(0.7))
                        .toList(),
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    tileMode: TileMode.repeated,
                    transform: _SlideGradientTransform(
                      percent: _animation.value,
                    ),
                  ),
                ),
              ),
              // Left-aligned logo (with padding to account for back button)
              Positioned(
                left: kToolbarHeight - 8, // 8px padding after back button
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/zensort_logo_wordmark_white.svg',
                    height: 45, // Adjust as needed
                  ),
                ),
              ),
              // Centered title
              if (widget.title != null)
                Center(
                  child: Text(
                    widget.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
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

/// A branded spinning loader using the ZenSort circular logo SVG.
class GradientLoader extends StatefulWidget {
  const GradientLoader({Key? key, this.size = 40.0}) : super(key: key);

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
