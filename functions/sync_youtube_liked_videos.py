import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Generator, Optional, Tuple
from firebase_admin import firestore
from firebase_functions import https_fn
import requests
import json


@dataclass
class Video:
    videoId: str
    title: str
    description: str
    thumbnailUrl: str
    channelTitle: str
    syncedAt: datetime
    privacyStatus: str


def get_total_liked_videos_count(access_token: str) -> int:
    """Gets the total number of liked videos from the YouTube API."""
    headers = {"Authorization": f"Bearer {access_token}"}
    url = "https://www.googleapis.com/youtube/v3/videos"
    params = {"myRating": "like", "part": "id", "maxResults": 1}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json().get("pageInfo", {}).get("totalResults", 0)


def fetch_liked_videos_page(
    access_token: str, page_token: Optional[str] = None
) -> Tuple[list[Video], Optional[str]]:
    """Fetches a single page of liked videos."""
    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = "https://www.googleapis.com/youtube/v3/playlistItems"
    params = {
        "part": "snippet,status",
        "maxResults": 50,
        "playlistId": "LL",
    }
    if page_token:
        params["pageToken"] = page_token

    response = requests.get(base_url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    videos = []
    for item in data.get("items", []):
        snippet = item.get("snippet", {})
        status = item.get("status", {})
        # The video ID for a playlistItem is in a different location
        video_id = snippet.get("resourceId", {}).get("videoId")
        if not video_id:
            continue

        videos.append(
            Video(
                videoId=video_id,
                title=snippet.get("title", ""),
                description=snippet.get("description", ""),
                thumbnailUrl=snippet.get("thumbnails", {})
                .get("default", {})
                .get("url", ""),
                channelTitle=snippet.get("channelTitle", ""),
                syncedAt=datetime.now(timezone.utc),
                privacyStatus=status.get("privacyStatus", "unknown"),
            )
        )
    return videos, data.get("nextPageToken")


@https_fn.on_call(max_instances=10)
def sync_youtube_liked_videos(req: https_fn.CallableRequest) -> dict:
    if req.auth is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            "The function must be called by an authenticated user.",
        )
    user_id = req.auth.uid

    db = firestore.client()
    sync_job_ref = (
        db.collection("users")
        .document(user_id)
        .collection("syncJobs")
        .document("youtube_liked_videos")
    )

    try:
        access_token = req.data.get("accessToken")
        if not access_token or not isinstance(access_token, str):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message='The function must be called with a valid "accessToken" in the request data.',
            )

        total_videos = get_total_liked_videos_count(access_token)
        sync_job_ref.set(
            {"totalCount": total_videos, "syncedCount": 0, "status": "in_progress"}
        )

        synced_count = 0
        next_page_token = None
        while True:
            videos, next_page_token = fetch_liked_videos_page(
                access_token, next_page_token
            )
            for video in videos:
                video_data = asdict(video)
                public_video_ref = db.collection("videos").document(video.videoId)
                user_video_ref = (
                    db.collection("users")
                    .document(user_id)
                    .collection("userVideos")
                    .document(video.videoId)
                )
                link_ref = (
                    db.collection("users")
                    .document(user_id)
                    .collection("likedVideoLinks")
                    .document(video.videoId)
                )

                if video.privacyStatus == "public":
                    doc = public_video_ref.get()
                    if not doc.exists:
                        public_video_ref.set(video_data)
                else:
                    user_video_ref.set(video_data)

                link_ref.set(
                    {"videoId": video.videoId, "linkedAt": datetime.now(timezone.utc)}
                )
                synced_count += 1

            sync_job_ref.update({"syncedCount": synced_count})
            if not next_page_token:
                break

        sync_job_ref.update({"status": "completed"})
        return {"synced": synced_count}

    except requests.exceptions.HTTPError as e:
        error_content = json.loads(e.response.content.decode("utf-8"))
        error_details = error_content.get("error", {})
        sync_job_ref.set({"status": "failed", "error": error_details})
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"YouTube API Error: {e.response.reason}",
            details=error_details,
        )
    except Exception as e:
        sync_job_ref.set({"status": "failed", "error": str(e)})
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An unexpected error occurred.",
        )
