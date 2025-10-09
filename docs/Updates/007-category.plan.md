<!-- 2b3a2b2a-460f-44b5-b286-e365ff320d6d 31a153ce-7f29-4d04-8f7a-2bcbdcfb0ce9 -->
# Category Shelves + All Videos Pagination

## Goals

- Localize and denormalize YouTube `categoryTitle` per user locale for automatic shelves.
- Remove `isMusic` entirely from backend and UI (no fallback).
- Optimize All Videos by loading in pages (initial 100) with smooth UX.
- Update backfill to populate new fields safely without disturbing embeddings/metadata.

## Data & Backend Changes

- Videos collection (`/videos/{videoId}`): keep authoritative fields (`categoryId`, `topicCategories`, existing `isMusic` for compatibility). Do NOT store localized titles here.
- User liked links (`/users/{uid}/likedVideos/{videoId}`): denormalize per-user display fields:
  - `likedAt`, `syncedAt`
  - `title`, `channelTitle`, `thumbnailUrl`
  - `categoryId`, `categoryTitle` (localized by user account locale)

### Cloud Functions (functions/main.py)

1) Category title resolver with caching

   - Add a helper that, given `(categoryId, locale)`, returns the proper `snippet.title` using `videoCategories.list` with `regionCode` and `hl` derived from locale (e.g., `en-US` → region `US`, hl `en`).
   - Maintain an in-memory LRU and a Firestore cache doc (e.g., `/ytCategoryMaps/{region}_{hl}`) mapping id→title to avoid repeated API calls.

2) Sync path writes denormalized fields

   - In `sync_youtube_liked_videos`, when writing `/users/{uid}/likedVideos/{videoId}`, include `title`, `channelTitle`, `thumbnailUrl`, `categoryId`, and resolved `categoryTitle` using the requesting user's locale.
   - Continue writing `/videos/{videoId}` as today (merge-only for enrichment), preserving embeddings and metadata.

3) Backfill

   - Create a backfill routine to iterate users’ `/likedVideos` docs and fill missing `categoryId`/`categoryTitle` by reading `/videos/{id}.categoryId` and resolving localized title via the resolver. Use merge updates only.
   - Batch with cursors; avoid touching `embedding_*` fields; skip private/deleted placeholders.

## Flutter App Changes

### Domain/Entities

- Update `lib/features/youtube/domain/entities/liked_video.dart` to include `categoryId` and `categoryTitle` (keep `isMusic` for legacy fallback in fromJson/toJson).

### Repository

- Update `lib/features/youtube/data/repositories/youtube_repository_impl.dart`:
  - Add paginated fetch based solely on `/users/{uid}/likedVideos` (no cross-collection joins):
    - Initial stream: orderBy `likedAt` desc, `limit(100)`.
    - Expose a method to fetch next page using `startAfterDocument`.
  - Map fields directly from liked link docs to `LikedVideo` (id = doc.id, title, channelName, thumbnailUrl, categoryId, categoryTitle).
  - Keep existing total verification logic. Keep legacy `watchLikedVideos` for compatibility during rollout if needed.

Example (essential shape):

```dart
// initial page stream
_firestore.collection('users').doc(uid)
  .collection('likedVideos')
  .orderBy('likedAt', descending: true)
  .limit(100)
  .snapshots();
```

### BLoC and UI

- `lib/features/youtube/presentation/bloc/youtube_bloc.dart`:
  - Build shelves by grouping videos on `categoryTitle`; only add a shelf if it has items.
  - Replace "Music" logic by category grouping (still treat legacy `isMusic` as fallback where `categoryTitle` is absent).
  - Add a `LoadMoreAllVideos` event that fetches the next page and appends to state.
- All Videos shelf UX:
  - Start with 100 items; show a bottom "Load more" button or auto-load on scroll threshold.
  - Keep existing "Unavailable Videos" and "Legacy Music Uploads" shelves.

### Firestore Security Rules

- Allow optional `categoryId` (string), `topicCategories` (array<string>) on `/videos`.
- Allow denormalized read/write of `title`, `channelTitle`, `thumbnailUrl`, `categoryId`, `categoryTitle` on `/users/{uid}/likedVideos/{videoId}` by the owner, maintaining existing restrictions on embedding fields in `/videos`.

## Locale Handling

- Use the user's account locale (e.g., `en-US`) to derive `hl=en`, `regionCode=US` for category titles.
- Store/update user locale under `users/{uid}/settings.locale`; fallback to `en-US` if absent.

## Non-Breaking Migration

- Keep `isMusic` writes in Functions and reading in client as fallback until category-based shelves are fully verified.

## Testing (TDD)

- Add unit tests for:
  - Category resolver caching behavior and locale correctness.
  - Repository pagination: initial 100, subsequent pages, and ordering.
  - BLoC shelf grouping correctness and absence of empty shelves.
  - Backfill writes merge-only and skip placeholders.

## Backfill Execution Strategy

- Run per-user in batches with an admin-triggered HTTPS function; progress logged.
- Idempotent; can resume via cursor.

## Minimal Schema Snapshot

- `/videos/{videoId}`: `videoId`, `title`, `description`, `channelTitle`, `thumbnailUrl`, `publishedAt`, `platform`, `addedToZensortAt`, `isMusic`, `categoryId`, `topicCategories`, (embeddings… read-only for clients).
- `/users/{uid}/likedVideos/{videoId}`: `likedAt`, `syncedAt`, `title`, `channelTitle`, `thumbnailUrl`, `categoryId`, `categoryTitle`.

### To-dos

- [ ] Add locale-based category title resolver with LRU + Firestore cache
- [ ] Write denormalized fields (incl. categoryTitle) to likedVideos docs
- [ ] Backfill likedVideos docs with categoryId and localized categoryTitle
- [ ] Extend LikedVideo with categoryId and categoryTitle fields
- [ ] Implement paginated likedVideos fetch (limit 100) and load-more API
- [ ] Group shelves by categoryTitle; remove isMusic shelf usage
- [ ] Add All Videos pagination with load more or infinite scroll
- [ ] Update Firestore rules for new fields and denormalized likedVideos
- [ ] Write unit tests for resolver, pagination, shelves, and backfill