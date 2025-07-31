import unittest
from unittest.mock import patch, Mock, ANY, call
from firebase_functions import https_fn
from google.oauth2.credentials import Credentials
from datetime import datetime, timezone

# It's crucial to mock these before importing the main module
# to prevent Firebase Admin SDK from trying to initialize.
with patch.dict("sys.modules", {"firebase_admin": Mock()}):
    from main import (
        fetch_liked_video_items,
        fetch_video_details,
        is_private_legacy_video,
        get_existing_video_ids,
        Video,
    )


class TestYouTubeSyncFunctions(unittest.TestCase):
    """
    Test suite for the scalable YouTube sync functions.
    """

    @patch("google.oauth2.credentials.Credentials")
    @patch("main.build")
    def test_fetch_liked_video_items_creates_proper_credentials(
        self, mock_build, mock_credentials_class
    ):
        """
        Tests that fetch_liked_video_items correctly constructs the Credentials object
        and fetches from the correct playlist endpoint with timestamps.
        """
        # Arrange: Set up mocks for credentials and YouTube API client
        mock_credentials_instance = Mock()
        mock_credentials_class.return_value = mock_credentials_instance

        mock_youtube_service = Mock()
        mock_playlist_items = Mock()
        mock_playlist_items.execute.return_value = {
            "items": [
                {
                    "snippet": {
                        "resourceId": {"videoId": "video1"},
                        "publishedAt": "2023-01-01T12:00:00Z",
                        "title": "Test Video 1",
                    }
                },
                {
                    "snippet": {
                        "resourceId": {"videoId": "video2"},
                        "publishedAt": "2023-01-02T12:00:00Z",
                        "title": "Private video",
                    }
                },
            ],
            "nextPageToken": None,
        }
        mock_youtube_service.playlistItems.return_value.list.return_value = (
            mock_playlist_items
        )
        mock_build.return_value = mock_youtube_service

        test_token = "test-access-token-123"

        # Act: Call the function
        result = fetch_liked_video_items(test_token)

        # Assert: Verify that Credentials was created with correct parameters
        mock_credentials_class.assert_called_once_with(
            token=test_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id="unused",
            client_secret="unused",
            scopes=["https://www.googleapis.com/auth/youtube.readonly"],
        )

        # Verify that 'build' was called with the mock credentials
        mock_build.assert_called_once_with(
            "youtube", "v3", credentials=mock_credentials_instance
        )

        # Verify the API call was made with correct parameters (playlist endpoint)
        mock_youtube_service.playlistItems.return_value.list.assert_called_with(
            playlistId="LL",
            part="snippet",
            maxResults=50,
            pageToken=None,
        )

        # Verify result structure includes videoId, likedAt, and title
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["videoId"], "video1")
        self.assertEqual(result[1]["videoId"], "video2")
        self.assertIn("likedAt", result[0])
        self.assertIn("likedAt", result[1])
        self.assertIn("title", result[0])
        self.assertIn("title", result[1])

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

    @patch("google.cloud.firestore.Client")
    def test_get_existing_video_ids(self, mock_firestore_client):
        """
        Tests the function that checks which video IDs already exist in Firestore.
        Tests the new optimized implementation using get_all().
        """
        # Arrange: Mock Firestore client and get_all response
        mock_db = Mock()
        mock_collection = Mock()
        mock_firestore_client.return_value = mock_db
        mock_db.collection.return_value = mock_collection

        # Mock document references and get_all response
        mock_doc_refs = [Mock(), Mock(), Mock()]
        mock_collection.document.side_effect = mock_doc_refs

        # Mock get_all response - simulate finding one existing video
        mock_existing_doc = Mock()
        mock_existing_doc.exists = True
        mock_existing_doc.id = "existing_video_1"

        mock_nonexistent_doc1 = Mock()
        mock_nonexistent_doc1.exists = False
        mock_nonexistent_doc1.id = "new_video_1"

        mock_nonexistent_doc2 = Mock()
        mock_nonexistent_doc2.exists = False
        mock_nonexistent_doc2.id = "new_video_2"

        mock_db.get_all.return_value = [
            mock_existing_doc,
            mock_nonexistent_doc1,
            mock_nonexistent_doc2,
        ]

        video_ids = ["existing_video_1", "new_video_1", "new_video_2"]

        # Act
        result = get_existing_video_ids(video_ids)

        # Assert
        self.assertEqual(result, {"existing_video_1"})
        mock_db.collection.assert_called_with("videos")
        # Verify document references were created for each video ID
        expected_calls = [
            call("existing_video_1"),
            call("new_video_1"),
            call("new_video_2"),
        ]
        mock_collection.document.assert_has_calls(expected_calls, any_order=True)
        # Verify get_all was called with the document references
        mock_db.get_all.assert_called_once_with(mock_doc_refs)

    @patch("google.oauth2.credentials.Credentials")
    @patch("main.build")
    def test_fetch_video_details(self, mock_build, mock_credentials_class):
        """
        Tests that fetch_video_details correctly fetches metadata for specific video IDs.
        """
        # Arrange: Set up mocks for credentials and YouTube API client
        mock_credentials_instance = Mock()
        mock_credentials_class.return_value = mock_credentials_instance

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
