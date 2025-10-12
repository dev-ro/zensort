# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy --only functions`

import os
from google.cloud import secretmanager
from firebase_admin import initialize_app
from firebase_functions import https_fn, firestore_fn
from firebase_functions.options import set_global_options
import requests
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
import google.oauth2.credentials as oauth2_credentials
from googleapiclient.errors import HttpError
import logging
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Generator, Any, Optional
from urllib.parse import unquote
from openai import OpenAI
from concurrent.futures import ThreadPoolExecutor, as_completed
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.field_path import FieldPath
from firebase_admin.firestore import firestore
from typing import Optional
from firebase_functions.firestore_fn import Event
from firebase_functions.core import Change
from google.cloud.firestore_v1.base_document import DocumentSnapshot
from firebase_functions.https_fn import on_request
from typing import Any


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
        version_id = "4"
        name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"

        # Access the secret
        response = client.access_secret_version(request={"name": name})
        api_key = response.payload.data.decode("UTF-8")
        logger.info("Successfully retrieved OpenAI API key from Secret Manager")
        return api_key

    except Exception as e:
        logger.error(f"Error retrieving OpenAI API key: {str(e)}")
        raise ValueError(f"Failed to retrieve OpenAI API key: {str(e)}")


# Initialize Firebase Admin SDK only if not already initialized
try:
    initialize_app()
except ValueError as e:
    if "already exists" in str(e):
        # App already initialized, this is fine
        pass
    else:
        # Some other error, re-raise it
        raise


def _firestore():
    # Lazy import to make testing and local execution more reliable
    from google.cloud import firestore as _firestore_mod

    return _firestore_mod


# In-memory cache for category maps by (regionCode, hl)
_CATEGORY_CACHE: dict[tuple[str, str], dict[str, Any]] = {}
_CATEGORY_CACHE_TTL_SECONDS = 6 * 60 * 60  # 6 hours


def _parse_locale_to_region_hl(locale: str) -> tuple[str, str]:
    """Return (regionCode, hl) from BCP 47 locale like 'en-US'."""
    try:
        if not isinstance(locale, str) or not locale:
            return ("US", "en")
        parts = locale.replace("_", "-").split("-")
        if len(parts) == 1:
            return ("US", parts[0].lower())
        lang = parts[0].lower()
        region = parts[-1].upper()
        return (region, lang)
    except Exception:
        return ("US", "en")


def _get_user_locale(db, user_id: str) -> str:
    """Fetch user's preferred locale from /users/{uid}/settings.locale or default 'en-US'."""
    try:
        user_doc = db.collection("users").document(user_id).get()
        if user_doc.exists:
            data = user_doc.to_dict() or {}
            settings = data.get("settings") or {}
            loc = settings.get("locale")
            if isinstance(loc, str) and loc:
                return loc
    except Exception:
        pass
    return "en-US"


def _normalize_topic_from_url(url: str) -> str | None:
    """Extract terminal path segment from a Wikipedia URL, decode,
    replace underscores with spaces, and title-case it.
    Returns None if input invalid or segment empty.
    """
    try:
        if not isinstance(url, str) or not url:
            return None
        # Take last segment after '/'
        segment = url.rsplit("/", 1)[-1]
        if not segment:
            return None
        # Decode percent-encoding and transform
        decoded = unquote(segment)
        cleaned = decoded.replace("_", " ").strip()
        if not cleaned:
            return None
        return cleaned.title()
    except Exception:
        return None


def _slugify(value: str) -> str:
    """Produce a URL-safe slug from a topic name: lowercase, hyphen-separated."""
    try:
        v = value.strip().lower()
        # Replace non-alphanum with hyphens
        out = []
        prev_dash = False
        for ch in v:
            if ch.isalnum():
                out.append(ch)
                prev_dash = False
            else:
                if not prev_dash:
                    out.append("-")
                    prev_dash = True
        slug = "".join(out).strip("-")
        return slug or "topic"
    except Exception:
        return "topic"


def _build_youtube_service(access_token: str):
    credentials = oauth2_credentials.Credentials(
        token=access_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id="unused",
        client_secret="unused",
        scopes=["https://www.googleapis.com/auth/youtube.readonly"],
    )
    try:
        if getattr(credentials, "universe_domain", None) is None or isinstance(
            getattr(credentials, "universe_domain"), object
        ):
            setattr(credentials, "universe_domain", "googleapis.com")
    except Exception:
        pass
    return build("youtube", "v3", credentials=credentials)


def _get_category_map_for_locale(
    access_token: str, region_code: str, hl: str, db
) -> dict[str, str]:
    """Return a map of videoCategory id -> localized title for a given locale.
    Caches in-memory and in Firestore doc `/ytCategoryMaps/{region_hl}`.
    """
    try:
        cache_key = (region_code, hl)
        now = time.time()
        cached = _CATEGORY_CACHE.get(cache_key)
        if cached and isinstance(cached.get("fetched_at"), (int, float)):
            if now - cached["fetched_at"] < _CATEGORY_CACHE_TTL_SECONDS:
                return cached.get("map", {})

        # Try Firestore cache first
        doc_id = f"{region_code}_{hl}"
        cache_ref = db.collection("ytCategoryMaps").document(doc_id)
        cache_doc = cache_ref.get()
        if cache_doc.exists:
            data = cache_doc.to_dict() or {}
            categories = data.get("categories")
            if isinstance(categories, dict) and categories:
                # Update memory cache and return
                _CATEGORY_CACHE[cache_key] = {"map": categories, "fetched_at": now}
                return categories

        # Fetch from YouTube API
        youtube = _build_youtube_service(access_token)
        request = youtube.videoCategories().list(
            part="snippet", regionCode=region_code, hl=hl
        )
        response = request.execute()
        items = response.get("items", [])
        category_map: dict[str, str] = {}
        for item in items:
            cid = str(item.get("id", "")).strip()
            snippet = item.get("snippet", {})
            title = (snippet.get("title") or "").strip()
            if cid and title:
                category_map[cid] = title

        # Persist cache to Firestore and memory
        cache_ref.set(
            {
                "categories": category_map,
                "updatedAt": datetime.now(timezone.utc),
            }
        )
        _CATEGORY_CACHE[cache_key] = {"map": category_map, "fetched_at": now}
        return category_map
    except Exception as e:
        logger.error(f"Failed to resolve category map for {region_code}/{hl}: {e}")
        return {}


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
        db = _firestore().Client()
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
    addedToZensortAt: datetime | None = None
    # Authoritative classification fields from YouTube Data API v3
    categoryId: str | None = None
    topicCategories: list[str] | None = None


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
        youtube = _build_youtube_service(access_token)

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
        youtube = _build_youtube_service(access_token)

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

        youtube = _build_youtube_service(access_token)

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
                    part="id,snippet,contentDetails,topicDetails",
                    id=",".join(batch_ids),
                )
                response = request.execute()

                batch_videos = []  # Videos from this batch

                # Process each item in the response
                for item in response.get("items", []):
                    snippet = item.get("snippet", {})
                    topic_details = item.get("topicDetails", {})

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

                    # Choose the best available thumbnail
                    thumbs = snippet.get("thumbnails", {})
                    best_thumb = (
                        thumbs.get("maxres", {}).get("url")
                        or thumbs.get("standard", {}).get("url")
                        or thumbs.get("high", {}).get("url")
                        or f"https://i.ytimg.com/vi/{item['id']}/hqdefault.jpg"
                    )

                    # Category metadata
                    category_id = snippet.get("categoryId", "")
                    topics = topic_details.get("topicCategories", []) or []

                    video = Video(
                        videoId=item["id"],
                        title=snippet.get("title", ""),
                        description=snippet.get("description", ""),
                        thumbnailUrl=best_thumb,
                        channelTitle=snippet.get("channelTitle", ""),
                        publishedAt=published_at,
                        platform="YouTube",
                        addedToZensortAt=datetime.now(timezone.utc),
                        categoryId=category_id,
                        topicCategories=topics,
                    )
                    batch_videos.append(video)

                # Add this batch's results to the master list
                all_videos.extend(batch_videos)

            except HttpError as e:
                logger.error(
                    f"YouTube API error while fetching video details: {e.resp.status}"
                )
                raise

        logger.info(
            f"Completed fetch_video_details: aggregated {len(all_videos)} detailed videos"
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
    Uses efficient batch reading with get_all() for better performance.
    """
    if not video_ids:
        return set()

    try:
        db = _firestore().Client()
        videos_collection = db.collection("videos")

        # Create document references for all video IDs
        doc_refs = [videos_collection.document(video_id) for video_id in video_ids]

        # Use get_all() to fetch all documents in a single batch operation
        docs = db.get_all(doc_refs)

        # Extract video IDs from existing documents
        existing_ids = set()
        for doc in docs:
            if doc.exists:
                existing_ids.add(doc.id)

        logger.info(
            f"Found {len(existing_ids)} existing videos out of {len(video_ids)} checked"
        )
        return existing_ids

    except Exception as e:
        logger.error(f"Error checking existing videos: {type(e).__name__}: {str(e)}")
        return set()  # Fail safe - assume none exist to avoid data loss


@https_fn.on_call(timeout_sec=540)  # 9 minutes timeout for large syncs
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

    db = _firestore().Client()
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

        # Step B: Check Existing Videos First (Performance Optimization)
        logger.info("Step B: Checking which videos already exist in database")

        # Extract all video IDs from liked items
        all_video_ids = [item["videoId"] for item in all_video_items]
        logger.info(f"Total video IDs to process: {len(all_video_ids)}")

        # Check which videos already exist in the root /videos collection FIRST
        existing_video_ids = get_existing_video_ids(all_video_ids)
        logger.info(
            f"Found {len(existing_video_ids)} videos already in public collection"
        )

        # Only fetch details for NEW videos by default (performance optimization)
        new_video_ids = [
            vid_id for vid_id in all_video_ids if vid_id not in existing_video_ids
        ]

        # Step C: Batch fetch details for NEW videos and enrichment candidates
        logger.info(
            "Step C: Batch fetching details for new videos and enrichment candidates"
        )
        ids_to_fetch = new_video_ids
        video_details: list[Video] = []
        if ids_to_fetch:
            video_details = fetch_video_details(access_token, ids_to_fetch)
            logger.info(
                f"Fetched details for {len(video_details)} of {len(ids_to_fetch)} requested videos"
            )

            # Update progress after fetching video details
            sync_job_ref.update({"syncedCount": len(video_details)})
            logger.info(f"Updated sync progress: {len(video_details)} videos processed")

        # Create lookup map from video details keyed by videoId
        video_details_map = {video.videoId: video for video in video_details}
        logger.info(f"Created lookup map with {len(video_details_map)} video details")

        # Merge liked items with video details, creating placeholders for private/deleted videos
        videos_to_store = []  # Only new videos need to be stored
        private_legacy_count = 0

        for video_item in all_video_items:
            video_id = video_item["videoId"]
            liked_at = video_item["likedAt"]
            playlist_title = video_item[
                "title"
            ]  # Title from playlist API (includes "Private video", "Deleted video", etc.)

            # Skip existing videos - they don't need processing in videos collection
            if video_id in existing_video_ids:
                logger.debug(f"Skipping existing video {video_id}")
                continue

            # Process only NEW videos
            if video_id in video_details_map:
                # New video with actual details from videos.list API
                video = video_details_map[video_id]
                videos_to_store.append(video)
                logger.debug(f"Storing new video {video_id}: {video.title}")
            else:
                # New video without details - create placeholder using playlist API title
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
                logger.info(
                    f"Creating new placeholder for video {video_id}: '{placeholder_title}'"
                )
                private_legacy_count += 1

        # Categorize NEW videos into public and private/legacy
        public_videos = []
        private_legacy_video_ids = set()

        for video in videos_to_store:
            if is_private_legacy_video(video.title):
                private_legacy_video_ids.add(video.videoId)
            else:
                public_videos.append(video)

        logger.info(
            f"Categorization complete: {len(public_videos)} public videos, {len(private_legacy_video_ids)} private/legacy videos"
        )
        logger.info(
            f"New videos to store: {len(videos_to_store)}, Existing videos skipped: {len(existing_video_ids)}"
        )
        logger.info(
            f"Total placeholders created for private/deleted videos: {private_legacy_count}"
        )

        # Step D: Differential Analysis - Detect newly liked vs unliked videos
        logger.info("Step D: Performing differential sync analysis")

        # Get current YouTube video IDs
        current_youtube_video_ids = set(item["videoId"] for item in all_video_items)
        logger.info(f"Current YouTube liked videos: {len(current_youtube_video_ids)}")

        # Get existing liked videos from Firestore with their data (for efficient unliked processing)
        # Using .get() instead of .stream() for better performance when processing all documents
        existing_liked_docs = (
            db.collection("users").document(user_id).collection("likedVideos").get()
        )
        existing_liked_data = {}  # Store document data for efficient access
        existing_firestore_video_ids = set()

        for doc in existing_liked_docs:
            existing_firestore_video_ids.add(doc.id)
            existing_liked_data[doc.id] = doc.to_dict()  # Cache document data

        logger.info(
            f"Existing Firestore liked videos: {len(existing_firestore_video_ids)}"
        )

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

        # Resolve US category title map (standardized across users)
        category_map_us = _get_category_map_for_locale(access_token, "US", "en", db)

        # Add new videos (public + placeholders) to the root /videos collection
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
                "embedding": None,
                "embedding_status": "pending",
            }

            # Include authoritative YouTube classification fields when available
            if getattr(video, "categoryId", None) is not None:
                video_data["categoryId"] = video.categoryId

            # Compute US category title (standardized)
            try:
                cid_str = str(getattr(video, "categoryId", "") or "").strip()
                if cid_str:
                    video_data["categoryTitleUS"] = category_map_us.get(cid_str)
            except Exception:
                pass

            # Persist raw topicCategories for provenance
            if getattr(video, "topicCategories", None) is not None:
                topics_raw = list(getattr(video, "topicCategories") or [])
                video_data["topicCategories"] = topics_raw
                # Derive cleaned topicTags (Title Case short names)
                cleaned = []
                seen = set()
                for t in topics_raw:
                    norm = _normalize_topic_from_url(t)
                    if not norm:
                        continue
                    if norm in seen:
                        continue
                    seen.add(norm)
                    cleaned.append(norm)
                # Truncate to top 5 to keep documents lean
                if cleaned:
                    video_data["topicTags"] = cleaned[:5]

            # Only add category field if it's not None (to avoid unnecessary null fields)
            if category is not None:
                video_data["category"] = category

            batch.set(video_doc_ref, video_data)

        # Create a map of videoId to its initial embedding_status for new videos
        new_video_status_map = {
            video.videoId: (
                "pending"
                if not is_private_legacy_video(video.title)
                else "not_applicable"
            )
            for video in videos_to_store
        }

        # Efficiently fetch embedding_status for all existing videos in one batch
        existing_video_status_map = {}
        if existing_video_ids:
            # Process existing video IDs in chunks of 30 (Firestore IN limit)
            chunk_size = 30
            for i in range(0, len(existing_video_ids), chunk_size):
                chunk_ids = list(existing_video_ids)[i : i + chunk_size]
                video_docs_query = db.collection("videos").where(
                    FieldPath.document_id(), "in", chunk_ids
                )
                video_docs = video_docs_query.stream()
                for doc in video_docs:
                    data = doc.to_dict()
                    if data:
                        existing_video_status_map[doc.id] = data.get(
                            "embedding_status", "pending"
                        )

        # Add currently liked videos (newly liked + still liked) to user's liked videos subcollection
        # Using the correct likedAt timestamps from Step A. Keep link docs minimal.
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

                # Get the video's embedding status efficiently from pre-fetched maps
                embedding_status = new_video_status_map.get(video_id)
                if embedding_status is None:
                    # For existing videos, use the pre-fetched status map
                    embedding_status = existing_video_status_map.get(
                        video_id, "pending"
                    )

                # Prepare minimal relation payload (link-only)
                relation_data = {
                    "videoId": video_id,
                    "likedAt": video_item["likedAt"],
                    "syncedAt": sync_timestamp,
                    "embedding_status": embedding_status,
                }
                batch.set(liked_video_doc_ref, relation_data)

                # Create reverse index for status propagation
                reverse_index_ref = (
                    db.collection("videos")
                    .document(video_id)
                    .collection("likedByUsers")
                    .document(user_id)
                )
                batch.set(reverse_index_ref, {"syncedAt": sync_timestamp})

                # Maintain topics reverse references under /topics/{slug}/videos/{videoId}
                try:
                    vdoc_ref = db.collection("videos").document(video_id)
                    vdoc = vdoc_ref.get()
                    if vdoc.exists:
                        vdata = vdoc.to_dict()
                        if vdata:
                            topic_tags = vdata.get("topicTags", [])
                            for tag in topic_tags[:10]:  # cap fan-out per video
                                if not isinstance(tag, str) or not tag:
                                    continue
                                slug = _slugify(tag)
                                topic_ref = db.collection("topics").document(slug)
                                batch.set(
                                    topic_ref,
                                    {
                                        "name": tag,
                                        "slug": slug,
                                        "createdAt": sync_timestamp,
                                    },
                                    merge=True,
                                )
                                topic_video_ref = topic_ref.collection(
                                    "videos"
                                ).document(video_id)
                                batch.set(
                                    topic_video_ref,
                                    {"createdAt": sync_timestamp},
                                    merge=True,
                                )
                except Exception as _:
                    pass

        # Handle newly unliked videos - move to unlikedVideos subcollection
        for unliked_video_id in newly_unliked:
            # Use cached liked data (no individual Firestore reads needed)
            original_data = existing_liked_data.get(unliked_video_id)

            if original_data:
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
                        "reason": "user_unliked",
                    },
                )

                # Remove from likedVideos subcollection
                original_liked_doc_ref = (
                    db.collection("users")
                    .document(user_id)
                    .collection("likedVideos")
                    .document(unliked_video_id)
                )
                batch.delete(original_liked_doc_ref)

                # Remove the reverse index entry
                reverse_index_ref = (
                    db.collection("videos")
                    .document(unliked_video_id)
                    .collection("likedByUsers")
                    .document(user_id)
                )
                batch.delete(reverse_index_ref)

                logger.info(
                    f"Moving unliked video {unliked_video_id} to unlikedVideos collection"
                )
            else:
                logger.warning(
                    f"No original data found for unliked video {unliked_video_id}"
                )

        # Execute the atomic batch write
        total_public_videos = len(public_videos)
        total_private_legacy = len(private_legacy_video_ids)
        total_user_relations = len(all_video_items)
        total_videos_processed = len(videos_to_store)  # Only new videos processed

        logger.info(
            f"Executing optimized differential batch write: {total_public_videos} public videos, "
            f"{total_private_legacy} private/legacy videos, {len(videos_to_store)} new videos, "
            f"{len(existing_video_ids)} existing skipped, {len(newly_liked)} newly liked, "
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

        # Step G: Initialize Embedding Progress - REMOVED
        # This is now handled by on-demand queries in the client
        logger.info("Step G: Embedding progress is now calculated on-demand.")

        logger.info(f"Sync completed successfully for user {user_id}")

        return {
            "synced": len(all_video_items),
            "public_videos": total_public_videos,
            "private_legacy_videos": total_private_legacy,
            "total_liked_videos": len(all_video_items),
            "videos_processed": total_videos_processed,
            "videos_stored_new": len(videos_to_store),
            "videos_skipped_existing": len(existing_video_ids),
            "placeholders_created": private_legacy_count,
            # Differential sync statistics
            "newly_liked": len(newly_liked),
            "still_liked": len(still_liked),
            "newly_unliked": len(newly_unliked),
            "differential_sync_enabled": True,
            "performance_optimized": True,
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
            message=f"An unexpected error occurred while syncing videos. Original error: {str(e)}",
        )


@firestore_fn.on_document_written(document="videos/{videoId}")
def propagate_embedding_status(
    event: Event[Change[DocumentSnapshot | None]],
) -> None:
    """
    Propagates embedding_status changes from /videos/{videoId] to all users who
    have liked that video via the reverse index in /videos/{videoId}/likedByUsers.
    """
    video_id = event.params["videoId"]

    # Safely access before and after data
    if event.data is None:
        logger.info(f"No data for video {video_id}. No propagation needed.")
        return

    before_data = event.data.before.to_dict() if event.data.before else None
    after_data = event.data.after.to_dict() if event.data.after else None

    before_status = before_data.get("embedding_status") if before_data else None
    after_status = after_data.get("embedding_status") if after_data else None

    # Only proceed if the embedding_status has actually changed
    if before_status == after_status:
        logger.info(
            f"Status for video {video_id} unchanged ('{after_status}'). No propagation needed."
        )
        return

    if not after_status:
        logger.warning(
            f"Video {video_id} has no embedding_status in after_data. Cannot propagate."
        )
        return

    logger.info(
        f"Status for video {video_id} changed from '{before_status}' to '{after_status}'. Propagating..."
    )

    db = _firestore().Client()
    liked_by_ref = db.collection("videos").document(video_id).collection("likedByUsers")

    try:
        # Get all users who have liked this video
        liked_by_docs = list(liked_by_ref.stream())
        if not liked_by_docs:
            logger.info(f"Video {video_id} is not liked by any users. Nothing to do.")
            return

        user_ids = [doc.id for doc in liked_by_docs]
        logger.info(
            f"Found {len(user_ids)} users who liked video {video_id}. Updating status..."
        )

        # Use a batch write to update all users' likedVideos subcollections
        batch = db.batch()
        for user_id in user_ids:
            user_liked_video_ref = (
                db.collection("users")
                .document(user_id)
                .collection("likedVideos")
                .document(video_id)
            )
            batch.update(user_liked_video_ref, {"embedding_status": after_status})

        batch.commit()
        logger.info(
            f"Successfully propagated status '{after_status}' for video {video_id} to {len(user_ids)} users."
        )

    except Exception as e:
        logger.error(
            f"Error propagating status for video {video_id}: {type(e).__name__}: {str(e)}"
        )


@firestore_fn.on_document_written(document="videos/{videoId}")
def create_video_embedding(event) -> None:
    """
    Event-driven function to generate embeddings for videos when they are created or updated.
    Triggered by onWrite on /videos/{videoId} documents.
    """
    video_data = None  # Ensure video_data is always defined
    video_id = event.params["videoId"]
    try:
        logger.info(f"Processing embedding for video: {video_id}")

        # Get the video document data from the 'after' snapshot
        video_data = (
            event.data.after.to_dict() if event.data and event.data.after else None
        )
        if not video_data:
            logger.warning(f"No data found for video {video_id}")
            return

        # Handle private or deleted videos by marking them as not applicable
        title = video_data.get("title", "")
        private_legacy_titles = {"Private video", "Deleted video"}
        if title in private_legacy_titles:
            logger.info(f"Skipping embedding for '{title}' video {video_id}")
            _update_embedding_status(
                video_id, "not_applicable", error=f"Video is '{title}'"
            )
            return

        # Skip if this is a batch update from the backfill process
        if "backfill_completed_at" in video_data:
            logger.info(
                f"Video {video_id} is being updated by batch process, skipping individual processing"
            )
            return

        # Idempotency check: Skip if embedding is already complete
        embedding_status = video_data.get("embedding_status")
        if embedding_status == "complete":
            logger.info(f"Video {video_id} already has completed embedding, skipping")
            return

        # Process if: status is pending, OR this is new video creation, OR video has no embedding
        video_has_no_embedding = "embedding" not in video_data
        if (
            not video_has_no_embedding
            and embedding_status != "pending"
            and not _is_new_video_creation(event)
        ):
            logger.info(
                f"Video {video_id} is not pending embedding processing, skipping"
            )
            return

        # Extract text fields for embedding
        title = video_data.get("title", "").strip()
        description = video_data.get("description", "").strip()
        channel_title = video_data.get("channelTitle", "").strip()

        if not title and not description and not channel_title:
            logger.warning(f"No text content found for video {video_id}")
            _update_embedding_status(video_id, "failed", error="No text content")
            return

        # Combine text fields for embedding including category and topics
        category_us = video_data.get("categoryTitleUS") or None
        topic_tags = video_data.get("topicTags") or None
        combined_text = _prepare_embedding_text(
            title, description, channel_title, category_us, topic_tags
        )
        logger.info(f"Prepared text for embedding (length: {len(combined_text)})")

        # Update status to processing
        _update_embedding_status(video_id, "processing")

        # Initialize OpenAI client once
        try:
            api_key = _get_openai_api_key()
            openai_client = OpenAI(api_key=api_key)
        except Exception as e:
            logger.error(f"Failed to initialize OpenAI client: {str(e)}")
            _update_embedding_status(
                video_id,
                "failed",
                error=f"OpenAI client initialization failed: {str(e)}",
            )
            return

        # Generate embedding using the pre-initialized client
        try:
            embedding_vector = _generate_embedding(openai_client, combined_text)
        except Exception as e:
            logger.error(f"Error generating embedding for video {video_id}: {str(e)}")
            _update_embedding_status(video_id, "failed", error=str(e))
            return

        # Update document with embedding and mark as complete
        db = _firestore().Client()
        video_ref = db.collection("videos").document(video_id)
        video_ref.update(
            {
                "embedding": embedding_vector,
                "embedding_status": "complete",
                "embedding_generated_at": datetime.now(timezone.utc),
                "embedding_error": firestore.DELETE_FIELD,  # Ensure any previous error is cleared
            }
        )

        logger.info(f"Successfully generated embedding for video {video_id}")

    except Exception as e:
        logger.error(f"Error processing embedding for video {video_id}: {str(e)}")
        _update_embedding_status(video_id, "failed", error=str(e))


@https_fn.on_request(timeout_sec=300)
def trigger_video_embeddings(req) -> Any:
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
            return (
                json.dumps(
                    {
                        "success": False,
                        "error": f"Failed to initialize OpenAI client: {str(e)}",
                    }
                ),
                500,
                {"Content-Type": "application/json"},
            )

        # Simple security check - require a secret parameter
        # In production, this should use proper authentication
        secret = req.args.get("secret")
        if secret != "zensort-embedding-backfill-2024":
            return ("Unauthorized", 401)

        # Get pagination cursor for resuming from previous batch
        start_after_id = req.args.get("start_after")
        batch_number = int(req.args.get("batch", "1"))

        logger.info(f"Starting embedding backfill process - Batch #{batch_number}")
        if start_after_id:
            logger.info(f"Resuming from video ID: {start_after_id}")

        db = _firestore().Client()
        videos_collection = db.collection("videos")

        # Build query with cursor support for pagination
        # Process 25 videos per batch to prevent timeouts (reduced from 50)
        # Use efficient filtering to only get videos without embeddings
        videos_query = (
            videos_collection.where("embedding", "==", None)
            .order_by("__name__")
            .limit(25)
        )

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

            # Skip documents without data
            if not video_data:
                skipped_count += 1
                continue

            # Skip if video already has a valid, complete embedding
            if _has_valid_embedding(video_data):
                skipped_count += 1
                continue

            # Skip videos that are private or deleted.
            title = video_data.get("title", "").strip()
            if title in {"Private video", "Deleted video"}:
                logger.info(
                    f"Skipping embedding for '{title}' video {video_doc.id}, marking as not_applicable"
                )
                video_doc.reference.update({"embedding_status": "not_applicable"})
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

            # Combine text fields for embedding including category and topics
            category_us = video_data.get("categoryTitleUS") or None
            topic_tags = video_data.get("topicTags") or None
            combined_text = _prepare_embedding_text(
                title, description, channel_title, category_us, topic_tags
            )

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
            logger.info(
                f"Processing embeddings for {processed_count} videos in a single batch"
            )

            try:
                # Use a single API call for all video texts
                response = openai_client.embeddings.create(
                    model="text-embedding-3-small", input=video_texts
                )
                embeddings = response.data

                if len(embeddings) != len(videos_to_process):
                    raise ValueError(
                        f"Mismatch between requested texts ({len(videos_to_process)}) and received embeddings ({len(embeddings)})"
                    )

                firestore_batch = db.batch()
                batch_timestamp = datetime.now(timezone.utc)
                successful_embeddings = 0

                for i, video_info in enumerate(videos_to_process):
                    embedding_vector = embeddings[i].embedding
                    if len(embedding_vector) != EMBEDDING_DIMENSIONALITY:
                        logger.warning(
                            f"Video {video_info['id']} has incorrect embedding dimensions: {len(embedding_vector)}"
                        )
                        # Mark as failed if dimensions are wrong
                        firestore_batch.update(
                            video_info["reference"],
                            {
                                "embedding_status": "failed",
                                "embedding_error": f"Incorrect embedding dimensions: {len(embedding_vector)}",
                                "embedding_updated_at": batch_timestamp,
                            },
                        )
                        failed_count += 1
                    else:
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

        return (
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
            200,
            {"Content-Type": "application/json"},
        )

    except Exception as e:
        logger.error(f"Error in embedding backfill: {str(e)}")
        return (
            json.dumps({"success": False, "error": str(e)}),
            500,
            {"Content-Type": "application/json"},
        )


def _is_new_video_creation(event) -> bool:
    """Check if this is a new video creation by examining the before/after snapshots."""
    # If there's no before data, this is a new document creation
    return event.data.before is None or not event.data.before.exists


def _prepare_embedding_text(
    title: str,
    description: str,
    channel_title: str,
    category_us: str | None = None,
    topic_tags: list[str] | None = None,
) -> str:
    """Combine video fields into embedding-optimized text including category and topics."""
    # Create structured text for better embedding quality
    parts = []
    if title:
        parts.append(f"Title: {title}")
    if channel_title:
        parts.append(f"Channel: {channel_title}")
    if category_us:
        parts.append(f"Category (US): {category_us}")
    if topic_tags:
        # join unique topic tags
        tags = ", ".join(
            sorted(set([t for t in topic_tags if isinstance(t, str) and t]))[:8]
        )
        if tags:
            parts.append(f"Topics: {tags}")
    if description:
        parts.append(f"Description: {description}")
    return "\n".join(parts)


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


def _embedding_vector_is_valid(embedding: Any) -> bool:
    """Checks if the provided embedding is a list with the correct dimensionality."""
    if not isinstance(embedding, list):
        return False
    if len(embedding) != EMBEDDING_DIMENSIONALITY:
        return False
    return True


def _has_valid_embedding(video_data: dict | None) -> bool:
    """
    Check if a video document has a complete, valid embedding vector.
    Since all documents now have the embedding field (either with vector or null),
    we can simplify the logic.

    Returns True only if:
    - embedding_status is "not_applicable" (private/deleted videos)
    - embedding_status is "complete"
    - embedding is a valid vector with correct dimensionality
    """
    if not video_data:
        return False

    # If status is not_applicable or complete, it's considered "valid" for skipping purposes
    if video_data.get("embedding_status") in ("not_applicable", "complete"):
        return True

    return _embedding_vector_is_valid(video_data.get("embedding"))


def _update_embedding_status(
    video_id: str, status: str, error: str | None = None
) -> None:
    """Update the embedding status for a video document, with verification."""
    try:
        db = _firestore().Client()
        video_ref = db.collection("videos").document(video_id)

        # Fortification: If attempting to mark as failed, first check if a valid embedding already exists.
        if status == "failed":
            video_doc = video_ref.get()
            if video_doc.exists:
                video_data = video_doc.to_dict()
                if video_data:  # Check if video_data is not None
                    embedding = video_data.get("embedding")
                    # If a valid embedding somehow exists, correct the status to 'complete' and ignore the fail.
                    if _embedding_vector_is_valid(embedding):
                        logger.warning(
                            f"Correcting status for video {video_id}. It was marked as failed but has a valid embedding."
                        )
                        video_ref.update(
                            {
                                "embedding_status": "complete",
                                "embedding_error": firestore.DELETE_FIELD,
                                "embedding_updated_at": datetime.now(timezone.utc),
                            }
                        )
                        return  # Stop further processing

        update_data = {
            "embedding_status": status,
            "embedding_updated_at": datetime.now(timezone.utc),
        }

        if error:
            update_data["embedding_error"] = error
        else:
            # If status is not failed (e.g., pending, processing, complete), clear any previous error.
            update_data["embedding_error"] = firestore.DELETE_FIELD

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
    db = _firestore().Client()

    # Get all liked video IDs for the user
    liked_videos_ref = (
        db.collection("users").document(user_id).collection("likedVideos")
    )
    liked_video_ids = [doc.id for doc in liked_videos_ref.stream()]

    if not liked_video_ids:
        return {"retried": 0}

    # Find which of the liked videos have a 'failed' status
    videos_ref = db.collection("videos")
    failed_videos_to_retry = []

    # Process in chunks of 30 due to 'in' query limitation
    for i in range(0, len(liked_video_ids), 30):
        chunk_ids = liked_video_ids[i : i + 30]
        query = videos_ref.where(FieldPath.document_id(), "in", chunk_ids).where(
            "embedding_status", "==", "failed"
        )
        docs = query.stream()
        for doc in docs:
            failed_videos_to_retry.append(doc.reference)

    if not failed_videos_to_retry:
        return {"retried": 0}

    # Batch update the status to 'pending'
    batch = db.batch()
    for video_ref in failed_videos_to_retry:
        batch.update(video_ref, {"embedding_status": "pending"})

    batch.commit()

    return {"retried": len(failed_videos_to_retry)}


@https_fn.on_call(timeout_sec=60)
def get_embedding_progress(req: https_fn.CallableRequest) -> dict:
    """
    Calculates and returns the embedding progress for a given user using efficient,
    direct count aggregations on a denormalized status field in the user's
    likedVideos subcollection.
    """
    user_id = req.data.get("user_id")
    if not user_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid 'user_id'.",
        )

    db = _firestore().Client()
    logger.info(f"Starting get_embedding_progress for user_id: {user_id}")
    liked_videos_ref = (
        db.collection("users").document(user_id).collection("likedVideos")
    )

    try:
        # Get total count
        total_query = liked_videos_ref.count()

        # Get completed count
        completed_query = liked_videos_ref.where(
            "embedding_status", "in", ["complete", "not_applicable"]
        ).count()

        # Get failed count
        failed_query = liked_videos_ref.where(
            "embedding_status", "==", "failed"
        ).count()

        # Execute all count queries
        total_result = total_query.get()
        completed_result = completed_query.get()
        failed_result = failed_query.get()

        total = total_result[0][0].value
        completed_count = completed_result[0][0].value
        failed_count = failed_result[0][0].value

        pending_count = total - completed_count - failed_count

        logger.info(
            f"Progress for user {user_id}: Total={total}, Completed={completed_count}, Failed={failed_count}, Pending={pending_count}"
        )

        # Get the last checked timestamp from cache
        cache_doc = db.collection("users").document(user_id).collection("embeddingProgressCache").document("metadata").get()
        last_checked = None
        if cache_doc.exists:
            data = cache_doc.to_dict()
            if data and "lastCheckedAt" in data:
                last_checked = data["lastCheckedAt"]

        return {
            "total": total,
            "completed": completed_count,
            "pending": pending_count if pending_count >= 0 else 0,
            "failed": failed_count,
            "last_updated": last_checked.isoformat() if last_checked else datetime.now(timezone.utc).isoformat(),
        }

    except Exception as e:
        logger.error(f"Error calculating embedding progress for user {user_id}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Failed to calculate embedding progress.",
        )


@on_request(timeout_sec=540)
def backfill_embedding_data(req: Any) -> Any:
    """
    A one-time backfill function to populate denormalized embedding_status
    and the likedByUsers reverse index for all existing users.
    """
    secret = req.args.get("secret")
    if secret != "zensort-backfill-secret-key-2024":
        return ("Unauthorized", 401)

    db = _firestore().Client()
    logger.info("Starting backfill for embedding status and reverse index...")

    try:
        users_ref = db.collection("users")
        all_users = list(users_ref.stream())
        total_users = len(all_users)
        logger.info(f"Found {total_users} users to process.")

        processed_users = 0
        for user in all_users:
            user_id = user.id
            logger.info(
                f"Processing user {user_id} ({processed_users + 1}/{total_users})..."
            )

            liked_videos_ref = users_ref.document(user_id).collection("likedVideos")
            liked_videos = list(liked_videos_ref.stream())

            if not liked_videos:
                logger.info(f"User {user_id} has no liked videos. Skipping.")
                processed_users += 1
                continue

            batch = db.batch()
            video_ids = [doc.id for doc in liked_videos]

            # Fetch all video documents in chunks of 30 (Firestore IN limit)
            video_status_map = {}
            chunk_size = 30
            for i in range(0, len(video_ids), chunk_size):
                chunk_ids = video_ids[i : i + chunk_size]
                video_docs_query = db.collection("videos").where(
                    FieldPath.document_id(), "in", chunk_ids
                )
                video_docs = video_docs_query.stream()
                for doc in video_docs:
                    data = doc.to_dict()
                    if data:
                        video_status_map[doc.id] = data.get(
                            "embedding_status", "pending"
                        )

            for video_id in video_ids:
                status = video_status_map.get(video_id, "pending")

                # Update likedVideos document
                liked_video_doc_ref = liked_videos_ref.document(video_id)
                batch.update(liked_video_doc_ref, {"embedding_status": status})

                # Create reverse index entry
                reverse_index_ref = (
                    db.collection("videos")
                    .document(video_id)
                    .collection("likedByUsers")
                    .document(user_id)
                )
                batch.set(reverse_index_ref, {"syncedAt": datetime.now(timezone.utc)})

            batch.commit()
            logger.info(
                f"Successfully processed {len(liked_videos)} videos for user {user_id}."
            )
            processed_users += 1

        logger.info(f"Backfill completed successfully for {processed_users} users.")
        return (f"Backfill completed for {processed_users} users.", 200)

    except Exception as e:
        logger.error(f"Error during backfill: {type(e).__name__}: {str(e)}")
        return (f"An error occurred during backfill: {e}", 500)
