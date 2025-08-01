import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

void main() {
  group('LikedVideo shouldSkipThumbnailLoad', () {
    test('should return true for private video', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'Private video',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, true);
    });

    test('should return true for deleted video', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'Deleted video',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, true);
    });

    test('should return true for video titled Music Library Uploads', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'Music Library Uploads',
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, true);
    });

    test('should return true for video from Music Library Uploads channel', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'Some Song Title',
        channelName: 'Music Library Uploads',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, true);
    });

    test('should return false for regular public video', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'How to Build a Flutter App',
        channelName: 'Flutter Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, false);
    });

    test('should return false for video with empty title and channel', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: '',
        channelName: '',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, false);
    });

    test('should be case sensitive for title matching', () {
      // Arrange
      const video = LikedVideo(
        id: 'test_id',
        title: 'private video', // lowercase
        channelName: 'Some Channel',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Act
      final shouldSkip = video.shouldSkipThumbnailLoad();

      // Assert
      expect(shouldSkip, false); // Should be case sensitive
    });
  });
}