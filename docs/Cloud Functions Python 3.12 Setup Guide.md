# Cloud Functions Python 3.12 Setup Guide

This guide provides step-by-step instructions for setting up the Python 3.12 virtual environment for Firebase Cloud Functions development on Windows.

## Overview

ZenSort's Cloud Functions require Python 3.12 to match the Firebase runtime configuration. This guide ensures your local development environment matches the cloud deployment environment.

## Prerequisites

- Windows 10/11
- Python 3.12 installed from [python.org](https://python.org)
- Git Bash (preferred) or PowerShell
- Firebase CLI installed and authenticated

## Quick Setup

### Option 1: Automated Setup (Recommended)

Navigate to the `functions` directory and run the appropriate setup script:

#### For PowerShell/Command Prompt:
```cmd
cd functions
setup_env.bat
```

#### For Git Bash:
```bash
cd functions
./setup_env.sh
```

### Option 2: Manual Setup

If you prefer to understand each step or need to troubleshoot:

1. **Navigate to functions directory:**
   ```bash
   cd functions
   ```

2. **Verify Python 3.12 is available:**
   ```bash
   py -3.12 --version
   # Should output: Python 3.12.x
   ```

3. **Remove existing virtual environment (if exists):**
   ```bash
   rm -rf venv
   ```

4. **Create Python 3.12 virtual environment:**
   ```bash
   # Using Python Launcher (PowerShell/CMD)
   py -3.12 -m venv venv
   
   # Using full path (Git Bash)
   "/c/Users/kyle0/AppData/Local/Programs/Python/Python312/python.exe" -m venv venv
   ```

5. **Activate virtual environment:**
   ```bash
   # Git Bash
   source venv/Scripts/activate
   
   # PowerShell/CMD
   venv\Scripts\activate.bat
   ```

6. **Upgrade pip:**
   ```bash
   python -m pip install --upgrade pip
   ```

7. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Validation

After setup, validate your environment using the validation script:

```bash
python validate_env.py
```

This script checks:
- ✅ Python 3.12.x version
- ✅ Virtual environment activation
- ✅ Firebase module imports
- ✅ Firebase configuration (runtime: python312)
- ✅ Required dependencies installation

Expected output:
```
🎉 ALL CHECKS PASSED - Environment is ready for deployment!

🚀 You can now deploy with:
   firebase deploy --only functions
```

## Daily Development Workflow

1. **Navigate to functions directory:**
   ```bash
   cd functions
   ```

2. **Activate virtual environment:**
   ```bash
   source venv/Scripts/activate  # Git Bash
   venv\Scripts\activate.bat     # PowerShell/CMD
   ```

3. **Verify environment (optional):**
   ```bash
   python validate_env.py
   ```

4. **Deploy functions:**
   ```bash
   firebase deploy --only functions
   ```

## Firebase Configuration

The project is configured for:
- **Runtime:** `python312` (matches local Python 3.12)
- **Region:** `us-central1` (Firebase project region)
- **Project:** `zensort-dev` (development environment)

Configuration is defined in `firebase.json`:
```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "runtime": "python312",
      "location": "us-central1"
    }
  ]
}
```

## Troubleshooting

### Python 3.12 Not Found

**Error:** `python3.12: command not found` or `py -3.12: command not found`

**Solution:**
1. Install Python 3.12 from [python.org](https://python.org/downloads/)
2. During installation, ensure "Add Python to PATH" is checked
3. Restart your terminal
4. Verify with: `py -0` (should show Python 3.12 in the list)

### Virtual Environment Creation Fails

**Error:** `Failed to create virtual environment`

**Solution:**
1. Remove existing venv: `rm -rf venv`
2. Try using the full Python path:
   ```bash
   "/c/Users/kyle0/AppData/Local/Programs/Python/Python312/python.exe" -m venv venv
   ```

### Dependency Installation Fails

**Error:** `Failed to install dependencies`

**Solution:**
1. Ensure virtual environment is activated (prompt should show `(venv)`)
2. Update pip: `python -m pip install --upgrade pip`
3. Try installing with verbose output: `pip install -r requirements.txt -v`

### Firebase Deployment Fails

**Error:** Runtime version mismatch

**Solution:**
1. Verify local Python version: `python --version` (should be 3.12.x)
2. Check firebase.json runtime setting (should be `python312`)
3. Run validation script: `python validate_env.py`

### Module Import Errors

**Error:** `ModuleNotFoundError: No module named 'firebase_admin'`

**Solution:**
1. Ensure virtual environment is activated
2. Reinstall dependencies: `pip install -r requirements.txt`
3. Run validation: `python validate_env.py`

## Files Created by This Setup

- `functions/venv/` - Python 3.12 virtual environment
- `functions/setup_env.bat` - Windows batch setup script
- `functions/setup_env.sh` - Git Bash setup script  
- `functions/validate_env.py` - Environment validation script

## Environment Details

- **Local Python Version:** 3.12.10
- **Virtual Environment:** `functions/venv/`
- **Firebase Runtime:** `python312`
- **Firebase Region:** `us-central1`
- **Firebase Project:** `zensort-dev`

## Next Steps

With your environment properly configured:

1. **Develop functions** in `functions/main.py`
2. **Test locally** using the validation script
3. **Deploy to Firebase** with confidence that versions match
4. **Monitor logs** in Firebase Console

For advanced Firebase patterns and architecture guidelines, see:
- `.cursor/rules/08-advanced-firebase.mdc`
- `.cursor/rules/09-feature-youtube.mdc`

---

*Last updated: January 2025*