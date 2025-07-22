from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Generator
from firebase_admin import firestore
from firebase_functions import https_fn
import requests
from googleapiclient.discovery import build


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

    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = "https://www.googleapis.com/youtube/v3/videos"
    params = {
        "myRating": "like",
        "part": "id",
        "maxResults": 1,
    }

    response = requests.get(base_url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    return {"total": data["pageInfo"]["totalResults"]}


def fetch_liked_videos(access_token: str) -> Generator[Video, None, None]:
    """
    Fetch all liked videos for a user from the YouTube Data API, handling pagination.
    Yields Video objects.
    """
    # This function is a generator and not directly called by the client, so it doesn't need the on_call decorator.
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
    Expects OAuth2 access token in the Authorization header.
    Returns a dict with the number of videos synced.
    """
    access_token = req.data.get("access_token")
    if not access_token:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with an access_token.",
        )

    count = 0
    for video in fetch_liked_videos(access_token):
        save_video_to_firestore(video)
        count += 1
    return {"synced": count}