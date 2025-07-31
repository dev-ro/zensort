#!/bin/bash
# Cloud Functions Python 3.12 Environment Setup Script for GitBash/Linux
# This script sets up the Python 3.12 virtual environment for Firebase Cloud Functions

set -e  # Exit on any error

echo "Setting up Python 3.12 virtual environment for Firebase Cloud Functions..."

# Navigate to functions directory
cd "$(dirname "$0")"

# Check if Python 3.12 is available
echo "Checking Python 3.12 availability..."
if ! py -3.12 --version &>/dev/null; then
    echo "ERROR: Python 3.12 is not available"
    echo "Please install Python 3.12 from https://python.org/downloads/"
    echo "Make sure to check 'Add Python to PATH' during installation"
    exit 1
fi

echo "✅ Python 3.12 found"

# Remove existing venv if it exists
if [ -d "venv" ]; then
    echo "Removing existing virtual environment..."
    rm -rf venv
fi

# Create new virtual environment with Python 3.12
echo "Creating Python 3.12 virtual environment..."
py -3.12 -m venv venv

echo "✅ Virtual environment created"

# Activate virtual environment and install dependencies
echo "Activating virtual environment and installing dependencies..."
source venv/Scripts/activate

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

echo "✅ Dependencies installed successfully"

# Validate installation
echo "Validating Firebase modules..."
python -c "import firebase_admin, firebase_functions; print('✅ Firebase modules validated')"

echo ""
echo "========================================"
echo "🎉 Setup completed successfully!"
echo "========================================"
echo ""
echo "To activate the environment in the future:"
echo "  cd functions"
echo "  source venv/Scripts/activate"
echo ""
echo "To deploy functions:"
echo "  firebase deploy --only functions"
echo ""