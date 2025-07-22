import unittest
from unittest.mock import patch, Mock, ANY
from firebase_functions import https_fn
from google.oauth2.credentials import Credentials

# It's crucial to mock these before importing the main module
# to prevent Firebase Admin SDK from trying to initialize.
with patch.dict("sys.modules", {"firebase_admin": Mock()}):
    from main import fetch_liked_videos, Video


class TestYouTubeSyncFunctions(unittest.TestCase):
    """
    A clean test suite focusing on verifying the core logic and fixes.
    """

    @patch("main.build")
    def test_fetch_liked_videos_creates_proper_credentials(self, mock_build):
        """
        Tests that fetch_liked_videos correctly constructs the Credentials object
        before passing it to the googleapiclient.
        """
        # Arrange: Set up a mock for the YouTube API client
        mock_youtube_service = Mock()
        mock_videos_list = Mock()
        mock_videos_list.execute.return_value = {
            "items": []
        }  # No videos, no pagination
        mock_youtube_service.videos.return_value.list.return_value = mock_videos_list
        mock_build.return_value = mock_youtube_service

        test_token = "test-access-token-123"

        # Act: Call the function. We need to exhaust the generator.
        list(fetch_liked_videos(test_token))

        # Assert: Verify that 'build' was called with a Credentials object
        # that has all the necessary attributes.
        mock_build.assert_called_once()

        # Check the 'credentials' keyword argument from the call to 'build'
        args, kwargs = mock_build.call_args
        actual_credentials = kwargs.get("credentials")

        self.assertIsNotNone(actual_credentials)
        self.assertIsInstance(actual_credentials, Credentials)
        self.assertEqual(actual_credentials.token, test_token)
        self.assertEqual(
            actual_credentials.token_uri, "https://oauth2.googleapis.com/token"
        )
        self.assertEqual(actual_credentials._client_id, "unused")
        self.assertEqual(actual_credentials._client_secret, "unused")
        self.assertEqual(
            actual_credentials._scopes,
            ["https://www.googleapis.com/auth/youtube.readonly"],
        )


if __name__ == "__main__":
    unittest.main()
