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


def fetch_liked_videos(access_token: str) -> Generator[Video, None, None]:
    """
    Fetch all liked videos for a user from the YouTube Data API, handling pagination.
    Yields Video objects.
    """
    try:
        logger.info("=== Starting fetch_liked_videos ===")
        logger.info(f"Token type: {type(access_token)}")

        # Create OAuth2 credentials from the access token
        logger.info("Creating OAuth2 credentials from access token")

        # FIXED: Create proper OAuth2 credentials with all required fields
        credentials = Credentials(
            token=access_token,
            token_uri="https://oauth2.googleapis.com/token",  # Google's token endpoint
            client_id="unused",  # Required but not used for existing tokens
            client_secret="unused",  # Required but not used for existing tokens
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        logger.info(f"Credentials created: {credentials is not None}")
        # Be careful with token logging to handle both real and mock objects
        if hasattr(credentials, "token") and credentials.token:
            token_preview = (
                str(credentials.token)[:20]
                if len(str(credentials.token)) > 20
                else str(credentials.token)
            )
            logger.info(f"Credentials token preview: {token_preview}...")
        else:
            logger.info("Credentials token: Not available")

        # Build the YouTube service
        logger.info("Building YouTube service client")
        try:
            youtube = build("youtube", "v3", credentials=credentials)
            logger.info("YouTube service built successfully")
        except Exception as e:
            logger.error(
                f"Failed to build YouTube service: {type(e).__name__}: {str(e)}"
            )
            if "invalid_grant" in str(e).lower():
                logger.error("Token appears to be expired or invalid")
                raise https_fn.HttpsError(
                    code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                    message="OAuth token is expired or invalid. Please sign in again.",
                )
            raise

        # Initialize pagination
        next_page_token = None
        page_count = 0
        total_videos = 0

        while True:
            page_count += 1
            logger.info(f"Fetching page {page_count} of liked videos")

            # Build the request
            try:
                logger.info(f"Creating API request - pageToken: {next_page_token}")
                request = youtube.videos().list(
                    myRating="like",
                    part="id,snippet",
                    maxResults=50,
                    pageToken=next_page_token,
                )
                logger.info("API request created successfully")
            except Exception as e:
                logger.error(
                    f"Failed to create API request: {type(e).__name__}: {str(e)}"
                )
                raise

            # Execute the request
            try:
                logger.info("Executing YouTube API request...")
                response = request.execute()
                logger.info("API request executed successfully")
            except Exception as e:
                logger.error(
                    f"API request execution failed: {type(e).__name__}: {str(e)}"
                )
                if hasattr(e, "resp") and hasattr(e.resp, "status"):
                    logger.error(f"HTTP status code: {e.resp.status}")
                if hasattr(e, "content"):
                    logger.error(f"Error content: {e.content}")
                raise

            items_count = len(response.get("items", []))
            logger.info(f"Page {page_count}: Received {items_count} videos")
            total_videos += items_count

            # Process each video
            for idx, item in enumerate(response.get("items", [])):
                snippet = item.get("snippet", {})
                video_id = item.get("id", "unknown")
                video_title = snippet.get("title", "")
                logger.debug(
                    f"Processing video {idx + 1}/{items_count}: {video_id} - {video_title[:30]}..."
                )

                yield Video(
                    videoId=video_id,
                    title=video_title,
                    description=snippet.get("description", ""),
                    thumbnailUrl=snippet.get("thumbnails", {})
                    .get("default", {})
                    .get("url", ""),
                    channelTitle=snippet.get("channelTitle", ""),
                    syncedAt=datetime.now(timezone.utc),
                )

            # Check for next page
            next_page_token = response.get("nextPageToken")
            if not next_page_token:
                logger.info(f"No more pages. Total videos fetched: {total_videos}")
                break
            else:
                logger.info(f"Next page token found: {next_page_token[:10]}...")

    except HttpError as e:
        logger.error(f"YouTube API HttpError caught")
        logger.error(f"Status: {e.resp.status if hasattr(e, 'resp') else 'unknown'}")

        if hasattr(e, "content"):
            try:
                error_content = json.loads(e.content)
                logger.error(f"Error details: {json.dumps(error_content, indent=2)}")
            except:
                logger.error(f"Raw error content: {e.content}")

        if e.resp.status == 401:
            logger.error("401 Unauthorized - Token is invalid or expired")
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Invalid or expired YouTube access token.",
            )
        elif e.resp.status == 403:
            # Could be quota exceeded or API not enabled
            error_content = json.loads(e.content) if e.content else {}
            error_info = error_content.get("error", {})
            errors = error_info.get("errors", [])
            error_reason = errors[0].get("reason", "unknown") if errors else "unknown"
            error_message = error_info.get("message", "Permission denied")

            logger.error(f"403 Forbidden - Reason: {error_reason}")
            logger.error(f"Error message: {error_message}")

            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message=f"YouTube API access denied: {error_reason} - {error_message}",
            )
        else:
            logger.error(f"Unexpected HTTP error: {e.resp.status}")
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f"YouTube API error: HTTP {e.resp.status}",
            )
    except Exception as e:
        logger.error(
            f"Unexpected error in fetch_liked_videos: {type(e).__name__}: {str(e)}"
        )
        logger.exception("Full traceback:")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Failed to fetch videos: {type(e).__name__}: {str(e)}",
        )


def save_video_to_firestore(video: Video):
    """
    Save a Video object to Firestore in the 'videos' collection, using videoId as the document ID.
    """
    try:
        logger.debug(f"Saving video {video.videoId} to Firestore")
        db = firestore.client()
        doc_ref = db.collection("videos").document(video.videoId)
        doc_ref.set(
            {
                "videoId": video.videoId,
                "title": video.title,
                "description": video.description,
                "thumbnailUrl": video.thumbnailUrl,
                "channelTitle": video.channelTitle,
                "syncedAt": video.syncedAt,
            }
        )
        logger.debug(f"Successfully saved video {video.videoId}")
    except Exception as e:
        logger.error(
            f"Failed to save video {video.videoId} to Firestore: {type(e).__name__}: {str(e)}"
        )
        raise


@https_fn.on_call()
def sync_youtube_liked_videos(req: https_fn.CallableRequest) -> dict:
    """
    HTTP Cloud Function to sync a user's liked YouTube videos to Firestore.
    Expects OAuth2 access token in the request data.
    Returns a dict with the number of videos synced.
    """
    logger.info("=== Starting sync_youtube_liked_videos ===")

    # Log request data (be careful not to log sensitive tokens in production)
    logger.info(f"Request auth present: {req.auth is not None}")
    if req.auth:
        logger.info(f"Request auth uid: {req.auth.get('uid', 'N/A')}")
    logger.info(f"Request data keys: {list(req.data.keys())}")

    access_token = req.data.get("access_token")
    if not access_token:
        logger.error("No access_token provided in request")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with an access_token.",
        )

    # Log token info (first few chars only for security)
    logger.info(f"Access token received (first 20 chars): {access_token[:20]}...")
    logger.info(f"Access token length: {len(access_token)}")

    try:
        logger.info("Starting video fetch process")
        count = 0

        # Add more detailed logging in fetch_liked_videos
        for video in fetch_liked_videos(access_token):
            logger.info(
                f"Processing video {count + 1}: {video.videoId} - {video.title[:50]}..."
            )
            save_video_to_firestore(video)
            count += 1

            # Log progress every 10 videos
            if count % 10 == 0:
                logger.info(f"Progress: Synced {count} videos so far")

        logger.info(f"=== Sync complete: {count} videos synced successfully ===")
        return {"synced": count}

    except https_fn.HttpsError as e:
        logger.error(f"HttpsError in sync: {e.code} - {e.message}")
        raise
    except Exception as e:
        logger.error(
            f"Unexpected error in sync_youtube_liked_videos: {type(e).__name__}: {str(e)}"
        )
        logger.exception("Full traceback:")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Video sync failed: {type(e).__name__}: {str(e)}",
        )
