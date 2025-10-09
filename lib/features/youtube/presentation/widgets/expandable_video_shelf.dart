import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/presentation/widgets/responsive_video_grid.dart';

class ExpandableVideoShelf extends StatefulWidget {
  final String title;
  final List<LikedVideo> videos;
  final bool initiallyExpanded;
  final VoidCallback? onEndReached; // Triggered when near bottom
  final VoidCallback? onExpand; // Trigger initial load on expand
  final bool isLoading;
  final bool hasMore;

  const ExpandableVideoShelf({
    super.key,
    required this.title,
    required this.videos,
    this.initiallyExpanded = false,
    this.onEndReached,
    this.onExpand,
    this.isLoading = false,
    this.hasMore = false,
  });

  @override
  State<ExpandableVideoShelf> createState() => _ExpandableVideoShelfState();
}

class _ExpandableVideoShelfState extends State<ExpandableVideoShelf> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return ExpansionTile(
      initiallyExpanded: _expanded,
      onExpansionChanged: (value) {
        setState(() => _expanded = value);
        if (value && widget.onExpand != null) widget.onExpand!();
      },
      title: Text(widget.title, style: titleStyle),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (widget.videos.isEmpty && !widget.isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'No videos',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent * 0.7 &&
                  widget.hasMore &&
                  widget.onEndReached != null &&
                  !widget.isLoading) {
                widget.onEndReached!();
              }
              return false;
            },
            child: ResponsiveVideoGrid(videos: widget.videos),
          ),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }
}
