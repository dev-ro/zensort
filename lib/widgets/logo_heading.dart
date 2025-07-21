import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zensort/theme.dart';

/// A reusable heading with the ZenSort logo and a title, tightly spaced.
class LogoHeading extends StatelessWidget {
  final String title;
  final TextStyle? style;
  final double logoSize;
  final double spacing;

  const LogoHeading({
    Key? key,
    required this.title,
    this.style,
    this.logoSize = 36,
    this.spacing = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/zensort_logo.svg',
          height: logoSize,
          width: logoSize,
        ),
        SizedBox(width: spacing),
        LayoutBuilder(
          builder: (context, constraints) {
            return ShaderMask(
              shaderCallback: (Rect bounds) {
                return ZenSortTheme.primaryGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                );
              },
              child: Text(
                title,
                style: (style ?? Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(
                      fontWeight: FontWeight.w300, // Less bold
                      fontSize: 24, // Slightly larger
                      color: Colors.white, // Needed for ShaderMask
                    ),
              ),
            );
          },
        ),
      ],
    );
  }
}
