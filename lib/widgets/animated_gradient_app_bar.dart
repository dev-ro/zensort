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
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                colors: ZenSortTheme.primaryGradient.colors
                    .map((color) => color.withOpacity(0.8))
                    .toList(),
                begin: Alignment(_animation.value, -1.0),
                end: Alignment(-_animation.value, 1.0),
              ),
            ),
          ),
        );
      },
    );
  }
}
