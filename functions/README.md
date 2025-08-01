# Firebase Cloud Functions

This directory contains the backend logic for the ZenSort application, implemented as Firebase Cloud Functions.

## Functions

### `add_to_waitlist`

- **Trigger**: HTTPS
- **Description**: This function is called from the landing page when a user submits their email to join the waitlist. It validates the email and adds it to the `waitlist` collection in Firestore.
- **File**: `main.py`

### `sync_youtube_liked_videos`

- **Trigger**: HTTPS (or as configured)
- **Description**: This function handles the synchronization of a user's liked videos from their YouTube account. It fetches the video data and processes it for organization within the ZenSort app.
- **File**: `sync_youtube_liked_videos.py`

## Local Development and Testing

### Setup

1. **Navigate to the functions directory:**

    ```sh
    cd functions
    ```

2. **Create a Python virtual environment:**

    ```sh
    python -m venv venv
    ```

3. **Activate the virtual environment:**
    - **Windows:**

        ```sh
        .\venv\Scripts\activate
        ```

    - **macOS/Linux:**

        ```sh
        source venv/bin/activate
        ```

4. **Install dependencies:**

    ```sh
    pip install -r requirements.txt
    ```

### Running Tests

To run the unit tests for the cloud functions, use the following command:

```sh
python -m pytest
```

Make sure to add new tests in the `tests/` directory for any new functionality. The test files should start with `test_` [[memory:3598373]].

## Deployment

To deploy the functions to Firebase, use the Firebase CLI:

```sh
firebase deploy --only functions
```

This will deploy all the functions defined in this directory to your configured Firebase project.

---

_This README was generated by an AI assistant._
