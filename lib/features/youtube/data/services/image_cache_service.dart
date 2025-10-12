import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized image cache configuration for YouTube video thumbnails.
///
/// Provides optimized cache settings for large video collections (500-1000+ videos)
/// with bounded memory and disk usage to prevent performance degradation.
class ImageCacheService {
  static const String _cacheKey = 'youtube_thumbnails';

  // Stale duration - 7 days before checking for updates
  static const Duration _staleDuration = Duration(days: 7);

  static CacheManager? _cacheManager;

  /// Get the configured cache manager instance.
  ///
  /// Creates a singleton cache manager with optimized settings for video thumbnails.
  static CacheManager get cacheManager {
    _cacheManager ??= CacheManager(
      Config(
        _cacheKey,
        maxNrOfCacheObjects: 2000, // Support 1000+ videos with buffer
        stalePeriod: _staleDuration,
        repo: JsonCacheInfoRepository(databaseName: _cacheKey),
        fileService: HttpFileService(),
      ),
    );
    return _cacheManager!;
  }

  /// Generate a consistent cache key for a video thumbnail.
  ///
  /// Uses video ID as the primary key to ensure consistent caching
  /// across app restarts and prevent duplicate cache entries.
  static String getCacheKey(String videoId) {
    return 'youtube_thumb_$videoId';
  }

  /// Build the high-quality thumbnail URL for a video.
  ///
  /// Uses hqdefault.jpg which provides 480x360 resolution - optimal
  /// balance between quality and file size for video thumbnails.
  static String buildThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  /// Get optimized CachedNetworkImage configuration for video thumbnails.
  ///
  /// Returns a map of configuration options optimized for video thumbnails
  /// with proper cache sizing and memory management.
  static Map<String, dynamic> getImageConfig(String videoId) {
    return {
      'cacheKey': getCacheKey(videoId),
      'memCacheWidth': 480, // Match hqdefault width
      'maxWidthDiskCache': 480,
      'cacheManager': cacheManager,
    };
  }

  /// Preload a batch of video thumbnails for viewport optimization.
  ///
  /// Loads images in the background to improve perceived performance
  /// when user scrolls through large video collections.
  static Future<void> preloadThumbnails(List<String> videoIds) async {
    final futures = videoIds.take(10).map((videoId) {
      final url = buildThumbnailUrl(videoId);
      return cacheManager.downloadFile(url);
    });

    try {
      await Future.wait(futures);
    } catch (e) {
      // Silent failure for preloading - don't disrupt user experience
      debugPrint('Thumbnail preload failed: $e');
    }
  }

  /// Clear the image cache (useful for testing or manual cache management).
  static Future<void> clearCache() async {
    await cacheManager.emptyCache();
  }

  /// Get current cache size in bytes.
  static Future<int> getCacheSize() async {
    // Note: getCacheInfo() method may not be available in all versions
    // This is a placeholder implementation
    return 0;
  }

  /// Check if a thumbnail is cached locally.
  static Future<bool> isCached(String videoId) async {
    final url = buildThumbnailUrl(videoId);
    final fileInfo = await cacheManager.getFileFromCache(url);
    return fileInfo != null;
  }
}
