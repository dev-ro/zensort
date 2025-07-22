import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Generator
from firebase_admin import firestore
from firebase_functions import https_fn
import requests
from googleapiclient.discovery import build
import json


@dataclass
class Video:
    videoId: str
    title: str
    description: str
    thumbnailUrl: str
    channelTitle: str
    syncedAt: datetime


def fetch_liked_videos(access_token: str) -> Generator[Video, None, None]:
    """
    Fetch all liked videos for a user from the YouTube Data API, handling pagination.
    Yields Video objects.
    """
    youtube = build(
        "youtube", "v3", developerKey=None, credentials=None, requestBuilder=None
    )
    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = "https://www.googleapis.com/youtube/v3/videos"
    params = {
        "myRating": "like",
        "part": "id,snippet",
        "maxResults": 50,
    }
    next_page_token = None
    while True:
        if next_page_token:
            params["pageToken"] = next_page_token
        else:
            params.pop("pageToken", None)
        response = requests.get(base_url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        for item in data.get("items", []):
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
        next_page_token = data.get("nextPageToken")
        if not next_page_token:
            break


def save_video_to_firestore(video: Video, user_id: str):
    """
    Save a Video object to Firestore in a user-specific 'videos' subcollection,
    using videoId as the document ID.
    """
    db = firestore.client()
    doc_ref = (
        db.collection("users")
        .document(user_id)
        .collection("videos")
        .document(video.videoId)
    )
    doc_ref.set(asdict(video))


@https_fn.on_call(max_instances=10)
def sync_youtube_liked_videos(req: https_fn.CallableRequest) -> dict:
    """
    A callable function to sync a user's liked YouTube videos to their profile.
    """
    # 1. Check for authenticated user
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="The function must be called by an authenticated user.",
        )
    user_id = req.auth.uid

    # 2. Get access token from request data
    access_token = req.data.get("accessToken")
    if not isinstance(access_token, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a valid 'accessToken'.",
        )

    try:
        # 3. Fetch liked videos and save them to Firestore
        count = 0
        for video in fetch_liked_videos(access_token):
            save_video_to_firestore(video, user_id)
            count += 1

        # 4. Return success response
        return {"synced": count}

    except requests.exceptions.HTTPError as e:
        # Log the detailed error from the YouTube API
        error_content = json.loads(e.response.content.decode("utf-8"))
        status_code = e.response.status_code
        error_details = error_content.get("error", {})
        error_reason = error_details.get("errors", [{}])[0].get("reason")

        print(
            f"YouTube API Error - Status: {status_code}, Reason: {error_reason}, Details: {json.dumps(error_details)}"
        )

        # Improve the error message returned to the client
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"YouTube API Error {status_code}: {error_reason}",
            details=error_details,
        )
    except Exception as e:
        print(f"Error syncing liked videos: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred while syncing videos.",
        )
