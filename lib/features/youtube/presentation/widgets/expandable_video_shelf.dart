import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/presentation/widgets/responsive_video_grid.dart';

class ExpandableVideoShelf extends StatefulWidget {
  final String title;
  final List<LikedVideo> videos;
  final bool initiallyExpanded;

  const ExpandableVideoShelf({
    super.key,
    required this.title,
    required this.videos,
    this.initiallyExpanded = false,
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
      onExpansionChanged: (value) => setState(() => _expanded = value),
      title: Text(widget.title, style: titleStyle),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (widget.videos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'No videos',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ResponsiveVideoGrid(videos: widget.videos),
      ],
    );
  }
}
