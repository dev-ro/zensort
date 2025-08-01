# Commands

## Run the app on dev environment

```bash
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=FLAVOR=dev
```

## Configure Firebase for web platform

If you encounter Firebase configuration errors on the web (e.g., `[firebase_auth/configuration-not-found]`), reconfigure Firebase for the web platform:

```bash
# For dev environment
flutterfire configure --project=zensort-dev --platforms=web

# For production environment  
flutterfire configure --project=zensort-prod --platforms=web
```

This will update `lib/firebase_options.dart` and `firebase.json` with the correct configuration.

## Deploy the cloud functions to dev environment

```bash
firebase deploy --only functions --project zensort-dev
# or
firebase use zensort-dev
firebase deploy --only functions
```

```bash
curl "https://us-central1-zensort-dev.cloudfunctions.net/trigger_video_embeddings?secret=zensort-embedding-backfill-2024"

```

```markdown
Hello Cursor. Before we begin new feature work, please clean up our Git repository by deleting all stale branches.

**Objective:**
Delete all local and remote branches that have already been merged, leaving only the `main` branch.

**State Context (The "Why"):**
Our repository has several old feature branches from our recent debugging sessions. To maintain a clean and manageable Git history, these should be removed.

**Intent Context (The "How"):**
Please execute the following shell commands sequentially to perform the cleanup.

1. **Switch to the `main` branch:**
    `git checkout main`

2. **Fetch up-to-date branch information from the remote:**
    `git fetch --prune`

3. **Delete all local branches except `main`:**
    `git branch | grep -v "main" | xargs git branch -D`

4. **Delete all remote branches except `main` and `HEAD`:**
    `git branch -r | grep -v "origin/main" | grep -v "origin/HEAD" | sed 's/origin\///' | xargs -n 1 git push origin --delete`

Execute these commands carefully and confirm when the cleanup is complete.
```
