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