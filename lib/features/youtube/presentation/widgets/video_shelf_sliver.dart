import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/video_shelf.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_grid_card.dart';

/// A sliver-based video shelf that provides true lazy rendering for large video collections.
///
/// This widget eliminates the shrinkWrap performance issues by using SliverGrid
/// within a CustomScrollView, enabling efficient rendering of 2000+ videos.
class VideoShelfSliver extends StatelessWidget {
  final VideoShelf shelf;
  final bool isExpanded;
  final bool showBusy;
  final ValueChanged<bool>? onExpansionChanged;

  const VideoShelfSliver({
    super.key,
    required this.shelf,
    required this.isExpanded,
    this.showBusy = false,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        // Shelf header
        SliverToBoxAdapter(child: _buildShelfHeader(context)),
        // Videos grid (only when expanded)
        if (isExpanded) ..._buildVideoGrid(context),
      ],
    );
  }

  Widget _buildShelfHeader(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(80),
        ),
      ),
      child: ListTile(
        title: Text(shelf.title, style: titleStyle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 8),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onTap: () => onExpansionChanged?.call(!isExpanded),
      ),
    );
  }

  List<Widget> _buildVideoGrid(BuildContext context) {
    if (shelf.videos.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No videos',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ];
    }

    return [
      // Videos grid with true lazy rendering
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            // Calculate grid parameters based on available width
            double maxExtent = 360.0;
            if (constraints.crossAxisExtent <= 420) maxExtent = 320.0;

            // Estimate childAspectRatio: 16:9 thumbnail + ~96px text/padding area
            double estimateAspect(double width) =>
                width / (width * 9 / 16 + 96);
            final sampleWidth =
                (constraints.crossAxisExtent /
                        (constraints.crossAxisExtent / maxExtent).ceil())
                    .clamp(220.0, maxExtent);
            final childAspectRatio = estimateAspect(sampleWidth.toDouble());

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
                childAspectRatio: childAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                // TRUE lazy rendering - only visible items build
                return VideoGridCard(video: shelf.videos[index]);
              }, childCount: shelf.videos.length),
            );
          },
        ),
      ),
    ];
  }
}
