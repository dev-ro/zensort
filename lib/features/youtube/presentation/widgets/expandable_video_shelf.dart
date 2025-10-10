import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/presentation/widgets/responsive_video_grid.dart';

class ExpandableVideoShelf extends StatelessWidget {
  final String title;
  final List<LikedVideo> videos;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback? onEndReached; // Triggered when near bottom
  final VoidCallback? onExpand; // Trigger initial load on expand
  final bool isLoading;
  final bool hasMore;
  final bool showBusy;

  const ExpandableVideoShelf({
    super.key,
    required this.title,
    required this.videos,
    required this.isExpanded,
    this.onExpansionChanged,
    this.onEndReached,
    this.onExpand,
    this.isLoading = false,
    this.hasMore = false,
    this.showBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return ExpansionTile(
      initiallyExpanded: isExpanded,
      onExpansionChanged: (value) {
        if (value && onExpand != null) onExpand!();
        if (onExpansionChanged != null) onExpansionChanged!(value);
      },
      title: Text(title, style: titleStyle),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (videos.isEmpty && !isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'No videos',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              // Constrain inner scroll to viewport height so shelves can individually infinite-scroll
              final maxHeight = MediaQuery.of(context).size.height * 0.7;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent * 0.7 &&
                        hasMore &&
                        onEndReached != null &&
                        !isLoading) {
                      onEndReached!();
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    child: ResponsiveVideoGrid(videos: videos, isBusy: showBusy),
                  ),
                ),
              );
            },
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }
}
