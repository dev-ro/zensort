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
    Fetch total number of liked videos for a user from the YouTube Data API.
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

        # Request liked videos with minimal data to get total count
        request = youtube.videos().list(myRating="like", part="id", maxResults=1)
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


def fetch_liked_video_ids(access_token: str) -> list[str]:
    """
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
    Returns a list of Video objects with full metadata.
    """
    if not video_ids:
        return []

    try:
        logger.info(f"Fetching details for {len(video_ids)} videos")

        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        youtube = build("youtube", "v3", credentials=credentials)

        videos = []

        # Process in batches of 50 (API limit)
        for i in range(0, len(video_ids), 50):
            batch_ids = video_ids[i : i + 50]
            logger.info(f"Processing batch {i//50 + 1}: {len(batch_ids)} videos")

            request = youtube.videos().list(part="id,snippet", id=",".join(batch_ids))

            response = request.execute()

            for item in response.get("items", []):
                snippet = item.get("snippet", {})
                videos.append(
                    Video(
                        videoId=item["id"],
                        title=snippet.get("title", ""),
                        description=snippet.get("description", ""),
                        thumbnailUrl=snippet.get("thumbnails", {})
                        .get("default", {})
                        .get("url", ""),
                        channelTitle=snippet.get("channelTitle", ""),
                        publishedAt=datetime.fromisoformat(
                            snippet.get("publishedAt", "").replace("Z", "+00:00")
                        ),
                        platform="YouTube",
                        addedToZensortAt=datetime.now(timezone.utc),
                    )
                )

        logger.info(f"Successfully fetched details for {len(videos)} videos")
        return videos

    except Exception as e:
        logger.error(f"Error fetching video details: {type(e).__name__}: {str(e)}")
        raise


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
    Uses a new data model that separates public video data from user-specific data.

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

    try:
        logger.info(f"Starting sync for user {user_id}")

        # Step 1: Fetch all liked video IDs
        all_video_ids = fetch_liked_video_ids(access_token)
        logger.info(f"Found {len(all_video_ids)} total liked videos")

        if not all_video_ids:
            return {"synced": 0, "public_videos": 0, "private_legacy_videos": 0}

        # Step 2: Check which videos already exist in the public collection
        existing_video_ids = get_existing_video_ids(all_video_ids)

        # Step 3: Identify new videos that need metadata fetching
        new_video_ids = [
            vid_id for vid_id in all_video_ids if vid_id not in existing_video_ids
        ]
        logger.info(f"Need to fetch metadata for {len(new_video_ids)} new videos")

        # Step 4: Fetch details for new videos only
        new_videos = []
        if new_video_ids:
            new_videos = fetch_video_details(access_token, new_video_ids)

        # Step 5: Categorize videos and prepare for batch write
        db = firestore.client()
        batch = db.batch()

        public_video_count = 0
        private_legacy_video_count = 0
        sync_timestamp = datetime.now(timezone.utc)

        # Add new public videos to the root collection
        for video in new_videos:
            if not is_private_legacy_video(video.title):
                # This is a public video - add to root collection
                video_doc_ref = db.collection("videos").document(video.videoId)
                batch.set(
                    video_doc_ref,
                    {
                        "platform": video.platform,
                        "videoId": video.videoId,
                        "title": video.title,
                        "description": video.description,
                        "channelTitle": video.channelTitle,
                        "thumbnailUrl": video.thumbnailUrl,
                        "publishedAt": video.publishedAt,
                        "addedToZensortAt": video.addedToZensortAt,
                    },
                )
                public_video_count += 1

        # Add ALL videos (public + private/legacy) to user's liked videos subcollection
        for video_id in all_video_ids:
            # For existing videos, we don't have the likedAt timestamp,
            # so we'll use the sync timestamp as a fallback
            liked_video_doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("likedVideos")
                .document(video_id)
            )
            batch.set(
                liked_video_doc_ref,
                {
                    "likedAt": sync_timestamp,  # This could be enhanced to get actual like timestamp
                    "syncedAt": sync_timestamp,
                },
            )

            # Count private/legacy videos
            for video in new_videos:
                if video.videoId == video_id and is_private_legacy_video(video.title):
                    private_legacy_video_count += 1

        # Step 6: Execute atomic batch write
        logger.info(
            f"Executing batch write: {public_video_count} public videos, {len(all_video_ids)} user relations"
        )
        batch.commit()

        logger.info(f"Sync completed successfully for user {user_id}")

        return {
            "synced": len(all_video_ids),
            "public_videos": public_video_count,
            "private_legacy_videos": private_legacy_video_count,
            "total_liked_videos": len(all_video_ids),
        }

    except Exception as e:
        logger.error(
            f"Error during video sync for user {user_id}: {type(e).__name__}: {str(e)}"
        )
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred while syncing videos.",
        )
