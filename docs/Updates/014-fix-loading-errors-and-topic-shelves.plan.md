<!-- 185349ac-e7c6-4c11-81e5-8a3f8df9f4a5 7d16e265-45ba-46b2-bd75-75ac178d3caa -->
# Fix Loading Errors and Topic Shelves

## Problem Analysis

### 1. Assertion Error (`_dependents.isEmpty`)

- **Root Cause**: Line 34 in `home_screen.dart` uses `context.watch<YouTubeBloc>()` outside the builder context
- **Impact**: Widget attempts rebuild after disposal during sign out
- **Location**: `lib/features/youtube/presentation/screens/home_screen.dart:34`

### 2. Videos Not Displaying in Shelves

- **Root Cause**: Complex nested scrollable architecture (`SingleChildScrollView` > `GridView.builder`) combined with rapid state changes
- **Impact**: Videos don't render properly under each shelf
- **Location**: `lib/features/youtube/presentation/widgets/expandable_video_shelf.dart`

### 3. Topic Filter Navigation Issue

- **Root Cause**: Topic filter switches to "search mode" with no way back to home shelf view
- **Current**: TopicFilterMenu triggers `TopicFilterChanged` event → switches from shelves to filtered single-shelf view
- **Location**: Lines 217-227 in `home_screen.dart`, entire `topic_filter_menu.dart` widget

## Implementation Plan

### Phase 1: Fix Assertion Error

**File**: `lib/features/youtube/presentation/screens/home_screen.dart`

- Remove `context.watch<YouTubeBloc>()` from line 34
- Use `BlocBuilder` or move logic inside existing `BlocConsumer` to safely track sync state
- Ensure no BLoC state access occurs outside proper listener/builder contexts

### Phase 2: Fix Video Display in Shelves

**File**: `lib/features/youtube/presentation/widgets/expandable_video_shelf.dart`

- Review and fix nested scroll architecture
- Ensure `ResponsiveVideoGrid` renders properly within `ExpansionTile`
- Test that videos display correctly when shelves are expanded

### Phase 3: Remove Topic Filter Dropdown

**Files**:

- `lib/features/youtube/presentation/screens/home_screen.dart` (lines 217-227)
- `lib/features/youtube/presentation/widgets/topic_filter_menu.dart` (entire file)

Actions:

- Remove `TopicFilterMenu` widget import and usage from `home_screen.dart`
- Delete `topic_filter_menu.dart` file
- Remove "All Shelves" button (lines 203-214) since it will no longer be needed
- Keep search bar for text-based search functionality

### Phase 4: Update BLoC for Topic Shelves

**File**: `lib/features/youtube/presentation/bloc/youtube_bloc.dart`

Update `_buildBaseShelves` method (lines 215-252):

1. Build shelves with proper ordering:

   - "All Videos" (if videos exist)
   - "Music" category
   - "Movies" category  
   - "Shows" category
   - Other categories alphabetically
   - Topic shelves (prefixed "Topic - ") alphabetically
   - "Unavailable Videos" (if exist)
   - "Legacy Music Uploads" (if exist)

2. Create topic-based shelves:

   - Iterate through all unique topic tags
   - For each topic, filter videos that contain that tag
   - Create shelf with title "Topic - {topicName}"
   - Add to shelves list in proper sort order

3. Remove topic filtering logic:

   - Remove `_onTopicFilterChanged` handler (lines 541-564)
   - Remove `TopicFilterChanged` event from event handlers
   - Remove `selectedTopic` field from `YoutubeLoaded` state
   - Remove `availableTopics` field (no longer needed for dropdown)

### Phase 5: Update State Management

**Files**:

- `lib/features/youtube/presentation/bloc/youtube_state.dart`
- `lib/features/youtube/presentation/bloc/youtube_event.dart`

Actions:

- Remove `selectedTopic` and `availableTopics` from `YoutubeLoaded` state
- Remove `TopicFilterChanged` event class
- Update `copyWith`, `toJson`, `fromJson` methods to remove these fields
- Update `props` getter in `YoutubeLoaded`

### Phase 6: Update Home Screen UI

**File**: `lib/features/youtube/presentation/screens/home_screen.dart`

Actions:

- Simplify UI to show shelves or search results only
- Remove topic filter conditional logic (lines 193-196)
- Keep search functionality but remove filter-based "isSearching" check
- Update "Reset view" button to only clear search query
- Remove all references to `selectedTopic` and `availableTopics`

### Phase 7: Testing & Cleanup

- Test sign out functionality (should not throw assertion error)
- Test video display in all shelf types
- Test search functionality still works
- Test shelf expansion/collapse
- Verify proper shelf ordering
- Delete unused `topic_filter_menu.dart` file

## Expected Shelf Order

```
1. All Videos
2. Music
3. Movies
4. Shows
5. [Other categories alphabetically]
6. Topic - [Topic A]
7. Topic - [Topic B]
8. Topic - [Topic Z]
9. Unavailable Videos
10. Legacy Music Uploads
```

## Files Modified

- `lib/features/youtube/presentation/screens/home_screen.dart`
- `lib/features/youtube/presentation/widgets/expandable_video_shelf.dart`
- `lib/features/youtube/presentation/bloc/youtube_bloc.dart`
- `lib/features/youtube/presentation/bloc/youtube_state.dart`
- `lib/features/youtube/presentation/bloc/youtube_event.dart`

## Files Deleted

- `lib/features/youtube/presentation/widgets/topic_filter_menu.dart`

### To-dos

- [ ] Fix assertion error in home_screen.dart by removing context.watch outside builder
- [ ] Fix video display issues in expandable_video_shelf.dart
- [ ] Remove TopicFilterMenu widget from home_screen.dart and delete topic_filter_menu.dart
- [ ] Update _buildBaseShelves in youtube_bloc.dart to include topic shelves with proper ordering
- [ ] Remove selectedTopic and availableTopics from YoutubeLoaded state and remove TopicFilterChanged event
- [ ] Simplify home_screen.dart UI to remove topic filter logic and update reset button
- [ ] Test sign out, video display, search, and shelf ordering functionality