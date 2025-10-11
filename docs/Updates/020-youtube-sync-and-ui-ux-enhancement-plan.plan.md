<!-- 80ce4fc8-7bfd-44b4-8a48-d5f043609a83 26b6f9e1-d05b-44b7-99c6-b0909ed5c9cc -->
# Plan: YouTube Sync Performance and UI/UX Overhaul

This plan addresses the slow synchronization performance and confusing UI feedback during the YouTube liked videos sync process.

## 1. Backend Refactoring: Decouple Embeddings from Sync

The primary cause of the slowdown is the embedding progress calculation, which runs during the main sync. I will decouple these processes to dramatically speed up the initial sync.

**File:** `functions/main.py`

1.  **Remove Progress Calculation from Main Sync:** I will remove the call to `update_embedding_progress` from the `sync_youtube_liked_videos` function. This will eliminate thousands of Firestore reads from the critical path of the user's initial sync.
2.  **Remove Automatic Embedding Retries:** I will also remove the call to `_retry_failed_embeddings_for_user` from the start of the sync to further accelerate the process.
3.  **Create On-Demand Embedding Functions:**
    *   I will create a new callable function, `calculate_embedding_progress`, which will contain the logic from `update_embedding_progress`. The app will call this directly when the user wants to check their progress.
    *   I will create another new callable function, `trigger_retry_failed_embeddings`, which will allow the user to manually retry any failed embeddings from the app's UI.

## 2. Frontend State Management: Granular Sync Feedback

I will enhance the `YouTubeBloc` to provide the detailed, real-time feedback necessary for the improved UI.

**File:** `lib/features/youtube/presentation/blocs/youtube_bloc.dart`

1.  **Introduce Granular States:** I will update the `YouTubeState` to include specific messages about the sync progress. For example, `YoutubeSyncInProgress(message: 'Fetching your liked videos...')` and `YoutubeSyncInProgress(message: 'Syncing video 500 of 1874...')`.
2.  **Add Embedding Calculation Logic:** I will add new events and states to handle the on-demand embedding calculation:
    *   **Event:** `CalculateEmbeddingProgress`
    *   **States:** `EmbeddingCalculationInProgress`, `EmbeddingCalculationSuccess`, `EmbeddingCalculationFailure`.

## 3. UI/UX Overhaul: Dynamic and Responsive Feedback

I will update the Flutter UI to reflect the new backend architecture and provide a transparent, user-friendly experience.

**Target UI Files:** (I will first locate the relevant files by searching for the sync button and related UI elements).

1.  **Dynamic Messaging:** I will replace the static "Welcome! Please sync your videos!" message with a dynamic one that displays the real-time status from the `YouTubeBloc`.
2.  **Disable Sync Button:** The sync button in the `AppBar` will be disabled and visually faded when a sync is in progress to prevent duplicate actions.
3.  **Update Embedding Modal:** The "embedding progress" button will trigger the new `CalculateEmbeddingProgress` event. The modal it opens will now show a loading indicator during calculation and then display the results, along with a button to trigger the retry mechanism.


### To-dos

- [ ] Decouple embedding progress calculation and automatic retries from the main `sync_youtube_liked_videos` function in `functions/main.py`.
- [ ] Create two new on-demand Cloud Functions in `functions/main.py`: `calculate_embedding_progress` and `trigger_retry_failed_embeddings`.
- [ ] Enhance `YouTubeBloc` with more granular states for sync progress and add new states/events for on-demand embedding calculation.
- [ ] Locate the relevant YouTube feature UI files in the Flutter app.
- [ ] Update the UI to display dynamic sync messages from the `YouTubeBloc`.
- [ ] Implement logic to disable the sync button during the sync process.
- [ ] Update the embedding progress modal to handle the new on-demand calculation flow, including loading states and a retry button.