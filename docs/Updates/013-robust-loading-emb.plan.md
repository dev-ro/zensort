<!-- af7d7bae-770b-49b2-8d3f-1c65feb2eea8 a0724156-4410-4fea-8ff9-2e98a41cc859 -->
# YouTube Shelves – Robust Loading UX, Reset Controls, and Performance

## Objectives

- Replace repeated bottom sheets with a single non-dismissible, auto-dismiss full-screen loader during eager load.
- Improve large-shelf experience with lightweight per-shelf loading indicators and rendering optimizations.
- Make exiting search/filter intuitive and instant: clear returns to full shelves; add an app bar reset icon.
- Fix “All topics” selection to reliably clear the filter and restore shelves.

## Strategy

- Loader UX:
  - Remove showModalBottomSheet loop. Introduce a page-level `FullScreenLoadingOverlay` rendered once via the `HomeScreen` body (Stack). It appears whenever state is `YoutubeAllLoading` and auto-hides when `YoutubeLoaded.isFullyLoaded` is true. Copy updated to instruct waiting (no “keep browsing”).
- Shelf performance:
  - Use `GridView.builder` with tuned `cacheExtent`, and `PageStorageKey` per shelf to preserve scroll state.
  - Add a light per-shelf loading bar (M3 `LinearProgressIndicator`) shown while a shelf first renders many items (flag-driven in state like `activeShelfLoadingKey`). Clear it post-first frame.
  - Minor image/rendering optimizations (avoid heavy effects; ensure thumbnails skip broken ones as already implemented).
- Search/Filter UX:
  - Search clear already resets shelves; keep suffix clear.
  - Add an AppBar reset icon (Material 3) to clear search, selected topic, and collapse shelves in one tap.
  - Topic filter: make “All topics” selectable across desktop/mobile; use a consistent first item that calls `onSelected(null)` and visually marks selection.

## Files To Change / Add

- `lib/features/youtube/presentation/screens/home_screen.dart`
  - Wrap body in a `Stack`; render `FullScreenLoadingOverlay` on `YoutubeAllLoading` (non-dismissible, auto-dismiss by state change).
  - Add AppBar reset icon to clear `SearchQueryChanged('')`, `TopicFilterChanged(null)`, `ShelfExpansionChanged(null)`.
- `lib/features/youtube/presentation/widgets/full_screen_loading_overlay.dart` (new)
  - Full-screen M3 surface with title, message (no browsing promise), and a single progress bar (indeterminate or `loaded/total`).
- `lib/features/youtube/presentation/widgets/topic_filter_menu.dart`
  - Ensure “All topics” (first item) is selectable and updates the button label to `Topics: All`.
  - Desktop: adjust `RadioListTile` group/value to use a stable sentinel (e.g., `_allTopicsValue = '__all__'`) instead of empty string; map sentinel to `null` on select.
  - Mobile: keep first `ListTile` but make selection state obvious (e.g., check icon when active).
- `lib/features/youtube/presentation/widgets/responsive_video_grid.dart`
  - Ensure `GridView.builder` usage with tuned `cacheExtent`; add optional `Key` to preserve state; expose `isBusy` to show a small top `LinearProgressIndicator` during initial heavy render.
- `lib/features/youtube/presentation/bloc/youtube_state.dart`
  - Add optional `activeShelfKey` and `activeShelfBusy` flags in `YoutubeLoaded` to drive per-shelf loading indicator.
- `lib/features/youtube/presentation/bloc/youtube_bloc.dart`
  - On `ShelfExpansionChanged`, momentarily set `activeShelfBusy=true` for the chosen shelf; clear after a microtask (`Future.microtask`) when the frame commits.
  - Remove repeated bottom-sheet invocation (no UI calls in listener); rely solely on overlay.

## TDD

- Bloc tests:
  - `test/features/youtube/presentation/youtube_bloc_shelf_busy_test.dart`: expanding a shelf toggles `activeShelfBusy` true then false.
- Widget tests:
  - `test/features/youtube/presentation/widgets/full_screen_loading_overlay_test.dart`: overlay visible only for `YoutubeAllLoading`, auto-hides when loaded.
  - `test/features/youtube/presentation/widgets/topic_filter_menu_test.dart`: selecting “All topics” clears filter and updates label.
  - `test/features/youtube/presentation/home_reset_icon_test.dart`: tapping reset clears search/topic/expanded shelf.

## Implementation Steps + Commands

1) Branch (stacked off current fixes)

```bash
git checkout -b feat/youtube-shelves-ux2 feat/youtube-shelves-loading-fixes
```

2) Add overlay and wire in `HomeScreen`

```bash
git add lib/features/youtube/presentation/widgets/full_screen_loading_overlay.dart lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): FullScreenLoadingOverlay; single non-dismissible loader with auto-dismiss"
```

3) AppBar reset icon

```bash
git add lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): Add AppBar reset icon to restore main shelves"
```

4) Topic filter reliability

```bash
git add lib/features/youtube/presentation/widgets/topic_filter_menu.dart
git commit -m "feat(youtube): Make All topics selectable; unify desktop/mobile behavior"
```

5) Shelf performance and busy indicator

```bash
git add lib/features/youtube/presentation/widgets/responsive_video_grid.dart lib/features/youtube/presentation/bloc/youtube_state.dart lib/features/youtube/presentation/bloc/youtube_bloc.dart
git commit -m "perf(youtube): Optimize grid rendering and show per-shelf loading"
```

6) Tests

```bash
git add test/**/*
git commit -m "test(youtube): Add tests for loader overlay, filter clear, and shelf busy state"
```

7) Push and open stacked PR

```bash
git push -u origin feat/youtube-shelves-ux2
gh pr create --base feat/youtube-shelves-loading-fixes --head feat/youtube-shelves-ux2 --title "feat(youtube): Single loader, reset icon, faster shelves" --body "Stacked on shelves-loading-fixes"
```

## Copy/UX Details

- Loader title: “Loading your videos”
- Message: “This can take a while for larger libraries. Please wait while we prepare your shelves and search.”
- No dismiss; closes itself when load completes.
- Topic button label always reflects selection; ‘All topics’ shows when cleared.

## Risk Mitigation

- No Navigator-based modals for progress; avoids multi-modal race.
- Keep overlay rendering cheap (no rebuild storms): Memoize values, use `AnimatedSwitcher` for the text.
- Grid performance tuned; if still slow, next iteration: consider `cached_network_image` and incremental image decode.

### To-dos

- [ ] Add YoutubeAllLoading state and LoadAllVideosEager event
- [ ] Implement eager-load with progress and post-sync reload in bloc
- [ ] Create LoadingAllVideosSheet (M3) and wire to bloc state
- [ ] Clear search resets shelves; add All Shelves button
- [ ] Add Clear filter option in topic filter menu
- [ ] Add bloc and widget tests for eager load and UX fixes
- [ ] Push branch and open stacked PR to youtube-shelves