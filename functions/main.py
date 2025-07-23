# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy --only functions`

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Generator
from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn
from firebase_functions.options import set_global_options
import requests
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.errors import HttpError
import logging
import json

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# For cost control, you can set the maximum number of containers that can be
# running at the same time. This helps mitigate the impact of unexpected
# traffic spikes by instead downgrading performance. This limit is a per-function
# limit. You can override the limit for each function using the max_instances
# parameter in the decorator, e.g. @https_fn.on_request(max_instances=5).
set_global_options(max_instances=10)

initialize_app()


@https_fn.on_call()
def add_to_waitlist(req: https_fn.CallableRequest) -> dict:
    """
    A callable function to add an email to the waitlist.
    """
    # 1. Validate the incoming email from the request data
    email = req.data.get("email")
    if not isinstance(email, str) or "@" not in email:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid email.",
        )

    try:
        # 2. Check if the email already exists in the 'waitlist' collection
        db = firestore.client()
        waitlist_collection = db.collection("waitlist")
        existing_entries = (
            waitlist_collection.where("email", "==", email).limit(1).get()
        )

        if len(list(existing_entries)) > 0:
            return {"message": f"{email} is already on our waitlist."}

        # 3. Add the new document to the 'waitlist' collection in Firestore
        # The Admin SDK bypasses security rules to write to the database
        waitlist_collection.add(
            {"email": email, "createdAt": datetime.now(timezone.utc)}
        )

        # 4. Send a success response back to the client
        return {"message": f"Successfully added {email} to the waitlist!"}

    except Exception as e:
        print(f"Error adding document to waitlist: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An error occurred while adding to the waitlist.",
        )


@dataclass
class Video:
    videoId: str
    title: str
    description: str
    thumbnailUrl: str
    channelTitle: str
    publishedAt: datetime
    platform: str = "YouTube"
    addedToZensortAt: datetime = None


@dataclass
class LikedVideoRelation:
    videoId: str
    likedAt: datetime
    syncedAt: datetime


@https_fn.on_call()
def get_liked_videos_total(req: https_fn.CallableRequest) -> dict:
    """
    Fetch total number of liked videos for a user from the YouTube Data API using the correct endpoint.
    Uses the playlistItems.list endpoint with the special "Liked Videos" playlist to get accurate count
    including private, deleted, and legacy videos.
    Returns an integer.
    """
    access_token = req.data.get("access_token")
    if not access_token:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with an access_token.",
        )

    try:
        # Create OAuth2 credentials from the access token
        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        # Build the YouTube service
        youtube = build("youtube", "v3", credentials=credentials)

        # Use playlistItems.list with the special "Liked Videos" playlist ID 'LL'
        # to get accurate total count including private/deleted videos
        request = youtube.playlistItems().list(playlistId="LL", part="id", maxResults=1)
        response = request.execute()

        return {"total": response["pageInfo"]["totalResults"]}

    except HttpError as e:
        if e.resp.status == 401:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Invalid or expired YouTube access token.",
            )
        else:
            print(f"YouTube API error: {e}")
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f"YouTube API error: {str(e)}",
            )
    except Exception as e:
        print(f"Unexpected error in get_liked_videos_total: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred while fetching video count.",
        )


def fetch_liked_video_items(access_token: str) -> list[dict]:
    """
    Fetch all items from the user's special "Liked Videos" playlist using the correct API endpoint.
    This function uses the playlistItems.list endpoint with playlistId 'LL' to get ALL liked videos
    (including private, deleted, and legacy videos) with their correct likedAt timestamps.

    Returns a list of dictionaries with 'videoId' and 'likedAt' keys.
    """
    try:
        logger.info("=== Starting fetch_liked_video_items ===")

        # Create OAuth2 credentials from the access token
        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        # Build the YouTube service
        youtube = build("youtube", "v3", credentials=credentials)

        video_items = []
        next_page_token = None
        page_count = 0

        while True:
            page_count += 1
            logger.info(f"Fetching page {page_count} of liked video items")

            # Use playlistItems.list with the special "Liked Videos" playlist ID 'LL'
            request = youtube.playlistItems().list(
                playlistId="LL",  # Special playlist ID for "Liked Videos"
                part="snippet",
                maxResults=50,
                pageToken=next_page_token,
            )

            response = request.execute()

            # Extract video items with videoId and likedAt timestamp
            for item in response.get("items", []):
                snippet = item.get("snippet", {})
                video_id = snippet.get("resourceId", {}).get("videoId")

                # The likedAt timestamp is the snippet.publishedAt from the playlist item
                liked_at_str = snippet.get("publishedAt", "")
                try:
                    liked_at = datetime.fromisoformat(
                        liked_at_str.replace("Z", "+00:00")
                    )
                except ValueError:
                    logger.warning(
                        f"Invalid likedAt timestamp for video {video_id}: {liked_at_str}"
                    )
                    liked_at = datetime.now(timezone.utc)

                if video_id:
                    video_items.append({"videoId": video_id, "likedAt": liked_at})

            logger.info(
                f"Page {page_count}: Retrieved {len(response.get('items', []))} video items"
            )

            # Check for next page
            next_page_token = response.get("nextPageToken")
            if not next_page_token:
                logger.info(
                    f"Completed fetching all video items. Total: {len(video_items)}"
                )
                break

        return video_items

    except HttpError as e:
        logger.error(
            f"YouTube API HttpError: {e.resp.status if hasattr(e, 'resp') else 'unknown'}"
        )

        if e.resp.status == 401:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Invalid or expired YouTube access token.",
            )
        elif e.resp.status == 403:
            error_content = json.loads(e.content) if e.content else {}
            error_info = error_content.get("error", {})
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message=f"YouTube API access denied: {error_info.get('message', 'Permission denied')}",
            )
        else:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f"YouTube API error: HTTP {e.resp.status}",
            )
    except Exception as e:
        logger.error(
            f"Unexpected error in fetch_liked_video_items: {type(e).__name__}: {str(e)}"
        )
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Failed to fetch video items: {type(e).__name__}: {str(e)}",
        )


def fetch_liked_video_ids(access_token: str) -> list[str]:
    """
    DEPRECATED: This function uses the wrong endpoint and excludes private/deleted videos.
    Use fetch_liked_video_items() instead for complete data integrity.

    Fetch all liked video IDs for a user from the YouTube Data API, handling pagination.
    Returns a list of video IDs only (no metadata).
    """
    try:
        logger.info("=== Starting fetch_liked_video_ids ===")

        # Create OAuth2 credentials from the access token
        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        # Build the YouTube service
        youtube = build("youtube", "v3", credentials=credentials)

        video_ids = []
        next_page_token = None
        page_count = 0

        while True:
            page_count += 1
            logger.info(f"Fetching page {page_count} of liked video IDs")

            # Request only IDs to minimize API usage
            request = youtube.videos().list(
                myRating="like",
                part="id",
                maxResults=50,
                pageToken=next_page_token,
            )

            response = request.execute()

            # Extract video IDs
            page_video_ids = [item["id"] for item in response.get("items", [])]
            video_ids.extend(page_video_ids)

            logger.info(f"Page {page_count}: Retrieved {len(page_video_ids)} video IDs")

            # Check for next page
            next_page_token = response.get("nextPageToken")
            if not next_page_token:
                logger.info(
                    f"Completed fetching all video IDs. Total: {len(video_ids)}"
                )
                break

        return video_ids

    except HttpError as e:
        logger.error(
            f"YouTube API HttpError: {e.resp.status if hasattr(e, 'resp') else 'unknown'}"
        )

        if e.resp.status == 401:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Invalid or expired YouTube access token.",
            )
        elif e.resp.status == 403:
            error_content = json.loads(e.content) if e.content else {}
            error_info = error_content.get("error", {})
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message=f"YouTube API access denied: {error_info.get('message', 'Permission denied')}",
            )
        else:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f"YouTube API error: HTTP {e.resp.status}",
            )
    except Exception as e:
        logger.error(
            f"Unexpected error in fetch_liked_video_ids: {type(e).__name__}: {str(e)}"
        )
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Failed to fetch video IDs: {type(e).__name__}: {str(e)}",
        )


def fetch_video_details(access_token: str, video_ids: list[str]) -> list[Video]:
    """
    Fetch detailed metadata for specified video IDs from YouTube API.
    Implements proper batching to handle more than 50 videos by making multiple
    paginated calls to the videos.list endpoint.
    Returns a list of Video objects with full metadata.
    """
    if not video_ids:
        return []

    try:
        logger.info(f"=== Starting fetch_video_details for {len(video_ids)} videos ===")

        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        youtube = build("youtube", "v3", credentials=credentials)

        all_videos = []  # Master list to aggregate all results
        batch_size = 50  # YouTube API limit for videos.list endpoint

        # Process video_ids in chunks of 50
        total_batches = (len(video_ids) + batch_size - 1) // batch_size
        logger.info(
            f"Processing {len(video_ids)} video IDs in {total_batches} batches of {batch_size}"
        )

        for batch_index in range(0, len(video_ids), batch_size):
            # Get the current batch of video IDs
            batch_ids = video_ids[batch_index : batch_index + batch_size]
            current_batch_number = (batch_index // batch_size) + 1

            logger.info(
                f"Processing batch {current_batch_number}/{total_batches}: {len(batch_ids)} video IDs"
            )
            logger.info(
                f"Batch {current_batch_number} IDs: {batch_ids[:5]}{'...' if len(batch_ids) > 5 else ''}"
            )

            # Make API request for this batch
            try:
                request = youtube.videos().list(
                    part="id,snippet", id=",".join(batch_ids)
                )
                response = request.execute()

                batch_videos = []  # Videos from this batch

                # Process each item in the response
                for item in response.get("items", []):
                    snippet = item.get("snippet", {})

                    # Parse publishedAt timestamp safely
                    published_at_str = snippet.get("publishedAt", "")
                    try:
                        published_at = datetime.fromisoformat(
                            published_at_str.replace("Z", "+00:00")
                        )
                    except ValueError:
                        logger.warning(
                            f"Invalid publishedAt format for video {item['id']}: {published_at_str}"
                        )
                        published_at = datetime.now(timezone.utc)

                    video = Video(
                        videoId=item["id"],
                        title=snippet.get("title", ""),
                        description=snippet.get("description", ""),
                        thumbnailUrl=snippet.get("thumbnails", {})
                        .get("default", {})
                        .get("url", ""),
                        channelTitle=snippet.get("channelTitle", ""),
                        publishedAt=published_at,
                        platform="YouTube",
                        addedToZensortAt=datetime.now(timezone.utc),
                    )
                    batch_videos.append(video)

                # Add this batch's results to the master list
                all_videos.extend(batch_videos)
                logger.info(
                    f"Batch {current_batch_number}: Successfully fetched {len(batch_videos)} video details"
                )
                logger.info(f"Total videos fetched so far: {len(all_videos)}")

            except HttpError as e:
                logger.error(
                    f"YouTube API error for batch {current_batch_number}: HTTP {e.resp.status}"
                )
                # Continue with next batch instead of failing completely
                if e.resp.status == 401:
                    raise https_fn.HttpsError(
                        code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                        message="Invalid or expired YouTube access token.",
                    )
                else:
                    logger.warning(
                        f"Skipping batch {current_batch_number} due to API error: {e}"
                    )
                    continue

            except Exception as e:
                logger.error(
                    f"Unexpected error processing batch {current_batch_number}: {type(e).__name__}: {str(e)}"
                )
                # Continue with next batch
                continue

        logger.info(
            f"=== Completed fetch_video_details: {len(all_videos)} videos fetched out of {len(video_ids)} requested ==="
        )

        if len(all_videos) != len(video_ids):
            logger.warning(
                f"Video count mismatch: requested {len(video_ids)}, got {len(all_videos)}"
            )

        return all_videos

    except Exception as e:
        logger.error(
            f"Critical error in fetch_video_details: {type(e).__name__}: {str(e)}"
        )
        raise


def get_video_category(title: str, channel_title: str) -> str | None:
    """
    Determine the category of a video based on its title and channel.
    Returns None for regular public videos.
    """
    if title == "Private video":
        return "Private"
    elif title == "Deleted video":
        return "Deleted"
    elif channel_title == "Music Library Uploads":
        return "Legacy Music"
    else:
        return None


def is_private_legacy_video(title: str) -> bool:
    """
    Determine if a video is private/legacy based on its title.
    """
    private_legacy_titles = {"Private video", "Deleted video", "Music Library Uploads"}
    return title in private_legacy_titles


def get_existing_video_ids(video_ids: list[str]) -> set[str]:
    """
    Check which video IDs already exist in the root /videos collection.
    Returns a set of existing video IDs.
    """
    if not video_ids:
        return set()

    try:
        db = firestore.client()
        videos_collection = db.collection("videos")

        existing_ids = set()

        # Firestore 'in' queries are limited to 10 items, so we batch
        for i in range(0, len(video_ids), 10):
            batch_ids = video_ids[i : i + 10]
            docs = videos_collection.where("videoId", "in", batch_ids).get()

            for doc in docs:
                existing_ids.add(doc.get("videoId"))

        logger.info(
            f"Found {len(existing_ids)} existing videos out of {len(video_ids)} checked"
        )
        return existing_ids

    except Exception as e:
        logger.error(f"Error checking existing videos: {type(e).__name__}: {str(e)}")
        return set()  # Fail safe - assume none exist to avoid data loss


@https_fn.on_call()
def sync_youtube_liked_videos(req: https_fn.CallableRequest) -> dict:
    """
    A scalable callable Cloud Function to sync a user's liked YouTube videos to Firestore.
    Uses the correct two-step API process for complete data integrity and performance.
    Now includes real-time progress reporting and video categorization.

    This function implements the efficient, batched algorithm:
    - Step 0: Create sync job document for progress tracking
    - Step A: Fetch all liked video items (public + private/legacy) with correct timestamps
    - Step B: Categorize videos and identify new public videos needing metadata
    - Step C: Batch fetch details for new public videos only
    - Step D: Atomic batch write for all operations with category fields
    - Step E: Update sync job completion status

    Expects: access_token and user_id in the request data.
    Returns: dict with sync statistics.
    """
    access_token = req.data.get("access_token")
    user_id = req.data.get("user_id")

    if not access_token:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid 'access_token'.",
        )

    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid 'user_id'.",
        )

    db = firestore.client()
    sync_job_ref = (
        db.collection("users")
        .document(user_id)
        .collection("syncJobs")
        .document("youtube_liked_videos")
    )

    try:
        logger.info(f"Starting efficient sync for user {user_id}")

        # Step 0: Create Sync Job Document for Progress Tracking
        logger.info("Step 0: Creating sync job document for progress tracking")
        sync_start_time = datetime.now(timezone.utc)

        # We'll update the total count once we know it
        initial_sync_job_data = {
            "status": "in_progress",
            "totalCount": 0,  # Will be updated after fetching video items
            "syncedCount": 0,
            "startedAt": sync_start_time,
        }
        sync_job_ref.set(initial_sync_job_data)
        logger.info("Sync job document created with initial state")

        # Step A: Fetch All Items - Get complete list with correct likedAt timestamps
        logger.info("Step A: Fetching all liked video items from playlist")
        all_video_items = fetch_liked_video_items(access_token)
        logger.info(f"Found {len(all_video_items)} total liked videos")

        # Update sync job with total count
        sync_job_ref.update({"totalCount": len(all_video_items)})
        logger.info(f"Updated sync job with total count: {len(all_video_items)}")

        if not all_video_items:
            # Complete sync job for empty result
            sync_job_ref.update(
                {"status": "completed", "completedAt": datetime.now(timezone.utc)}
            )
            return {"synced": 0, "public_videos": 0, "private_legacy_videos": 0}

        # Step B: Categorize and Identify New Public Videos
        logger.info("Step B: Categorizing videos and checking existing public videos")

        # Extract all video IDs
        all_video_ids = [item["videoId"] for item in all_video_items]

        # Check which videos already exist in the root /videos collection
        existing_video_ids = get_existing_video_ids(all_video_ids)
        logger.info(
            f"Found {len(existing_video_ids)} videos already in public collection"
        )

        # Get new video IDs that need metadata fetching
        new_video_ids = [
            vid_id for vid_id in all_video_ids if vid_id not in existing_video_ids
        ]
        logger.info(f"Need to fetch metadata for {len(new_video_ids)} new videos")

        # Step C: Batch Fetch Details for New Videos
        logger.info("Step C: Batch fetching details for new public videos")
        new_videos = []
        if new_video_ids:
            new_videos = fetch_video_details(access_token, new_video_ids)
            logger.info(
                f"Successfully fetched details for {len(new_videos)} new videos"
            )

            # Update progress after fetching video details
            sync_job_ref.update({"syncedCount": len(new_videos)})
            logger.info(f"Updated sync progress: {len(new_videos)} videos processed")

        # Categorize new videos into public and private/legacy
        public_videos = []
        private_legacy_video_ids = set()

        for video in new_videos:
            if is_private_legacy_video(video.title):
                private_legacy_video_ids.add(video.videoId)
                logger.info(
                    f"Categorized {video.videoId} as private/legacy: {video.title}"
                )
            else:
                public_videos.append(video)

        logger.info(
            f"Categorization complete: {len(public_videos)} public, {len(private_legacy_video_ids)} private/legacy new videos"
        )

        # Step D: Atomic Batch Write with Category Fields
        logger.info("Step D: Executing atomic batch write with categorization")
        batch = db.batch()

        sync_timestamp = datetime.now(timezone.utc)

        # Add new public videos to the root /videos collection with category field
        for video in public_videos:
            video_doc_ref = db.collection("videos").document(video.videoId)
            category = get_video_category(video.title, video.channelTitle)

            video_data = {
                "platform": video.platform,
                "videoId": video.videoId,
                "title": video.title,
                "description": video.description,
                "channelTitle": video.channelTitle,
                "thumbnailUrl": video.thumbnailUrl,
                "publishedAt": video.publishedAt,
                "addedToZensortAt": video.addedToZensortAt,
            }

            # Only add category field if it's not None (to avoid unnecessary null fields)
            if category is not None:
                video_data["category"] = category

            batch.set(video_doc_ref, video_data)

        # Add ALL videos (public + private/legacy) to user's liked videos subcollection
        # Using the correct likedAt timestamps from Step A
        for video_item in all_video_items:
            liked_video_doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("likedVideos")
                .document(video_item["videoId"])
            )
            batch.set(
                liked_video_doc_ref,
                {
                    "likedAt": video_item[
                        "likedAt"
                    ],  # Correct timestamp from playlist API
                    "syncedAt": sync_timestamp,
                },
            )

        # Execute the atomic batch write
        total_public_videos = len(public_videos)
        total_private_legacy = len(private_legacy_video_ids)
        total_user_relations = len(all_video_items)

        logger.info(
            f"Executing batch write: {total_public_videos} new public videos, {total_user_relations} user relations"
        )
        batch.commit()

        # Step E: Update Sync Job Completion Status
        logger.info("Step E: Updating sync job completion status")
        sync_job_ref.update(
            {
                "status": "completed",
                "syncedCount": len(all_video_items),
                "completedAt": datetime.now(timezone.utc),
            }
        )

        logger.info(f"Sync completed successfully for user {user_id}")

        return {
            "synced": len(all_video_items),
            "public_videos": total_public_videos,
            "private_legacy_videos": total_private_legacy,
            "total_liked_videos": len(all_video_items),
            "new_videos_processed": len(new_videos),
            "existing_videos_skipped": len(existing_video_ids),
        }

    except Exception as e:
        logger.error(
            f"Error during video sync for user {user_id}: {type(e).__name__}: {str(e)}"
        )

        # Update sync job with error status
        try:
            sync_job_ref.update(
                {
                    "status": "failed",
                    "completedAt": datetime.now(timezone.utc),
                    "error": str(e),
                }
            )
        except Exception as sync_error:
            logger.error(f"Failed to update sync job error status: {sync_error}")

        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred while syncing videos.",
        )
