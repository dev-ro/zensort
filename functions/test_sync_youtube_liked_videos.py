import unittest
from unittest.mock import patch, Mock, ANY
from firebase_functions import https_fn
from google.oauth2.credentials import Credentials
from datetime import datetime, timezone

# It's crucial to mock these before importing the main module
# to prevent Firebase Admin SDK from trying to initialize.
with patch.dict("sys.modules", {"firebase_admin": Mock()}):
    from main import (
        fetch_liked_video_ids,
        fetch_video_details,
        is_private_legacy_video,
        get_existing_video_ids,
        Video,
    )


class TestYouTubeSyncFunctions(unittest.TestCase):
    """
    Test suite for the scalable YouTube sync functions.
    """

    @patch("main.build")
    def test_fetch_liked_video_ids_creates_proper_credentials(self, mock_build):
        """
        Tests that fetch_liked_video_ids correctly constructs the Credentials object
        and only fetches video IDs (no metadata).
        """
        # Arrange: Set up a mock for the YouTube API client
        mock_youtube_service = Mock()
        mock_videos_list = Mock()
        mock_videos_list.execute.return_value = {
            "items": [{"id": "video1"}, {"id": "video2"}],
            "nextPageToken": None,
        }
        mock_youtube_service.videos.return_value.list.return_value = mock_videos_list
        mock_build.return_value = mock_youtube_service

        test_token = "test-access-token-123"

        # Act: Call the function
        result = fetch_liked_video_ids(test_token)

        # Assert: Verify that 'build' was called with a Credentials object
        mock_build.assert_called_once()
        args, kwargs = mock_build.call_args
        actual_credentials = kwargs.get("credentials")

        self.assertIsNotNone(actual_credentials)
        self.assertIsInstance(actual_credentials, Credentials)
        self.assertEqual(actual_credentials.token, test_token)
        self.assertEqual(
            actual_credentials.token_uri, "https://oauth2.googleapis.com/token"
        )

        # Verify the API call was made with correct parameters (only 'id' part)
        mock_youtube_service.videos.return_value.list.assert_called_with(
            myRating="like",
            part="id",
            maxResults=50,
            pageToken=None,
        )

        # Verify result
        self.assertEqual(result, ["video1", "video2"])

    def test_is_private_legacy_video(self):
        """
        Tests the video categorization logic for private/legacy videos.
        """
        # Test private/legacy video titles
        self.assertTrue(is_private_legacy_video("Private video"))
        self.assertTrue(is_private_legacy_video("Deleted video"))
        self.assertTrue(is_private_legacy_video("Music Library Uploads"))

        # Test public video titles
        self.assertFalse(is_private_legacy_video("My Awesome Video"))
        self.assertFalse(is_private_legacy_video("Tutorial: How to Code"))
        self.assertFalse(is_private_legacy_video(""))
        self.assertFalse(is_private_legacy_video("Private Video"))  # Case sensitive
        self.assertFalse(is_private_legacy_video("private video"))  # Case sensitive

    @patch("main.firestore")
    def test_get_existing_video_ids(self, mock_firestore):
        """
        Tests the function that checks which video IDs already exist in Firestore.
        """
        # Arrange: Mock Firestore client and query response
        mock_db = Mock()
        mock_collection = Mock()
        mock_firestore.client.return_value = mock_db
        mock_db.collection.return_value = mock_collection

        # Mock query response - simulate finding one existing video
        mock_doc = Mock()
        mock_doc.get.return_value = "existing_video_1"
        mock_collection.where.return_value.get.return_value = [mock_doc]

        video_ids = ["existing_video_1", "new_video_1", "new_video_2"]

        # Act
        result = get_existing_video_ids(video_ids)

        # Assert
        self.assertEqual(result, {"existing_video_1"})
        mock_db.collection.assert_called_with("videos")
        mock_collection.where.assert_called()

    @patch("main.build")
    def test_fetch_video_details(self, mock_build):
        """
        Tests that fetch_video_details correctly fetches metadata for specific video IDs.
        """
        # Arrange: Mock YouTube API response with video details
        mock_youtube_service = Mock()
        mock_videos_list = Mock()
        mock_videos_list.execute.return_value = {
            "items": [
                {
                    "id": "video1",
                    "snippet": {
                        "title": "Test Video 1",
                        "description": "Test description",
                        "channelTitle": "Test Channel",
                        "publishedAt": "2023-01-01T00:00:00Z",
                        "thumbnails": {
                            "default": {"url": "http://example.com/thumb.jpg"}
                        },
                    },
                }
            ]
        }
        mock_youtube_service.videos.return_value.list.return_value = mock_videos_list
        mock_build.return_value = mock_youtube_service

        test_token = "test-token"
        video_ids = ["video1"]

        # Act
        with patch("main.datetime") as mock_datetime:
            mock_datetime.now.return_value = datetime(
                2023, 1, 1, 0, 0, 0, tzinfo=timezone.utc
            )
            mock_datetime.fromisoformat = datetime.fromisoformat
            result = fetch_video_details(test_token, video_ids)

        # Assert
        self.assertEqual(len(result), 1)
        video = result[0]
        self.assertIsInstance(video, Video)
        self.assertEqual(video.videoId, "video1")
        self.assertEqual(video.title, "Test Video 1")
        self.assertEqual(video.platform, "YouTube")

        # Verify API call used the correct parameters
        mock_youtube_service.videos.return_value.list.assert_called_with(
            part="id,snippet", id="video1"
        )


if __name__ == "__main__":
    unittest.main()
