<!-- af7d7bae-770b-49b2-8d3f-1c65feb2eea8 9521c0f6-3993-401e-bc82-4d004b342c11 -->
# Embeddings Status Modal (Real-time, M3)

## Scope

- Add a Material 3 “Status” button in the `HomeScreen` app bar to open a modal bottom sheet showing embeddings progress.
- Auto-open the modal once on initial login if embeddings are incomplete.
- Stream Firestore progress at `users/{uid}/embeddingProgress/current` (fields: `total`, `completed`, `failed`, `pending`, `last_updated`) and update UI in real time.
- Keep architecture clean: domain entity + repository stream + small presentation cubit + widget.

## Files To Change / Add

- Domain
  - Add `lib/features/youtube/domain/entities/embedding_progress.dart` (immutable entity with computed helpers: `isComplete`, `percentComplete`).
  - Update `lib/features/youtube/domain/repositories/youtube_repository.dart`: add `Stream<EmbeddingProgress> watchEmbeddingProgress()`.
- Data
  - Update `lib/features/youtube/data/repositories/youtube_repository_impl.dart`: implement `watchEmbeddingProgress()` streaming Firestore doc.
- Presentation (BLoC/Cubit)
  - Add `lib/features/youtube/presentation/bloc/embedding_progress_cubit.dart` to subscribe to repository stream and expose latest `EmbeddingProgress`.
  - Update `lib/main.dart`: provide `EmbeddingProgressCubit` in `MultiBlocProvider` (constructed with `YoutubeRepository`).
- Presentation (UI)
  - Add `lib/features/youtube/presentation/widgets/embedding_status_sheet.dart`: a responsive modal bottom sheet; shows M3 `LinearProgressIndicator`, counts, percent, error/empty states, and a friendly explanation of embeddings and clustering.
  - Update `lib/features/youtube/presentation/screens/home_screen.dart`:
    - Add a Material 3 `FilledButton.tonalIcon` labeled “Status” in `AppBar.actions` to open the modal.
    - Listen once for `EmbeddingProgress` after login; if `!isComplete` and totals > 0 (or progress doc exists), auto-open the modal once per authenticated session.

## TDD Flow

1) Plan tests

- `test/features/youtube/domain/embedding_progress_test.dart`
  - Verifies JSON mapping and computed fields (`isComplete`, `percentComplete`).
- `test/features/youtube/presentation/embedding_progress_cubit_test.dart`
  - Given repository stream emits progress snapshots, cubit emits mapped states.
- `test/features/youtube/presentation/widgets/embedding_status_sheet_test.dart`
  - Renders progress bar and counts; updates when cubit emits new values; shows friendly explanation text; handles 0/empty state.
- `test/features/youtube/presentation/home_appbar_status_button_test.dart`
  - Tapping “Status” opens the modal; auto-open logic triggers once upon initial login when progress is incomplete.

2) Write failing tests (commit: test)

3) Minimal implementation for each layer to pass tests, iterating in small steps (commit after each logical step)

4) Refactor for clarity (commit: refactor) without breaking tests

## Implementation Steps + Commands

1) Branch

```bash
git checkout main && git pull origin main
git checkout -b feat/embeddings-status-modal
```

2) Add domain entity `EmbeddingProgress` (immutable, fromMap, helpers)

```bash
git add lib/features/youtube/domain/entities/embedding_progress.dart
git commit -m "feat(youtube): Add EmbeddingProgress domain entity"
gh issue create --title "feat(youtube): Add EmbeddingProgress domain entity" --body "Introduce immutable entity with computed helpers for UI"
```

3) Repository interface: add `watchEmbeddingProgress()`

```bash
git add lib/features/youtube/domain/repositories/youtube_repository.dart
git commit -m "feat(youtube): Expose watchEmbeddingProgress() in repository interface"
gh issue create --title "feat(youtube): Expose watchEmbeddingProgress()" --body "Stream Firestore progress doc users/{uid}/embeddingProgress/current"
```

4) Repository impl: Firestore stream mapping

```bash
git add lib/features/youtube/data/repositories/youtube_repository_impl.dart
git commit -m "feat(youtube): Implement watchEmbeddingProgress() on YoutubeRepositoryImpl"
gh issue create --title "feat(youtube): Implement embedding progress stream" --body "Map Firestore doc to EmbeddingProgress with sensible defaults"
```

5) Add `EmbeddingProgressCubit` and provide it

```bash
git add lib/features/youtube/presentation/bloc/embedding_progress_cubit.dart lib/main.dart
git commit -m "feat(youtube): Add EmbeddingProgressCubit and provide via MultiBlocProvider"
gh issue create --title "feat(youtube): Add EmbeddingProgressCubit" --body "Presentation state for real-time embeddings progress"
```

6) Create `EmbeddingStatusSheet` widget (modal bottom sheet)

```bash
git add lib/features/youtube/presentation/widgets/embedding_status_sheet.dart
git commit -m "feat(youtube): Add EmbeddingStatusSheet with real-time progress UI"
gh issue create --title "feat(youtube): Add EmbeddingStatusSheet" --body "Material 3 sheet with progress, counts, explanation"
```

7) App bar button + open modal

```bash
git add lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): Add Status button to AppBar and open EmbeddingStatusSheet"
gh issue create --title "feat(youtube): AppBar Status button" --body "Open modal sheet for embeddings status"
```

8) Auto-open on initial login if embeddings incomplete (guard to show once per session)

```bash
git add lib/features/youtube/presentation/screens/home_screen.dart
git commit -m "feat(youtube): Auto-open embeddings status on initial login when incomplete"
gh issue create --title "feat(youtube): Auto-open embeddings modal" --body "Improve onboarding clarity on first login"
```

9) Tests (add/fix) and refactors

```bash
git add test/**/*
git commit -m "test(youtube): Add unit and widget tests for embeddings status"

git add -A
git commit -m "refactor(youtube): Polish UI text, semantics, and minor cleanups"
```

10) Push and PR

```bash
git push -u origin feat/embeddings-status-modal
# Create PR in GitHub UI; link issues and use "Create a merge commit"
```

## UI/UX Notes (Material 3)

- Use `FilledButton.tonalIcon` in the app bar actions; rely on theme (no hardcoded colors).
- In the sheet, use `LinearProgressIndicator`, `AnimatedSwitcher` for text changes, and clear copy describing embeddings and clustering.
- Accessibility: `Semantics` labels on progress and counts; `Tooltip` on the Status button.

## Data & Realtime

- Firestore document: `users/{uid}/embeddingProgress/current` (source of truth; Cloud Functions keep it updated).
- If doc missing: show an informative idle state prompting the user to start or wait for sync.

## Security & Performance

- Read-only access to progress fields; no client writes.
- Avoid re-subscribing repeatedly; keep a single cubit subscription for the session.

### To-dos

- [ ] Add EmbeddingProgress entity to domain layer
- [ ] Expose watchEmbeddingProgress() in YoutubeRepository interface
- [ ] Implement watchEmbeddingProgress() in YoutubeRepositoryImpl
- [ ] Create EmbeddingProgressCubit and wire it in main.dart
- [ ] Build EmbeddingStatusSheet widget (M3, realtime progress)
- [ ] Add Status button to HomeScreen AppBar and open sheet
- [ ] Auto-open sheet on initial login if progress incomplete
- [ ] Add and update unit/widget tests for entity, cubit, UI
- [ ] Write update doc describing the feature and UX