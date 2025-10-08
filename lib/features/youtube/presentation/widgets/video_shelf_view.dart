import 'package:flutter/material.dart';
import 'package:zensort/features/youtube/domain/entities/video_shelf.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';

class VideoShelfView extends StatelessWidget {
  final VideoShelf shelf;

  const VideoShelfView({super.key, required this.shelf});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            shelf.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: 180, // Adjust height as needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.videos.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: 240, // Adjust width as needed
                child: VideoListItem(video: shelf.videos[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
