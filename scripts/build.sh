#!/bin/bash
set -e

# Default to 'dev' flavor if no argument is provided
FLAVOR=${1:-dev}

# Validate the flavor
if [ "$FLAVOR" != "dev" ] && [ "$FLAVOR" != "prod" ]; then
  echo "Invalid flavor: $FLAVOR. Use 'dev' or 'prod'."
  exit 1
fi

echo "Building with flavor: $FLAVOR"

# Build the Flutter web app
if [ "$FLAVOR" == "prod" ]; then
  flutter build web --dart-define=FLAVOR=prod
else
  flutter build web
fi

# Write the flavor to a file in the build directory
echo "$FLAVOR" > build/web/.build_flavor

echo "Build complete for flavor: $FLAVOR" 