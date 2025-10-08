import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

class VideoGridCard extends StatelessWidget {
  final LikedVideo video;

  const VideoGridCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _Thumbnail(url: video.thumbnailUrl, skip: video.shouldSkipThumbnailLoad()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final bool skip;
  const _Thumbnail({required this.url, required this.skip});

  @override
  Widget build(BuildContext context) {
    if (skip) {
      return Container(color: Theme.of(context).colorScheme.surfaceVariant);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      },
    );
  }
}
