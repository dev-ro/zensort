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
        // Determine a good max tile width; adapt for wide screens
        double maxTileWidth = 340;
        if (constraints.maxWidth >= 1400) {
          maxTileWidth = 360;
        } else if (constraints.maxWidth <= 420) {
          maxTileWidth = 300;
        }
        final crossAxisCount = (constraints.maxWidth / maxTileWidth).clamp(1, 8).floor();
        final spacing = 12.0;
        final gridWidth = constraints.maxWidth - (spacing * (crossAxisCount - 1));
        final tileWidth = gridWidth / crossAxisCount;
        // Match the card's thumbnail aspect and text area; slightly wider than tall
        final childAspectRatio = tileWidth / (tileWidth / (16 / 10) + 64);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) => VideoGridCard(video: videos[index]),
        );
      },
    );
  }
}
