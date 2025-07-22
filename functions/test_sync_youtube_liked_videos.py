import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timezone
from flask import Flask

from firebase_functions import https_fn
from googleapiclient.errors import HttpError


class TestYouTubeSyncFunctions(unittest.TestCase):
    """Test suite for YouTube sync Cloud Functions."""

    def setUp(self):
        """Set up test app context."""
        self.app = Flask(__name__)
        self.app_context = self.app.app_context()
        self.app_context.push()

    def tearDown(self):
        """Clean up app context."""
        self.app_context.pop()

    @patch("main.firestore")
    @patch("main.Credentials")
    @patch("main.build")
    def test_get_liked_videos_total_success(
        self, mock_build, mock_credentials, mock_firestore
    ):
        """Test successful retrieval of liked videos count."""
        # Import after patching
        from main import get_liked_videos_total

        # Mock the YouTube API response
        mock_youtube = Mock()
        mock_request = Mock()
        mock_request.execute.return_value = {"pageInfo": {"totalResults": 42}}
        mock_youtube.videos.return_value.list.return_value = mock_request
        mock_build.return_value = mock_youtube

        # Mock credentials
        mock_credentials.return_value = Mock()

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function
        result = get_liked_videos_total(mock_req)

        # Verify the results
        self.assertEqual(result, {"total": 42})
        mock_build.assert_called_once_with(
            "youtube", "v3", credentials=mock_credentials.return_value
        )

    @patch("main.firestore")
    @patch("main.Credentials")
    @patch("main.build")
    def test_get_liked_videos_total_401_error(
        self, mock_build, mock_credentials, mock_firestore
    ):
        """Test handling of 401 Unauthorized error from YouTube API."""
        from main import get_liked_videos_total

        # Create a mock 401 error
        mock_response = Mock()
        mock_response.status = 401
        mock_error = HttpError(resp=mock_response, content=b"Unauthorized")

        # Mock the YouTube API to raise the error
        mock_youtube = Mock()
        mock_request = Mock()
        mock_request.execute.side_effect = mock_error
        mock_youtube.videos.return_value.list.return_value = mock_request
        mock_build.return_value = mock_youtube

        # Mock credentials
        mock_credentials.return_value = Mock()

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function and verify it raises the correct error
        with self.assertRaises(https_fn.HttpsError) as context:
            get_liked_videos_total(mock_req)

        self.assertEqual(
            context.exception.code, https_fn.FunctionsErrorCode.UNAUTHENTICATED
        )
        self.assertEqual(
            context.exception.message, "Invalid or expired YouTube access token."
        )

    @patch("main.firestore")
    @patch("main.Credentials")
    @patch("main.build")
    def test_get_liked_videos_total_other_api_error(
        self, mock_build, mock_credentials, mock_firestore
    ):
        """Test handling of other API errors from YouTube."""
        from main import get_liked_videos_total

        # Create a mock 403 error
        mock_response = Mock()
        mock_response.status = 403
        mock_error = HttpError(resp=mock_response, content=b"Forbidden")

        # Mock the YouTube API to raise the error
        mock_youtube = Mock()
        mock_request = Mock()
        mock_request.execute.side_effect = mock_error
        mock_youtube.videos.return_value.list.return_value = mock_request
        mock_build.return_value = mock_youtube

        # Mock credentials
        mock_credentials.return_value = Mock()

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function and verify it raises the correct error
        with self.assertRaises(https_fn.HttpsError) as context:
            get_liked_videos_total(mock_req)

        self.assertEqual(context.exception.code, https_fn.FunctionsErrorCode.INTERNAL)
        self.assertIn("YouTube API error", context.exception.message)

    @patch("main.firestore")
    def test_get_liked_videos_total_missing_access_token(self, mock_firestore):
        """Test error when access token is missing."""
        from main import get_liked_videos_total

        # Create mock request without access token
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {}

        # Call the function and verify it raises the correct error
        with self.assertRaises(https_fn.HttpsError) as context:
            get_liked_videos_total(mock_req)

        self.assertEqual(
            context.exception.code, https_fn.FunctionsErrorCode.INVALID_ARGUMENT
        )
        self.assertEqual(
            context.exception.message,
            "The function must be called with an access_token.",
        )

    @patch("main.firestore")
    @patch("main.Credentials")
    @patch("main.build")
    def test_fetch_liked_videos_success_with_pagination(
        self, mock_build, mock_credentials, mock_firestore
    ):
        """Test successful fetching of liked videos with pagination."""
        from main import fetch_liked_videos

        # Mock YouTube API responses
        mock_youtube = Mock()

        # First page response
        first_page_response = {
            "items": [
                {
                    "id": "video1",
                    "snippet": {
                        "title": "Test Video 1",
                        "description": "Description 1",
                        "thumbnails": {"default": {"url": "http://thumb1.jpg"}},
                        "channelTitle": "Channel 1",
                    },
                }
            ],
            "nextPageToken": "page2",
        }

        # Second page response (last page)
        second_page_response = {
            "items": [
                {
                    "id": "video2",
                    "snippet": {
                        "title": "Test Video 2",
                        "description": "Description 2",
                        "thumbnails": {"default": {"url": "http://thumb2.jpg"}},
                        "channelTitle": "Channel 2",
                    },
                }
            ]
        }

        # Set up mock to return different responses
        mock_request_1 = Mock()
        mock_request_1.execute.return_value = first_page_response
        mock_request_2 = Mock()
        mock_request_2.execute.return_value = second_page_response

        # Use side_effect to return different mock requests for each call
        mock_youtube.videos.return_value.list.side_effect = [
            mock_request_1,
            mock_request_2,
        ]
        mock_build.return_value = mock_youtube

        # Mock credentials
        mock_credentials.return_value = Mock()

        # Fetch videos
        videos = list(fetch_liked_videos("test_token"))

        # Verify results
        self.assertEqual(len(videos), 2)
        self.assertEqual(videos[0].videoId, "video1")
        self.assertEqual(videos[0].title, "Test Video 1")
        self.assertEqual(videos[1].videoId, "video2")
        self.assertEqual(videos[1].title, "Test Video 2")

    @patch("main.firestore")
    @patch("main.Credentials")
    @patch("main.build")
    def test_fetch_liked_videos_401_error(
        self, mock_build, mock_credentials, mock_firestore
    ):
        """Test fetch_liked_videos handles 401 error correctly."""
        from main import fetch_liked_videos

        # Create a mock 401 error
        mock_response = Mock()
        mock_response.status = 401
        mock_error = HttpError(resp=mock_response, content=b"Unauthorized")

        # Mock the YouTube API to raise the error
        mock_youtube = Mock()
        mock_request = Mock()
        mock_request.execute.side_effect = mock_error
        mock_youtube.videos.return_value.list.return_value = mock_request
        mock_build.return_value = mock_youtube

        # Mock credentials
        mock_credentials.return_value = Mock()

        # Call the generator and verify it raises the correct error
        with self.assertRaises(https_fn.HttpsError) as context:
            list(fetch_liked_videos("test_token"))

        self.assertEqual(
            context.exception.code, https_fn.FunctionsErrorCode.UNAUTHENTICATED
        )
        self.assertEqual(
            context.exception.message, "Invalid or expired YouTube access token."
        )

    @patch("main.firestore")
    @patch("main.save_video_to_firestore")
    @patch("main.fetch_liked_videos")
    def test_sync_youtube_liked_videos_success(
        self, mock_fetch, mock_save, mock_firestore
    ):
        """Test successful sync of YouTube liked videos."""
        from main import sync_youtube_liked_videos, Video

        # Mock fetch_liked_videos to return test videos
        test_videos = [
            Video(
                videoId="video1",
                title="Test Video 1",
                description="Description 1",
                thumbnailUrl="http://thumb1.jpg",
                channelTitle="Channel 1",
                syncedAt=datetime.now(timezone.utc),
            ),
            Video(
                videoId="video2",
                title="Test Video 2",
                description="Description 2",
                thumbnailUrl="http://thumb2.jpg",
                channelTitle="Channel 2",
                syncedAt=datetime.now(timezone.utc),
            ),
        ]
        mock_fetch.return_value = iter(test_videos)

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function
        result = sync_youtube_liked_videos(mock_req)

        # Verify results
        self.assertEqual(result, {"synced": 2})
        mock_fetch.assert_called_once_with("test_token")
        self.assertEqual(mock_save.call_count, 2)

    @patch("main.firestore")
    def test_sync_youtube_liked_videos_missing_access_token(self, mock_firestore):
        """Test sync function with missing access token."""
        from main import sync_youtube_liked_videos

        # Create mock request without access token
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {}

        # Call the function and verify it raises the correct error
        with self.assertRaises(https_fn.HttpsError) as context:
            sync_youtube_liked_videos(mock_req)

        self.assertEqual(
            context.exception.code, https_fn.FunctionsErrorCode.INVALID_ARGUMENT
        )
        self.assertEqual(
            context.exception.message,
            "The function must be called with an access_token.",
        )

    @patch("main.firestore")
    @patch("main.save_video_to_firestore")
    @patch("main.fetch_liked_videos")
    def test_sync_youtube_liked_videos_fetch_error(
        self, mock_fetch, mock_save, mock_firestore
    ):
        """Test sync function handles errors from fetch_liked_videos."""
        from main import sync_youtube_liked_videos

        # Mock fetch to raise an HttpsError
        mock_fetch.side_effect = https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Invalid or expired YouTube access token.",
        )

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function and verify it re-raises the error
        with self.assertRaises(https_fn.HttpsError) as context:
            sync_youtube_liked_videos(mock_req)

        self.assertEqual(
            context.exception.code, https_fn.FunctionsErrorCode.UNAUTHENTICATED
        )
        self.assertEqual(
            context.exception.message, "Invalid or expired YouTube access token."
        )
        mock_save.assert_not_called()

    @patch("main.firestore")
    @patch("main.save_video_to_firestore")
    @patch("main.fetch_liked_videos")
    def test_sync_youtube_liked_videos_save_error(
        self, mock_fetch, mock_save, mock_firestore
    ):
        """Test sync function handles errors during save."""
        from main import sync_youtube_liked_videos, Video

        # Mock fetch to return one video
        test_video = Video(
            videoId="video1",
            title="Test Video 1",
            description="Description 1",
            thumbnailUrl="http://thumb1.jpg",
            channelTitle="Channel 1",
            syncedAt=datetime.now(timezone.utc),
        )
        mock_fetch.return_value = iter([test_video])

        # Mock save to raise an exception
        mock_save.side_effect = Exception("Firestore error")

        # Create mock request
        mock_req = Mock(spec=https_fn.CallableRequest)
        mock_req.data = {"access_token": "test_token"}

        # Call the function and verify it handles the error
        with self.assertRaises(https_fn.HttpsError) as context:
            sync_youtube_liked_videos(mock_req)

        self.assertEqual(context.exception.code, https_fn.FunctionsErrorCode.INTERNAL)
        self.assertIn("unexpected error", context.exception.message)


if __name__ == "__main__":
    unittest.main()
