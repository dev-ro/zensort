<!-- cbc4968c-1412-4347-afb9-f16861ec66dd a1cc6aea-47bb-41b4-bbcb-5d1530b3a41c -->
# Efficient Embedding Query Implementation

## Overview

Transform the embedding detection system from expensive client-side filtering to efficient Firestore queries by explicitly setting `embedding: null` for videos without embeddings, enabling the use of `.where("embedding", "==", null)` queries.

## Implementation Steps

### 1. Update Video Creation Logic

**File: `functions/main.py`**

Modify `sync_youtube_liked_videos` function (lines 1068-1118) to explicitly set both `embedding: null` and `embedding_status: "pending"` when creating new video documents in the `/videos` collection.

**Changes:**

- Line ~1081: Add `"embedding": None` to `video_data` dict
- Line ~1082: Add `"embedding_status": "pending"` to `video_data` dict

This ensures all NEW videos have queryable embedding fields from creation.

### 2. Create One-Time Backfill Migration Function

**File: `functions/main.py`**

Create a new Cloud Function `backfill_embedding_null_field` (add after `diagnose_progress_calculation`):

**Purpose:** Add `embedding: null` and `embedding_status: "pending"` to ALL existing videos that are missing these fields.

**Implementation:**

- Use pagination with `order_by("__name__").limit(100)` for batch processing
- Check each document: if `"embedding" not in video_data`
- Set `{"embedding": None, "embedding_status": "pending"}` using batch writes
- Skip videos with `embedding_status: "not_applicable"` (private/deleted)
- Include continuation logic similar to `trigger_video_embeddings`
- Require secret parameter for security: `zensort-embedding-backfill-2024`
- Return stats: `processed`, `skipped`, `has_more`, `last_doc_id`

### 3. Update Progress Calculation Function

**File: `functions/main.py`**

Modify `update_embedding_progress` function (lines 1317-1359) to use efficient Firestore queries:

**Current:** Fetches ALL liked videos, then checks each one individually

**New:** Use targeted queries with `.where()` clauses

**Query replacements:**

- Completed: `videos_ref.where("__name__", "in", video_id_chunks).where("embedding_status", "in", ["complete", "not_applicable"]).get()`
- Failed: `videos_ref.where("__name__", "in", video_id_chunks).where("embedding_status", "==", "failed").get()`
- Pending: `videos_ref.where("__name__", "in", video_id_chunks).where("embedding", "==", None).get()`

**Note:** Use chunking (30 IDs per chunk) due to Firestore `in` query limitations.

**CRITICAL - Maintain UI Compatibility:**

The function MUST continue writing to `/users/{uid}/embeddingProgress/current` with the EXACT same schema:

```python
{
    "total": int,
    "completed": int,
    "failed": int,
    "pending": int,
    "last_updated": datetime
}
```

The Flutter UI (`EmbeddingStatusSheet`) depends on this schema. Only the query logic changes, not the output format.

### 4. Update Backfill Trigger Function

**File: `functions/main.py`**

Modify `trigger_video_embeddings` function (lines 1510-1762):

**Line 1555:** Replace pagination query with efficient filtering:

```python
videos_query = videos_collection.where("embedding", "==", None).order_by("__name__").limit(25)
```

This eliminates the need to fetch and filter all videos client-side.

### 5. Update Retry Failed Embeddings Logic

**File: `functions/main.py`**

Modify `_retry_failed_embeddings_for_user` function (lines 1870-1938):

**Lines 1905-1907:** Simplify the query by removing the complex chunk logic:

```python
failed_videos_query = videos_ref.where("embedding_status", "==", "failed")
```

Since we're querying by status (not by ID list), we don't need the `in` chunking anymore. Stream results and add to retry list.

### 6. Remove Diagnostic Function

**File: `functions/main.py`**

Delete the `diagnose_progress_calculation` function (lines 1954-2026) entirely since it's no longer needed with efficient queries in place.

### 7. Update Helper Function

**File: `functions/main.py`**

Modify `_has_valid_embedding` function (lines 1816-1843):

**Simplification:** Since all documents will now have the `embedding` field (either with vector or null), simplify the logic:

- Check if `embedding_status == "not_applicable"` → return True
- Check if `embedding_status == "complete"` → return True  
- Check if `embedding is None` → return False
- Check if `isinstance(embedding, list) and len(embedding) == EMBEDDING_DIMENSIONALITY` → return True
- Otherwise → return False

### 8. Update Flutter Progress Display

**File: `lib/features/youtube/domain/entities/embedding_progress.dart`**

No changes needed - the entity already handles all the status calculations correctly.

**File: `lib/features/youtube/presentation/widgets/embedding_status_sheet.dart`**

No changes needed - UI already displays the progress data correctly.

## Migration Execution Order

1. Deploy updated `sync_youtube_liked_videos` (step 1) - ensures new videos have proper fields
2. Deploy `backfill_embedding_null_field` (step 2)
3. Execute backfill: `GET https://us-central1-zensort-dev.cloudfunctions.net/backfill_embedding_null_field?secret=zensort-embedding-backfill-2024`
4. Wait for backfill completion (check logs)
5. Deploy remaining updates (steps 3-7) - switch to efficient queries
6. Verify with test queries

## Benefits

- **Performance:** Queries scan only matching documents instead of entire collection
- **Cost:** Dramatically reduced read operations (from ~2000 reads to ~10-50 per query)
- **Scalability:** Query performance stays constant as collection grows
- **Consistency:** All documents have predictable schema structure

### To-dos

- [ ] Add embedding: null and embedding_status: pending to video creation in sync_youtube_liked_videos
- [ ] Create backfill_embedding_null_field Cloud Function for one-time migration
- [ ] Replace client-side filtering with Firestore queries in update_embedding_progress
- [ ] Add where clause to trigger_video_embeddings query for efficient pagination
- [ ] Simplify retry_failed_embeddings query to use status-based filtering
- [ ] Delete diagnose_progress_calculation function
- [ ] Simplify _has_valid_embedding function logic