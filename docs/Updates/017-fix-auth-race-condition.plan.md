<!-- 34c40bf9-018a-41e8-baba-d99eee6bfe54 0aa5e8f8-b733-4818-9069-ee20614ef14b -->
# Fix Race Condition in YouTubeBloc Authentication Flow

## Problem Analysis

The race condition occurs in `_onAuthStatusChanged` (lines 69-152) where:

1. `_likedVideosSubscription` is set up at line 108
2. The sync/eager load decision runs asynchronously at line 124 via `Future(() async { ... })`
3. If `watchLikedVideos()` emits cached data immediately, it triggers `_onLikedVideosUpdated` before the decision completes
4. This causes premature state emissions and potential duplicate sync/load operations

## Solution

Reorder the operations in `_onAuthStatusChanged` to ensure the decision logic completes atomically before any stream subscriptions are established.

### Changes to `lib/features/youtube/presentation/bloc/youtube_bloc.dart`

**Step 1: Move the decision logic before stream setup**

In `_onAuthStatusChanged` method (lines 78-136), restructure to:

1. Set sync progress stream first (lines 95-103) - this can stay early since it doesn't emit cached data
2. **Execute and await the sync/eager load decision (current lines 124-136)** - make this synchronous/awaited
3. **Only after decision completes**, set up `_likedVideosSubscription` (current lines 108-121)
4. Remove `_shouldCheckForAutoSync` flag entirely - no longer needed since decision happens first

**Step 2: Remove obsolete auto-sync logic**

In `_onLikedVideosUpdated` method (lines 320-381):

- Remove the `_shouldCheckForAutoSync` check (lines 333-344)
- Remove the early return for empty videos
- Simplify to always emit loaded state with whatever videos are received

**Step 3: Clean up unused flag**

- Remove `_shouldCheckForAutoSync` field declaration (line 33)
- Remove flag reset in unauthentication handler (line 141)

## Implementation Details

### Modified Flow

```dart
// In _onAuthStatusChanged:
if (authState is Authenticated && authState.accessToken != null && !_isInitialLoadDispatched) {
  _isInitialLoadDispatched = true;
  emit(YoutubeLoading());
  
  // Cancel existing subscriptions
  _syncProgressSubscription?.cancel();
  _likedVideosSubscription?.cancel();
  
  // Set up sync progress monitoring (non-blocking)
  _syncProgressSubscription = _youtubeRepository.getSyncProgressStream().listen(...);
  
  // Make sync/eager load decision BEFORE setting up video stream
  try {
    final remote = await _youtubeRepository.fetchRemoteLikedVideosTotal();
    final local = await _youtubeRepository.fetchLocalLikedVideosCount();
    if (remote > local) {
      add(SyncLikedVideos());
    } else {
      add(LoadAllVideosEager());
    }
  } catch (_) {
    add(LoadAllVideosEager());
  }
  
  // NOW set up reactive liked videos stream (after decision made)
  _likedVideosSubscription = _youtubeRepository.watchLikedVideos().listen(...);
}
```

### Simplified `_onLikedVideosUpdated`

```dart
void _onLikedVideosUpdated(_LikedVideosUpdated event, Emitter<YoutubeState> emit) {
  // Removed auto-sync check - decision already made in _onAuthStatusChanged
  _verifyTotalsOnceAsync(event.videos.length);
  
  final currentQuery = state is YoutubeLoaded ? (state as YoutubeLoaded).searchQuery : '';
  final allVideos = event.videos;
  
  // Build and emit shelves based on current query
  if (currentQuery.isEmpty) {
    final shelves = _buildBaseShelves(allVideos);
    emit(YoutubeLoaded(...));
  } else {
    final filtered = _filterVideos(allVideos, query);
    emit(YoutubeLoaded(...));
  }
}
```

## Benefits

1. **Eliminates race condition**: Decision logic completes atomically before stream can emit
2. **Clearer control flow**: Sequential operations are easier to reason about
3. **Removes redundant flag**: `_shouldCheckForAutoSync` no longer needed
4. **Simplifies handler**: `_onLikedVideosUpdated` becomes a pure reactive handler

## Testing Considerations

- Verify sync triggers when remote > local
- Verify eager load triggers when remote <= local or on error
- Verify no duplicate syncs occur
- Verify stream emissions after decision don't trigger unintended operations