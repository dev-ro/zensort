#!/bin/bash
set -e

# --- Configuration ---
VERSION_FILE="VERSION"

# --- Pre-flight Checks ---

# 1. Ensure we are on the main branch
if [[ $(git rev-parse --abbrev-ref HEAD) != "main" ]]; then
  echo "❌ Error: You must be on the 'main' branch to deploy."
  exit 1
fi

# 2. Ensure the working directory is clean
if [[ -n $(git status --porcelain) ]]; then
  echo "❌ Error: Your working directory is not clean. Please commit or stash your changes."
  exit 1
fi

# 3. Fetch the latest changes from the remote
echo "Checking for remote changes..."
git remote update
if [[ $(git rev-list HEAD...origin/main --count) != "0" ]]; then
  echo "❌ Error: Your main branch is not up-to-date with the remote. Please pull the latest changes."
  exit 1
fi
echo "✅ Branch is up-to-date."


# --- Version Bumping ---

if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ Error: Version file not found at '$VERSION_FILE'"
    exit 1
fi

# Read the current version and increment the patch number
CURRENT_VERSION=$(cat "$VERSION_FILE")
IFS='.' read -r -a version_parts <<< "$CURRENT_VERSION"
version_parts[2]=$((version_parts[2] + 1))
NEW_VERSION="${version_parts[0]}.${version_parts[1]}.${version_parts[2]}"

echo ""
echo "Current version: $CURRENT_VERSION"
echo "   New version: $NEW_VERSION"
echo ""

# --- Confirmation ---

read -p "Do you want to deploy version $NEW_VERSION to production? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# --- Deployment ---

echo "Updating version file..."
echo "$NEW_VERSION" > "$VERSION_FILE"

echo "Committing version bump..."
git add "$VERSION_FILE"
git commit -m "chore(release): bump version to $NEW_VERSION"

echo "Creating and pushing tag..."
git tag "v$NEW_VERSION"
git push origin main
git push --tags

echo ""
echo "✅ Successfully deployed version $NEW_VERSION!"
echo "Check the GitHub Actions tab for progress." 