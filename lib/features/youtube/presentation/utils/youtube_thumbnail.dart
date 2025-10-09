String buildHighQualityThumbnailUrl(String videoId) {
  // hqdefault is reliable; maxres may not exist for all videos.
  // This util is isolated so we can upgrade to a backend-provided best URL later.
  return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}
