import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';
import 'package:zensort/widgets/thumbnail_placeholder.dart';

void main() {
  group('VideoListItem thumbnail optimization', () {
    testWidgets('should show placeholder directly for private video without network request', (tester) async {
      // Arrange
      const privateVideo = LikedVideo(
        id: 'test_id',
        title: 'Private video',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: privateVideo),
          ),
        ),
      );

      // Assert
      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing); // No Image.network widget should be created
    });

    testWidgets('should show placeholder directly for deleted video without network request', (tester) async {
      // Arrange
      const deletedVideo = LikedVideo(
        id: 'test_id',
        title: 'Deleted video',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: deletedVideo),
          ),
        ),
      );

      // Assert
      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('should show placeholder directly for Music Library Uploads by title', (tester) async {
      // Arrange
      const musicLibraryVideo = LikedVideo(
        id: 'test_id',
        title: 'Music Library Uploads',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: musicLibraryVideo),
          ),
        ),
      );

      // Assert
      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('should show placeholder directly for Music Library Uploads by channel', (tester) async {
      // Arrange
      const musicLibraryVideo = LikedVideo(
        id: 'test_id',
        title: 'Some Song',
        channelName: 'Music Library Uploads',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: musicLibraryVideo),
          ),
        ),
      );

      // Assert
      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('should attempt to load image for regular video', (tester) async {
      // Arrange
      const regularVideo = LikedVideo(
        id: 'test_id',
        title: 'How to Build a Flutter App',
        channelName: 'Flutter Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: regularVideo),
          ),
        ),
      );

      // Assert - Should create Image.network widget for regular videos
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should show placeholder for empty thumbnail URL regardless of optimization', (tester) async {
      // Arrange
      const videoWithoutThumbnail = LikedVideo(
        id: 'test_id',
        title: 'Regular Video',
        channelName: 'Regular Channel',
        thumbnailUrl: '',
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoListItem(video: videoWithoutThumbnail),
          ),
        ),
      );

      // Assert
      expect(find.byType(ThumbnailPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}