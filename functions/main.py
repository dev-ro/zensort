# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy --only functions`

import os
from google.cloud import secretmanager
from google.cloud import firestore
from firebase_admin import initialize_app
from firebase_functions import https_fn, firestore_fn
from firebase_functions.options import set_global_options
import requests
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.errors import HttpError
import logging
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Generator
from openai import OpenAI
from concurrent.futures import ThreadPoolExecutor, as_completed

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Constants for embedding configuration
EMBEDDING_DIMENSIONALITY = 1536

# For cost control, you can set the maximum number of containers that can be
# running at the same time. This helps mitigate the impact of unexpected
# traffic spikes by instead downgrading performance. This limit is a per-function
# limit. You can override the limit for each function using the max_instances
# parameter in the decorator, e.g. @https_fn.on_request(max_instances=5).
set_global_options(max_instances=10)


def _get_openai_api_key() -> str:
    """
    Securely retrieve the OpenAI API key from Google Cloud Secret Manager.
    """
    try:
        # For local development, check environment variable first
        local_key = os.environ.get("OPENAI_API_KEY")
        if local_key:
            logger.info("Using OpenAI API key from local environment variable")
            return local_key

        # For production, fetch from Secret Manager
        project_id = os.environ.get("GCP_PROJECT")
        if not project_id:
            raise ValueError("GCP_PROJECT environment variable is not set.")

        # Create the Secret Manager client
        client = secretmanager.SecretManagerServiceClient()

        # Build the resource name
        secret_id = "openai-api-key"
        version_id = "latest"
        name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"

        # Access the secret
        response = client.access_secret_version(request={"name": name})
        api_key = response.payload.data.decode("UTF-8")
        logger.info("Successfully retrieved OpenAI API key from Secret Manager")
        return api_key

    except Exception as e:
        logger.error(f"Error retrieving OpenAI API key: {str(e)}")
        raise ValueError(f"Failed to retrieve OpenAI API key: {str(e)}")


initialize_app()


@https_fn.on_request()
def test_secret_manager(req: https_fn.Request) -> https_fn.Response:
    """
    Debug function to test Secret Manager integration and OpenAI API key retrieval.
    Returns environment information and success/failure status.
    """
    try:
        # Get project ID and function target from environment (use consistent variable names)
        project_id = os.environ.get("GCP_PROJECT", "Not found")
        function_region = os.environ.get("FUNCTION_REGION", "Not found")
        function_target = os.environ.get("K_SERVICE", "Not found")

        # Try to get the OpenAI API key
        api_key = _get_openai_api_key()

        # If we got here, it worked - create a safe response
        # Only return the first and last 4 chars of the key for verification
        key_preview = f"{api_key[:4]}...{api_key[-4:]}" if api_key else "No key found"

        return https_fn.Response(
            json.dumps(
                {
                    "status": "success",
                    "environment": {
                        "project_id": project_id,
                        "function_region": function_region,
                        "function_target": function_target,
                    },
                    "secret_manager": {
                        "key_retrieved": bool(api_key),
                        "key_preview": key_preview,
                    },
                }
            ),
            status=200,
            headers={"Content-Type": "application/json"},
        )

    except Exception as e:
        logger.error(f"Debug function error: {str(e)}")
        # Use the same consistent environment variable names in error response
        project_id = os.environ.get("GCP_PROJECT", "Not found")
        function_region = os.environ.get("FUNCTION_REGION", "Not found")
        function_target = os.environ.get("K_SERVICE", "Not found")
        return https_fn.Response(
            json.dumps(
                {
                    "status": "error",
                    "error": str(e),
                    "environment": {
                        "project_id": project_id,
                        "function_region": function_region,
                        "function_target": function_target,
                    },
                }
            ),
            status=500,
            headers={"Content-Type": "application/json"},
        )


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
        db = firestore.Client()
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

    Returns a list of dictionaries with 'videoId', 'likedAt', and 'title' keys.
    The title field contains the actual video title or status labels like "Private video", "Deleted video".
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

            # Extract video items with videoId, likedAt timestamp, and title
            for item in response.get("items", []):
                snippet = item.get("snippet", {})
                video_id = snippet.get("resourceId", {}).get("videoId")

                # YouTube API provides the actual title here, including "Private video", "Deleted video", etc.
                title = snippet.get("title", "")

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
                    video_items.append(
                        {"videoId": video_id, "likedAt": liked_at, "title": title}
                    )

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
        db = firestore.Client()
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
    Uses differential sync to handle liked/unliked videos and merge pattern for private/deleted videos.
    Includes real-time progress reporting, video categorization, and historical unlike tracking.

    This function implements the differential sync algorithm:
    - Step 0: Create sync job document for progress tracking
    - Step A: Fetch all liked video items (public + private/deleted) with correct timestamps
    - Step B: Fetch video details for ALL liked videos using merge pattern
    - Step C: Create lookup map and merge liked items with details, creating placeholders for private/deleted videos
    - Step D: Differential analysis - detect newly liked vs newly unliked videos
    - Step E: Differential batch write with unlike handling (moves unliked videos to unlikedVideos subcollection)
    - Step F: Update sync job completion status

    Key Features:
    - Detects when users unlike videos on YouTube and moves them to unlikedVideos subcollection
    - Preserves historical data for unliked videos (originalLikedAt, unlikedAt, reason)
    - Maintains complete data integrity with proper placeholder handling

    Expects: access_token and user_id in the request data.
    Returns: dict with comprehensive sync statistics including differential sync counts.
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

    db = firestore.Client()
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

        # Step B: Fetch Video Details Using Merge Pattern for Private/Deleted Videos
        logger.info(
            "Step B: Fetching video details with merge pattern for private/deleted videos"
        )

        # Extract all video IDs from liked items
        all_video_ids = [item["videoId"] for item in all_video_items]
        logger.info(f"Total video IDs to process: {len(all_video_ids)}")

        # Step C: Batch Fetch Details for ALL Videos (not just new ones)
        logger.info("Step C: Batch fetching details for all liked videos")
        video_details = []
        if all_video_ids:
            video_details = fetch_video_details(access_token, all_video_ids)
            logger.info(
                f"Successfully fetched details for {len(video_details)} out of {len(all_video_ids)} videos"
            )

            # Update progress after fetching video details
            sync_job_ref.update({"syncedCount": len(video_details)})
            logger.info(f"Updated sync progress: {len(video_details)} videos processed")

        # Create lookup map from video details keyed by videoId
        video_details_map = {video.videoId: video for video in video_details}
        logger.info(f"Created lookup map with {len(video_details_map)} video details")

        # Check which videos already exist in the root /videos collection
        existing_video_ids = get_existing_video_ids(all_video_ids)
        logger.info(
            f"Found {len(existing_video_ids)} videos already in public collection"
        )

        # Merge liked items with video details, creating placeholders for private/deleted videos
        videos_to_store = []
        private_legacy_count = 0

        for video_item in all_video_items:
            video_id = video_item["videoId"]
            liked_at = video_item["likedAt"]
            playlist_title = video_item[
                "title"
            ]  # Title from playlist API (includes "Private video", "Deleted video", etc.)

            # Skip videos that already exist in the /videos collection
            if video_id in existing_video_ids:
                continue

            if video_id in video_details_map:
                # Use actual video details from videos.list API
                video = video_details_map[video_id]
                videos_to_store.append(video)
                logger.debug(f"Using real details for video {video_id}: {video.title}")
            else:
                # Create placeholder using the title from playlist API
                # YouTube API provides accurate titles like "Private video", "Deleted video", etc.
                placeholder_title = (
                    playlist_title if playlist_title else "Private video"
                )

                # Set appropriate description based on the title
                if placeholder_title == "Private video":
                    placeholder_description = (
                        "This video is private and cannot be accessed."
                    )
                elif placeholder_title == "Deleted video":
                    placeholder_description = (
                        "This video has been deleted and is no longer available."
                    )
                else:
                    placeholder_description = (
                        f"This video ({placeholder_title}) is not accessible."
                    )

                # Create placeholder with the actual title from YouTube API
                placeholder_video = Video(
                    videoId=video_id,
                    title=placeholder_title,
                    description=placeholder_description,
                    thumbnailUrl="",
                    channelTitle="Unknown Channel",
                    publishedAt=liked_at,  # Use likedAt as publishedAt for placeholders
                    platform="YouTube",
                    addedToZensortAt=datetime.now(timezone.utc),
                )
                videos_to_store.append(placeholder_video)
                private_legacy_count += 1
                logger.info(
                    f"Created placeholder for video {video_id}: '{placeholder_title}'"
                )

        # Categorize videos into public and private/legacy
        public_videos = []
        private_legacy_video_ids = set()

        for video in videos_to_store:
            if is_private_legacy_video(video.title):
                private_legacy_video_ids.add(video.videoId)
            else:
                public_videos.append(video)

        logger.info(
            f"Categorization complete: {len(public_videos)} public videos, {len(private_legacy_video_ids)} private/legacy videos to store"
        )
        logger.info(
            f"Total placeholders created for private/deleted videos: {private_legacy_count}"
        )

        # Step D: Differential Analysis - Detect newly liked vs unliked videos
        logger.info("Step D: Performing differential sync analysis")
        
        # Get current YouTube video IDs 
        current_youtube_video_ids = set(item["videoId"] for item in all_video_items)
        logger.info(f"Current YouTube liked videos: {len(current_youtube_video_ids)}")
        
        # Get existing liked videos from Firestore
        existing_liked_docs = (
            db.collection("users")
            .document(user_id) 
            .collection("likedVideos")
            .stream()
        )
        existing_firestore_video_ids = set(doc.id for doc in existing_liked_docs)
        logger.info(f"Existing Firestore liked videos: {len(existing_firestore_video_ids)}")
        
        # Calculate differences
        newly_liked = current_youtube_video_ids - existing_firestore_video_ids
        still_liked = current_youtube_video_ids & existing_firestore_video_ids  
        newly_unliked = existing_firestore_video_ids - current_youtube_video_ids
        
        logger.info(
            f"Differential analysis complete: {len(newly_liked)} newly liked, "
            f"{len(still_liked)} still liked, {len(newly_unliked)} newly unliked"
        )

        # Step E: Differential Batch Write with Category Fields and Unlike Handling
        logger.info("Step E: Executing differential batch write with unlike handling")
        batch = db.batch()

        sync_timestamp = datetime.now(timezone.utc)

        # Add all videos (public + placeholders) to the root /videos collection
        for video in videos_to_store:
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

        # Add currently liked videos (newly liked + still liked) to user's liked videos subcollection
        # Using the correct likedAt timestamps from Step A
        for video_item in all_video_items:
            video_id = video_item["videoId"]
            
            # Only process videos that are currently liked on YouTube
            if video_id in newly_liked or video_id in still_liked:
                liked_video_doc_ref = (
                    db.collection("users")
                    .document(user_id)
                    .collection("likedVideos")
                    .document(video_id)
                )
                batch.set(
                    liked_video_doc_ref,
                    {
                        "likedAt": video_item["likedAt"],  # Correct timestamp from playlist API
                        "syncedAt": sync_timestamp,
                    },
                )
        
        # Handle newly unliked videos - move to unlikedVideos subcollection
        for unliked_video_id in newly_unliked:
            # Get original liked data to preserve historical information
            original_liked_doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("likedVideos")
                .document(unliked_video_id)
            )
            original_liked_doc = original_liked_doc_ref.get()
            
            if original_liked_doc.exists:
                original_data = original_liked_doc.to_dict()
                
                # Add to unlikedVideos subcollection with historical data
                unliked_video_doc_ref = (
                    db.collection("users")
                    .document(user_id)
                    .collection("unlikedVideos")
                    .document(unliked_video_id)
                )
                batch.set(
                    unliked_video_doc_ref,
                    {
                        "originalLikedAt": original_data["likedAt"],
                        "unlikedAt": sync_timestamp,
                        "syncedAt": sync_timestamp,
                        "reason": "user_unliked"
                    },
                )
                
                # Remove from likedVideos subcollection
                batch.delete(original_liked_doc_ref)
                
                logger.info(f"Moving unliked video {unliked_video_id} to unlikedVideos collection")

        # Execute the atomic batch write
        total_public_videos = len(public_videos)
        total_private_legacy = len(private_legacy_video_ids)
        total_user_relations = len(all_video_items)
        total_videos_stored = len(videos_to_store)

        logger.info(
            f"Executing differential batch write: {total_public_videos} public videos, "
            f"{total_private_legacy} private/legacy videos, {len(newly_liked)} newly liked, "
            f"{len(still_liked)} still liked, {len(newly_unliked)} newly unliked"
        )
        batch.commit()

        # Step F: Update Sync Job Completion Status
        logger.info("Step F: Updating sync job completion status")
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
            "videos_stored_in_collection": total_videos_stored,
            "existing_videos_skipped": len(existing_video_ids),
            "placeholders_created": private_legacy_count,
            # Differential sync statistics
            "newly_liked": len(newly_liked),
            "still_liked": len(still_liked),
            "newly_unliked": len(newly_unliked),
            "differential_sync_enabled": True,
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


def update_embedding_progress(user_id):
    db = firestore.Client()
    # Get all videoIds liked by this user
    liked_videos_ref = (
        db.collection("users").document(user_id).collection("likedVideos")
    )
    liked_video_docs = liked_videos_ref.stream()
    video_ids = [doc.id for doc in liked_video_docs]
    total = len(video_ids)
    completed = 0
    failed = 0
    for video_id in video_ids:
        video_doc = db.collection("videos").document(video_id).get()
        if not video_doc.exists:
            continue
        status = video_doc.get("embedding_status")
        if status == "complete":
            completed += 1
        elif status == "failed":
            failed += 1
    pending = total - completed - failed
    progress_ref = (
        db.collection("users")
        .document(user_id)
        .collection("embeddingProgress")
        .document("current")
    )
    progress_ref.set(
        {
            "total": total,
            "completed": completed,
            "failed": failed,
            "pending": pending,
            "last_updated": datetime.now(timezone.utc),
        },
        merge=True,
    )


@firestore_fn.on_document_written(document="videos/{videoId}")
def create_video_embedding(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """
    Event-driven function to generate embeddings for videos when they are created or updated.
    Triggered by onWrite on /videos/{videoId} documents.
    """
    video_data = None  # Ensure video_data is always defined
    try:
        logger.info(f"Processing embedding for video: {event.params['videoId']}")

        # Get the video document data from the 'after' snapshot
        video_data = (
            event.data.after.to_dict() if event.data and event.data.after else None
        )
        if not video_data:
            logger.warning(f"No data found for video {event.params['videoId']}")
            return

        # Skip if this is a batch update from the backfill process
        if "backfill_completed_at" in video_data:
            logger.info(
                f"Video {event.params['videoId']} is being updated by batch process, skipping individual processing"
            )
            return

        # Idempotency check: Skip if embedding is already complete
        embedding_status = video_data.get("embedding_status")
        if embedding_status == "complete":
            logger.info(
                f"Video {event.params['videoId']} already has completed embedding, skipping"
            )
            return

        # Only process if status is pending (set by backfill) or if this is a new video creation
        if embedding_status != "pending" and not _is_new_video_creation(event):
            logger.info(
                f"Video {event.params['videoId']} is not pending embedding processing, skipping"
            )
            return

        # Extract text fields for embedding
        title = video_data.get("title", "").strip()
        description = video_data.get("description", "").strip()
        channel_title = video_data.get("channelTitle", "").strip()

        if not title and not description and not channel_title:
            logger.warning(f"No text content found for video {event.params['videoId']}")
            _update_embedding_status(
                event.params["videoId"], "failed", error="No text content"
            )
            # Update progress for all users who have liked this video
            _update_progress_for_all_users(event.params["videoId"])
            return

        # Combine text fields for embedding
        combined_text = _prepare_embedding_text(title, description, channel_title)
        logger.info(f"Prepared text for embedding (length: {len(combined_text)})")

        # Update status to processing
        _update_embedding_status(event.params["videoId"], "processing")

        # Initialize OpenAI client once
        try:
            api_key = _get_openai_api_key()
            openai_client = OpenAI(api_key=api_key)
        except Exception as e:
            logger.error(f"Failed to initialize OpenAI client: {str(e)}")
            _update_embedding_status(
                event.params["videoId"],
                "failed",
                error=f"OpenAI client initialization failed: {str(e)}",
            )
            _update_progress_for_all_users(event.params["videoId"])
            return

        # Generate embedding using the pre-initialized client
        try:
            embedding_vector = _generate_embedding(openai_client, combined_text)
        except Exception as e:
            logger.error(
                f"Error generating embedding for video {event.params['videoId']}: {str(e)}"
            )
            _update_embedding_status(event.params["videoId"], "failed", error=str(e))
            _update_progress_for_all_users(event.params["videoId"])
            return

        # Update document with embedding and mark as complete
        db = firestore.Client()
        video_ref = db.collection("videos").document(event.params["videoId"])
        video_ref.update(
            {
                "embedding": embedding_vector,
                "embedding_status": "complete",
                "embedding_generated_at": datetime.now(timezone.utc),
            }
        )

        logger.info(
            f"Successfully generated embedding for video {event.params['videoId']}"
        )

        # Update progress for all users who have liked this video
        _update_progress_for_all_users(event.params["videoId"])

    except Exception as e:
        logger.error(
            f"Error processing embedding for video {event.params['videoId']}: {str(e)}"
        )
        _update_embedding_status(event.params["videoId"], "failed", error=str(e))
        _update_progress_for_all_users(event.params["videoId"])


def _update_progress_for_all_users(video_id):
    """For a given video_id, update embedding progress for all users who have liked it."""
    db = firestore.Client()
    # Query all users who have liked this video
    users_ref = db.collection("users")
    user_docs = users_ref.stream()
    for user_doc in user_docs:
        liked_video_ref = (
            users_ref.document(user_doc.id).collection("likedVideos").document(video_id)
        )
        if liked_video_ref.get().exists:
            update_embedding_progress(user_doc.id)


@https_fn.on_request(timeout_sec=300)
def trigger_video_embeddings(req: https_fn.Request) -> https_fn.Response:
    """
    Efficient batch processing function to generate embeddings for videos without valid embeddings.
    Processes batches of 25 videos per invocation to prevent timeouts.
    Handles all scenarios: new videos, failed embeddings, or invalid embedding dimensions.
    """
    try:
        # Initialize OpenAI client once at the start to avoid repeated Secret Manager calls
        try:
            api_key = _get_openai_api_key()
            openai_client = OpenAI(api_key=api_key)
            logger.info("Successfully initialized OpenAI client")
        except Exception as e:
            logger.error(f"Failed to initialize OpenAI client: {str(e)}")
            return https_fn.Response(
                json.dumps(
                    {
                        "success": False,
                        "error": f"Failed to initialize OpenAI client: {str(e)}",
                    }
                ),
                status=500,
                headers={"Content-Type": "application/json"},
            )

        # Simple security check - require a secret parameter
        # In production, this should use proper authentication
        secret = req.args.get("secret")
        if secret != "zensort-embedding-backfill-2024":
            return https_fn.Response("Unauthorized", status=401)

        # Get pagination cursor for resuming from previous batch
        start_after_id = req.args.get("start_after")
        batch_number = int(req.args.get("batch", "1"))

        logger.info(f"Starting embedding backfill process - Batch #{batch_number}")
        if start_after_id:
            logger.info(f"Resuming from video ID: {start_after_id}")

        db = firestore.Client()
        videos_collection = db.collection("videos")

        # Build query with cursor support for pagination
        # Process 25 videos per batch to prevent timeouts (reduced from 50)
        videos_query = videos_collection.order_by("__name__").limit(25)

        # Resume from where previous batch left off
        if start_after_id:
            start_after_doc = videos_collection.document(start_after_id).get()
            if start_after_doc.exists:
                videos_query = videos_query.start_after(start_after_doc)

        videos_batch = videos_query.get()

        logger.info(f"Retrieved {len(videos_batch)} videos for processing")

        # Collect videos that need embeddings
        videos_to_process = []
        video_texts = []
        skipped_count = 0
        last_doc_id = None

        for video_doc in videos_batch:
            last_doc_id = video_doc.id  # Track last processed document for pagination
            video_data = video_doc.to_dict()

            # Skip if video already has a valid, complete embedding
            if _has_valid_embedding(video_data):
                skipped_count += 1
                continue

            # Extract text fields for embedding
            title = video_data.get("title", "").strip()
            description = video_data.get("description", "").strip()
            channel_title = video_data.get("channelTitle", "").strip()

            if not title and not description and not channel_title:
                logger.warning(f"No text content found for video {video_doc.id}")
                skipped_count += 1
                continue

            # Combine text fields for embedding
            combined_text = _prepare_embedding_text(title, description, channel_title)

            videos_to_process.append(
                {
                    "id": video_doc.id,
                    "reference": video_doc.reference,
                    "text": combined_text,
                }
            )
            video_texts.append(combined_text)

        processed_count = len(videos_to_process)
        failed_count = 0

        if processed_count == 0:
            logger.info("No videos need embedding processing in this batch")
            result_message = f"Batch #{batch_number}: No videos needed processing, skipped {skipped_count} already processed"
        else:
            logger.info(f"Processing embeddings for {processed_count} videos")

            try:
                # Process embeddings concurrently using ThreadPoolExecutor
                logger.info(
                    f"Processing embeddings for {len(videos_to_process)} videos concurrently"
                )
                firestore_batch = db.batch()
                batch_timestamp = datetime.now(timezone.utc)
                successful_embeddings = 0
                failed_count = 0

                # Use ThreadPoolExecutor to process embeddings in parallel
                with ThreadPoolExecutor(max_workers=10) as executor:
                    # Submit all embedding generation tasks
                    future_to_video = {
                        executor.submit(
                            _generate_embedding, openai_client, video["text"]
                        ): video
                        for video in videos_to_process
                    }

                    logger.info(
                        f"Submitted {len(future_to_video)} embedding tasks to thread pool"
                    )

                    # Process results as they complete
                    for future in as_completed(future_to_video):
                        video_info = future_to_video[future]
                        try:
                            # Get the embedding result
                            embedding_vector = future.result()

                            # Update Firestore batch with successful result
                            firestore_batch.update(
                                video_info["reference"],
                                {
                                    "embedding": embedding_vector,
                                    "embedding_status": "complete",
                                    "embedding_generated_at": batch_timestamp,
                                    "backfill_completed_at": batch_timestamp,
                                },
                            )
                            successful_embeddings += 1
                            logger.debug(
                                f"Successfully generated embedding for video {video_info['id']}"
                            )

                        except Exception as e:
                            logger.error(
                                f"Failed to generate embedding for video {video_info['id']}: {str(e)}"
                            )
                            # Mark video as failed in Firestore batch
                            firestore_batch.update(
                                video_info["reference"],
                                {
                                    "embedding_status": "failed",
                                    "embedding_error": str(e),
                                    "embedding_updated_at": batch_timestamp,
                                    "backfill_completed_at": batch_timestamp,
                                },
                            )
                            failed_count += 1

                # Commit all updates in a single batch after all futures complete
                firestore_batch.commit()
                logger.info(
                    f"Successfully processed {successful_embeddings} videos with embeddings, {failed_count} failed"
                )

                processed_count = successful_embeddings
                result_message = f"Batch #{batch_number}: Successfully processed {processed_count} videos, skipped {skipped_count} already processed"
                if failed_count > 0:
                    result_message += f", {failed_count} failed"

            except Exception as e:
                logger.error(f"Error in batch embedding processing: {str(e)}")
                failed_count = len(videos_to_process)
                processed_count = 0
                result_message = f"Batch #{batch_number}: Failed to process {failed_count} videos - {str(e)}"

        # Check if we need to continue processing more videos (adjusted for new batch size)
        has_more_videos = (
            len(videos_batch) == 25
        )  # If we got a full batch, more likely exist

        if failed_count > 0:
            result_message += f", {failed_count} failed"

        logger.info(result_message)

        # Auto-continuation: If we processed a full batch, trigger next batch
        if has_more_videos and last_doc_id:
            next_batch_number = batch_number + 1
            continuation_url = f"https://us-central1-zensort-dev.cloudfunctions.net/trigger_video_embeddings?secret={secret}&start_after={last_doc_id}&batch={next_batch_number}"

            logger.info(
                f"Full batch processed. Triggering continuation batch #{next_batch_number}"
            )

            # Trigger next batch asynchronously
            try:
                import threading

                def trigger_next_batch():
                    time.sleep(2)  # Brief delay to avoid overwhelming
                    response = requests.get(continuation_url, timeout=10)
                    logger.info(
                        f"Triggered batch #{next_batch_number}: {response.status_code}"
                    )

                # Start continuation in background thread
                thread = threading.Thread(target=trigger_next_batch)
                thread.daemon = True
                thread.start()

                result_message += f" | Triggered batch #{next_batch_number}"

            except Exception as e:
                logger.error(f"Failed to trigger continuation: {e}")
                result_message += f" | Manual continuation needed: {continuation_url}"

        elif not has_more_videos:
            logger.info("Embedding backfill completed - no more videos to process")
            result_message += " | Backfill completed"

        return https_fn.Response(
            json.dumps(
                {
                    "success": True,
                    "message": result_message,
                    "batch_number": batch_number,
                    "processed_count": processed_count,
                    "skipped_count": skipped_count,
                    "failed_count": failed_count,
                    "has_more_videos": has_more_videos,
                    "last_doc_id": last_doc_id,
                }
            ),
            status=200,
            headers={"Content-Type": "application/json"},
        )

    except Exception as e:
        logger.error(f"Error in embedding backfill: {str(e)}")
        return https_fn.Response(
            json.dumps({"success": False, "error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"},
        )


def _is_new_video_creation(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> bool:
    """Check if this is a new video creation by examining the before/after snapshots."""
    # If there's no before data, this is a new document creation
    return event.data.before is None or not event.data.before.exists


def _prepare_embedding_text(title: str, description: str, channel_title: str) -> str:
    """Combine video fields into embedding-optimized text."""
    # Create structured text for better embedding quality
    # Let the API handle truncation automatically (no manual truncation)
    parts = []
    if title:
        parts.append(f"Title: {title}")
    if channel_title:
        parts.append(f"Channel: {channel_title}")
    if description:
        parts.append(f"Description: {description}")

    return " | ".join(parts)


def _generate_embedding(client: OpenAI, text: str) -> list:
    """Generate embedding vector using OpenAI's text-embedding-3-small model."""
    try:
        response = client.embeddings.create(
            model="text-embedding-3-small", input=[text]
        )
        embedding_vector = response.data[0].embedding
        if len(embedding_vector) != EMBEDDING_DIMENSIONALITY:
            logger.warning(
                f"Expected {EMBEDDING_DIMENSIONALITY} dimensions, got {len(embedding_vector)}"
            )
        return embedding_vector
    except Exception as e:
        logger.error(f"Error generating embedding with OpenAI: {e}")
        raise ValueError(f"Embedding generation failed: {e}")


def _has_valid_embedding(video_data: dict) -> bool:
    """
    Check if a video document has a complete, valid embedding vector.

    Returns True only if:
    - 'embedding' field exists
    - It's a list/array
    - It has the correct dimensionality
    """
    embedding = video_data.get("embedding")

    if not embedding:
        return False

    if not isinstance(embedding, list):
        return False

    if len(embedding) != EMBEDDING_DIMENSIONALITY:
        return False

    return True


def _update_embedding_status(video_id: str, status: str, error: str = None) -> None:
    """Update the embedding status for a video document."""
    try:
        db = firestore.Client()
        video_ref = db.collection("videos").document(video_id)

        update_data = {
            "embedding_status": status,
            "embedding_updated_at": datetime.now(timezone.utc),
        }

        if error:
            update_data["embedding_error"] = error

        video_ref.update(update_data)

    except Exception as e:
        logger.error(
            f"Failed to update embedding status for video {video_id}: {str(e)}"
        )


@https_fn.on_call()
def retry_failed_embeddings(req: https_fn.CallableRequest) -> dict:
    user_id = req.data.get("user_id")
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid 'user_id'.",
        )
    db = firestore.Client()
    # Get all videoIds liked by this user
    liked_videos_ref = (
        db.collection("users").document(user_id).collection("likedVideos")
    )
    liked_video_docs = liked_videos_ref.stream()
    retried = 0
    for doc in liked_video_docs:
        video_id = doc.id
        video_ref = db.collection("videos").document(video_id)
        video_doc = video_ref.get()
        if video_doc.exists and video_doc.get("embedding_status") == "failed":
            video_ref.update(
                {
                    "embedding_status": "pending",
                    "embedding_error": firestore.DELETE_FIELD,
                    "embedding_updated_at": datetime.now(timezone.utc),
                }
            )
            retried += 1
    update_embedding_progress(user_id)
    return {"retried": retried}
