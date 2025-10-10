<!-- af7d7bae-770b-49b2-8d3f-1c65feb2eea8 f85c87d7-61a7-4a5e-a75b-f9b3a055f79e -->
# YouTube Shelves – Eager Load + Search/Filter UX

## Goals

- Eagerly load ALL liked videos into memory from Firestore on initial login and after syncs.
- Show a friendly Material 3 loading modal whenever a full load is in progress.
- Make search easy to exit: clearing the search returns to the main shelves; add an explicit “All Shelves” button.
- Add a clear option to topic filters to show all videos again.

## Approach

- Extend `YouTubeBloc` to support an eager, batched full-load that streams pages and tracks progress.
- Add a `YoutubeAllLoading` state to surface progress (current/total). Use `fetchRemoteLikedVideosTotal()` when available.
- UI listens for `YoutubeAllLoading` to open a blocking modal; closes it when `YoutubeLoaded.isFullyLoaded == true`.
- Update search bar to provide a clear action (suffix icon) that resets query and returns to shelves; also add an “All Shelves” M3 button to clear search and filters.
- Add a “Clear filter” option in `TopicFilterMenu` (selecting “All topics”).

## Files To Change / Add

- `lib/features/youtube/presentation/bloc/youtube_state.dart`
  - Add `YoutubeAllLoading { loadedCount, totalCount }` state (non-hydrated).
- `lib/features/youtube/presentation/bloc/youtube_event.dart`
  - Add `LoadAllVideosEager()`; trigger after auth initialization and after a successful sync.
- `lib/features/youtube/presentation/bloc/youtube_bloc.dart`
  - Handle `LoadAllVideosEager` by consuming `fetchAllLikedVideosBatched()` and emitting `YoutubeAllLoading` progress updates, then `YoutubeLoaded.copyWith(isFullyLoaded: true)` when finished.
  - On `YoutubeSyncSuccess`, re-dispatch `LoadAllVideosEager`.
- `lib/features/youtube/presentation/widgets/loading_all_videos_sheet.dart` (new)
  - Modal explaining the full load, with `LinearProgressIndicator` using `loadedCount/totalCount` when known; falls back to indeterminate.
- `lib/features/youtube/presentation/widgets/video_search_bar.dart`
  - Add clear (suffix) icon that dispatches `SearchQueryChanged('')` and shifts UI back to shelves.
  - Optionally expose a callback to request clearing filters too.
- `lib/features/youtube/presentation/screens/home_screen.dart`
  - Open the new loading modal when state is `YoutubeAllLoading`, close on `YoutubeLoaded.isFullyLoaded`.
  - Add an M3 `FilledButton.tonal` labeled “All Shelves” that clears search and topic filter.
  - When search text becomes empty, return to shelves automatically.
- `lib/features/youtube/presentation/widgets/topic_filter_menu.dart`
  - Add a first option “All topics”/“Clear filter” that passes `null` to `onSelected`.

## TDD Plan

- Bloc tests: `test/features/youtube/presentation/youtube_bloc_all_load_test.dart`
  - Start on `LoadAllVideosEager` → emits `YoutubeAllLoading` with increasing counts, then `YoutubeLoaded` with `isFullyLoaded = true`.
  - On `YoutubeSyncSuccess` → triggers a fresh eager load.
- Widget tests:
  - `test/features/youtube/presentation/widgets/loading_all_videos_sheet_test.dart`: Modal renders, shows progress, closes on completion.
  - `test/features/youtube/presentation/widgets/video_search_bar_test.dart`: Clear icon resets query; UI returns to shelves.
  - `test/features/youtube/presentation/widgets/topic_filter_menu_test.dart`: “All topics” clears filter.

## Implementation Steps + Commands

1) Create stacked branch from `feat/youtube-shelves`

```bash
git checkout -b feat/youtube-shelves-loading-fixes feat/youtube-shelves
```

2) Bloc state/event additions (compile-only)

```bash
git add lib/features/youtube/presentation/bloc/youtube_state.dart lib/features/youtube/presentation/bloc/youtube_event.dart
git commit -m "feat(youtube): Add YoutubeAllLoading state and LoadAllVideosEager event"
```

3) Bloc eager-load logic and sync hook

```bash
git add lib/features/youtube/presentation/bloc/youtube_bloc.dart
git commit -m "feat(youtube): Eager-load all videos with progress and post-sync reload"
```

4) Loading modal sheet

```bash
git add lib/features/youtube/presentation/widgets/loading_all_videos_sheet.dart
git commit -m "feat(youtube): Add LoadingAllVideosSheet (M3) with progress"
```

5) Wire modal open/close in `HomeScreen`

```bash
git add lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): Show loading modal during full load; close on completion"
```

6) Search clear + “All Shelves” button

```bash
git add lib/features/youtube/presentation/widgets/video_search_bar.dart lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): Clear search restores shelves; add All Shelves button"
```

7) Topic filter clear option

```bash
git add lib/features/youtube/presentation/widgets/topic_filter_menu.dart
git commit -m "feat(youtube): Add Clear filter (All topics) option"
```

8) Tests

```bash
git add test/**/*
git commit -m "test(youtube): Add bloc and widget tests for eager load and UX fixes"
```

9) Push and open stacked PR

```bash
git push -u origin feat/youtube-shelves-loading-fixes
gh pr create --base feat/youtube-shelves --head feat/youtube-shelves-loading-fixes --title "feat(youtube): Eager load + search/filter UX fixes" --body "Stacked on youtube-shelves"
```

## UX Notes

- Use Material 3 components; no hardcoded colors; rely on theme.
- Modal copy: “Loading your library. For larger libraries this can take a while. You can keep browsing; we’ll fill shelves and search as data arrives.”
- Disable closing (or allow cancel?)—prefer non-dismissible with a small note; if allowed to dismiss, re-open automatically if still loading when navigating back.

## Edge Cases

- Unknown total count: fall back to indeterminate progress until total is available.
- Very large libraries: keep updates efficient (throttle UI progress to reduce jank).
- Offline/Errors: surface a retry action; keep previous shelves visible.

### To-dos

- [ ] Add YoutubeAllLoading state and LoadAllVideosEager event
- [ ] Implement eager-load with progress and post-sync reload in bloc
- [ ] Create LoadingAllVideosSheet (M3) and wire to bloc state
- [ ] Clear search resets shelves; add All Shelves button
- [ ] Add Clear filter option in topic filter menu
- [ ] Add bloc and widget tests for eager load and UX fixes
- [ ] Push branch and open stacked PR to youtube-shelves