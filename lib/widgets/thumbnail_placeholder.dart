import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A branded thumbnail placeholder using the ZenSort logo for failed or empty video thumbnails.
/// Provides consistent branding instead of generic broken image icons.
class ThumbnailPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double logoSize;

  const ThumbnailPlaceholder({
    super.key,
    this.width = 120,
    this.height = 90,
    this.logoSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/zensort_logo.svg',
              width: logoSize,
              height: logoSize,
              colorFilter: ColorFilter.mode(
                Colors.grey[600]!,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 