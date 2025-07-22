import 'package:flutter/material.dart';
import 'package:zensort/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final bool isLandingPage = widget.title == null;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return AppBar(
          leading: widget.leading,
          title: isLandingPage
              ? SvgPicture.asset(
                  'assets/images/zensort_logo_wordmark_white.svg',
                  height: 55,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/zensort_logo_white.svg',
                      height: 35,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
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
          actions: isLandingPage
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ElevatedButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Sign Out'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ]
              : null,
          centerTitle: !isLandingPage,
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
