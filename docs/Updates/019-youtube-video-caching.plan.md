<!-- 00ea17aa-e186-4d88-8a9f-723461d2444a a90356b0-116d-4abc-bf46-e3f48a51370c -->
# YouTube Performance Optimization Plan

## Issues Identified

1. **Cache not preventing loading modal**: Loading modal still appears on sign-in even with cached videos
2. **Slow shelf expansion**: Large shelves (All Videos, Music) take significant time to render
3. **No image caching**: Network images loaded fresh every time
4. **Eager rendering**: All videos in a shelf render immediately when expanded (no lazy rendering)

## Important Distinction: Loading vs Rendering

**Eager Loading (KEEP THIS)**: Load ALL video data from Firestore into memory

- ✅ Required for complete search results
- ✅ Allows filtering/searching across entire library
- ✅ Already implemented correctly

**Lazy Rendering (IMPLEMENT THIS)**: Render only visible video cards in the viewport

- 🎯 Data is in memory, but widgets only built for visible items
- 🎯 Dramatically faster shelf expansion
- 🎯 Does NOT affect search - all data still searchable

## Performance Bottleneck Analysis

### Current Flow Problems:

- **GridView.builder with shrinkWrap: true** - Renders ALL items immediately instead of lazily
- **No image caching** - Browser cache helps but not optimal for Flutter web
- **Hydrated state restoration issue** - Videos persist but loading modal still shows

## Optimization Strategy

### 1. Fix Cache Restoration (Critical)

**Problem**: Loading modal appears despite cached videos being present

**Root Cause**: The `_onAuthStatusChanged` check happens but the auth flow might be re-emitting `YoutubeLoading` elsewhere

**Solution**:

- Debug print statements to trace why loading modal shows with cache
- Ensure `YoutubeLoaded` state is emitted BEFORE any auth subscriptions
- Verify `fromJson` is being called correctly on app restart

### 2. Implement Image Caching (High Impact)

**Problem**: No persistent image caching - images reload from network each time

**Solution**: Use `cached_network_image` package

**Benefits**:

- Automatic disk and memory caching
- Progressive loading with placeholders
- Better performance than raw `Image.network`
- Handles cache invalidation automatically
- Keep `hqdefault.jpg` quality (480x360) - quality is good

**Files to modify**:

- Add `cached_network_image` to `pubspec.yaml`
- Update `VideoGridCard` to use `CachedNetworkImage`
- Update `VideoListItem` to use `CachedNetworkImage`

### 3. Implement Virtual/Lazy Rendering (High Impact)

**Problem**: `GridView.builder` with `shrinkWrap: true` and `NeverScrollableScrollPhysics` renders ALL items

**Current**: 500 videos = 500 widgets built immediately (even though data is already loaded)

**Solution**: Use `CustomScrollView` with `SliverGrid` for true lazy rendering

- ALL video data stays in memory (eager loading preserved)
- Only render visible items + buffer (lazy rendering)
- Use `SliverChildBuilderDelegate` which only calls builder for visible items
- Remove `shrinkWrap: true` and `NeverScrollableScrollPhysics`
- Expand shelves with proper scrolling physics

**Why This Works for Search**:

- Search filters the in-memory `allVideos` list
- Filtered results passed to grid widget
- Grid lazily renders the filtered list
- All search results available, just rendered on-demand

### 4. Optimize Shelf Expansion State (Medium Impact)

**Problem**: `expandedShelfKey` persistence might cause issues

**Solution**:

- Don't persist `expandedShelfKey` in hydrated state
- Start with all shelves collapsed on app load
- Faster initial render, user expands as needed

## Implementation Priority

### Phase 1: Critical Fixes (Immediate)

1. **Fix cache restoration** - Debug why loading modal still appears
2. **Add cached_network_image** - Implement persistent image caching with hqdefault quality
3. **Implement lazy rendering** - Virtual scrolling with CustomScrollView

**Expected Impact**: 70-90% faster shelf expansion, no loading modal on restart

### Phase 2: Polish (Next)

4. **Optimize shelf state** - Don't persist expansion state
5. **Add loading skeletons** - Better UX during image loads

**Expected Impact**: Smoother UX, faster initial load

## Technical Implementation Details

### Cached Network Image

```dart
// Add to pubspec.yaml
dependencies:
  cached_network_image: ^3.3.1

// Update VideoGridCard - keep hqdefault quality
CachedNetworkImage(
  imageUrl: buildHighQualityThumbnailUrl(video.id), // Keep hqdefault
  fit: BoxFit.cover,
  placeholder: (context, url) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),
  errorWidget: (context, url, error) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.image_not_supported),
  ),
  memCacheWidth: 480, // Match hqdefault width
  maxWidthDiskCache: 480,
)
```

### Lazy Rendering with Virtual Scrolling

**Key Change**: Replace `GridView.builder` with `CustomScrollView` + `SliverGrid`

```dart
// Current: ResponsiveVideoGrid (eager rendering)
GridView.builder(
  physics: const NeverScrollableScrollPhysics(), // ❌ No scrolling
  shrinkWrap: true, // ❌ Renders ALL items
  itemCount: videos.length,
  itemBuilder: (context, index) => VideoGridCard(video: videos[index]),
)

// New: ResponsiveVideoGrid (lazy rendering)
CustomScrollView(
  physics: const ClampingScrollPhysics(), // ✅ Proper scrolling
  shrinkWrap: true, // Keep for shelf embedding
  slivers: [
    SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360.0,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // ✅ Only called for visible items
          return VideoGridCard(video: videos[index]);
        },
        childCount: videos.length, // ✅ All data available
      ),
    ),
  ],
)
```

**How This Preserves Search**:

1. User searches "flutter tutorial"
2. BLoC filters `allVideos` list (eager loaded data)
3. Filtered list passed to ResponsiveVideoGrid: `ResponsiveVideoGrid(videos: filteredVideos)`
4. Grid renders filtered list lazily: only visible cards built
5. User scrolls, more cards built on demand
6. ALL search results accessible, just rendered progressively

### Optimize Shelf Expansion State

```dart
// Don't persist expandedShelfKey in toJson
Map<String, dynamic> toJson() {
  return {
    'searchQuery': searchQuery,
    // Remove: if (expandedShelfKey != null) 'expandedShelfKey': expandedShelfKey,
    'isFullyLoaded': isFullyLoaded,
    if (allVideos.isNotEmpty) 'allVideos': allVideos.map((v) => v.toJson()).toList(),
  };
}

// Don't restore expandedShelfKey in fromJson
factory YoutubeLoaded.fromJson(Map<String, dynamic> json) {
  // ...
  return YoutubeLoaded(
    shelves: shelves,
    allVideos: allVideos,
    searchQuery: query,
    expandedShelfKey: null, // ✅ Always start collapsed
    isFullyLoaded: isFullyLoaded,
  );
}
```

## Files to Modify

1. `lib/features/youtube/presentation/bloc/youtube_bloc.dart` - Fix cache restoration logic
2. `pubspec.yaml` - Add cached_network_image dependency
3. `lib/features/youtube/presentation/widgets/video_grid_card.dart` - Use CachedNetworkImage
4. `lib/features/youtube/presentation/widgets/video_list_item.dart` - Use CachedNetworkImage
5. `lib/features/youtube/presentation/widgets/responsive_video_grid.dart` - Implement lazy rendering with CustomScrollView
6. `lib/features/youtube/presentation/bloc/youtube_state.dart` - Don't persist expandedShelfKey

## Success Metrics

- **Cache hit**: No loading modal on app restart with cached videos
- **Shelf expansion**: < 500ms to expand any shelf (currently 2-3+ seconds)
- **Image loading**: Images appear progressively, cached on subsequent views
- **Memory usage**: Stable memory with cached images
- **Smooth scrolling**: 60 FPS when scrolling large shelves
- **Search completeness**: ALL results findable (eager loading preserved)

## Architecture Clarification

```
┌─────────────────────────────────────────────────────┐
│ DATA LAYER (Eager Loading - KEEP AS IS)            │
│ • Firestore: All videos loaded into memory         │
│ • Search: Filters in-memory data                   │
│ • Result: Complete dataset always available        │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ PRESENTATION LAYER (Lazy Rendering - OPTIMIZE)     │
│ • Grid Widget: Only builds visible cards           │
│ • Images: Cached for instant display               │
│ • Result: Fast rendering, smooth scrolling         │
└─────────────────────────────────────────────────────┘
```

### To-dos

- [ ] Update YoutubeLoaded toJson/fromJson to persist allVideos list
- [ ] Ensure LikedVideo entity has toJson/fromJson methods for serialization
- [ ] Modify _onAuthStatusChanged to check for cached videos and load immediately if available
- [ ] Add silent background count comparison when loading from cache
- [ ] Test full cache workflow: first load, cached load, sync, sign out