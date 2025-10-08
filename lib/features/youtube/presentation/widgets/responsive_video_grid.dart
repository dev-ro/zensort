import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_grid_card.dart';

class ResponsiveVideoGrid extends StatelessWidget {
  final List<LikedVideo> videos;

  const ResponsiveVideoGrid({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Choose a max tile width that yields rectangular tiles on web
        double maxExtent = 360;
        if (constraints.maxWidth <= 420) maxExtent = 320;

        // Estimate childAspectRatio: 16:9 thumbnail + ~96px text/padding area
        // Height = width*(9/16) + 96  => aspect = width / height
        // For stability across widths, compute at runtime
        double estimateAspect(double width) => width / (width * 9 / 16 + 96);
        final sampleWidth = (constraints.maxWidth / (constraints.maxWidth / maxExtent).ceil()).clamp(220, maxExtent);
        final childAspectRatio = estimateAspect(sampleWidth.toDouble());

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) => VideoGridCard(video: videos[index]),
        );
      },
    );
  }
}
