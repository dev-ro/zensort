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
        credentials = Credentials(token=access_token)

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
        # Create OAuth2 credentials from the access token
        credentials = Credentials(token=access_token)

        # Build the YouTube service
        youtube = build("youtube", "v3", credentials=credentials)

        # Initialize pagination
        next_page_token = None

        while True:
            # Build the request
            request = youtube.videos().list(
                myRating="like",
                part="id,snippet",
                maxResults=50,
                pageToken=next_page_token,
            )

            # Execute the request
            response = request.execute()

            # Process each video
            for item in response.get("items", []):
                snippet = item.get("snippet", {})
                yield Video(
                    videoId=item["id"],
                    title=snippet.get("title", ""),
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
                break

    except HttpError as e:
        if e.resp.status == 401:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Invalid or expired YouTube access token.",
            )
        else:
            print(f"YouTube API error in fetch_liked_videos: {e}")
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f"YouTube API error: {str(e)}",
            )
    except Exception as e:
        print(f"Unexpected error in fetch_liked_videos: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred while fetching videos.",
        )


def save_video_to_firestore(video: Video):
    """
    Save a Video object to Firestore in the 'videos' collection, using videoId as the document ID.
    """
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


@https_fn.on_call()
def sync_youtube_liked_videos(req: https_fn.CallableRequest) -> dict:
    """
    HTTP Cloud Function to sync a user's liked YouTube videos to Firestore.
    Expects OAuth2 access token in the request data.
    Returns a dict with the number of videos synced.
    """
    access_token = req.data.get("access_token")
    if not access_token:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with an access_token.",
        )

    try:
        count = 0
        for video in fetch_liked_videos(access_token):
            save_video_to_firestore(video)
            count += 1
        return {"synced": count}

    except https_fn.HttpsError:
        # Re-raise HttpsError from fetch_liked_videos
        raise
    except Exception as e:
        print(f"Unexpected error in sync_youtube_liked_videos: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred during video sync.",
        )
