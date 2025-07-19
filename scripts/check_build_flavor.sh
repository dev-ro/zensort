#!/bin/bash

# Get the target Firebase project ID from the environment variable set by Firebase CLI
TARGET_PROJECT_ID="$GCLOUD_PROJECT"
BUILD_FLAVOR_FILE="build/web/.build_flavor"

# Check if the build flavor file exists
if [ ! -f "$BUILD_FLAVOR_FILE" ]; then
    echo "--------------------------------------------------------------------"
    echo "⛔️ Deploy Aborted: Build Artifacts Missing"
    echo ""
    echo "Could not find 'build/web/.build_flavor'."
    echo "Fix: Run the build script first (e.g., './build.sh prod')."
    echo "--------------------------------------------------------------------"
    exit 1
fi

# Get the actual build flavor from the file
BUILD_FLAVOR=$(cat "$BUILD_FLAVOR_FILE")

# Define your project IDs
PROD_PROJECT_ID="zensort-a7b47"
DEV_PROJECT_ID="zensort-dev"

# Determine the expected flavor based on the target project
EXPECTED_FLAVOR=""
if [ "$TARGET_PROJECT_ID" == "$PROD_PROJECT_ID" ]; then
  EXPECTED_FLAVOR="prod"
elif [ "$TARGET_PROJECT_ID" == "$DEV_PROJECT_ID" ]; then
  EXPECTED_FLAVOR="dev"
else
  # If the project is neither dev nor prod, we don't enforce a check.
  exit 0
fi

# Fail if the actual build flavor does not match the expected one
if [ "$BUILD_FLAVOR" != "$EXPECTED_FLAVOR" ]; then
  echo "--------------------------------------------------------------------"
  echo "⛔️ Deploy Aborted: Build Mismatch"
  echo ""
  echo "Attempted to deploy a '$BUILD_FLAVOR' build to project '$TARGET_PROJECT_ID'."
  echo "This project requires a '$EXPECTED_FLAVOR' build."
  echo ""
  echo "Fix: Run './build.sh $EXPECTED_FLAVOR' and retry deployment."
  echo "--------------------------------------------------------------------"
  exit 1
fi

# On success, be silent. The Firebase CLI provides enough success output.
exit 0 