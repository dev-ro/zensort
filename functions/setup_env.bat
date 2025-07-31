@echo off
REM Cloud Functions Python 3.12 Environment Setup Script for Windows
REM This script sets up the Python 3.12 virtual environment for Firebase Cloud Functions

echo Setting up Python 3.12 virtual environment for Firebase Cloud Functions...

REM Check if Python 3.12 is available
echo Checking Python 3.12 availability...
py -3.12 --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python 3.12 is not installed or not available via Python Launcher
    echo Please install Python 3.12 from https://python.org
    exit /b 1
)

echo ✅ Python 3.12 found

REM Navigate to functions directory
cd /d "%~dp0"

REM Remove existing venv if it exists
if exist "venv" (
    echo Removing existing virtual environment...
    rmdir /s /q venv
)

REM Create new virtual environment with Python 3.12
echo Creating Python 3.12 virtual environment...
py -3.12 -m venv venv
if errorlevel 1 (
    echo ERROR: Failed to create virtual environment
    exit /b 1
)

echo ✅ Virtual environment created

REM Activate virtual environment and install dependencies
echo Activating virtual environment and installing dependencies...
call venv\Scripts\activate.bat

REM Upgrade pip
python -m pip install --upgrade pip

REM Install dependencies
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    exit /b 1
)

echo ✅ Dependencies installed successfully

REM Validate installation
echo Validating Firebase modules...
python -c "import firebase_admin, firebase_functions; print('✅ Firebase modules validated')"
if errorlevel 1 (
    echo ERROR: Firebase modules validation failed
    exit /b 1
)

echo.
echo ========================================
echo 🎉 Setup completed successfully!
echo ========================================
echo.
echo To activate the environment in the future:
echo   cd functions
echo   venv\Scripts\activate.bat
echo.
echo To deploy functions:
echo   firebase deploy --only functions
echo.