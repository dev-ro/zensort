#!/usr/bin/env python3
"""
Cloud Functions Environment Validation Script
This script validates that the Python 3.12 environment is correctly set up for Firebase Cloud Functions.
"""

import subprocess
import sys
from pathlib import Path


def check_python_version():
    """Verify Python version is 3.12.x"""
    print("🔍 Checking Python version...")
    version = sys.version_info
    if version.major == 3 and version.minor == 12:
        print(
            f"✅ Python {version.major}.{version.minor}.{version.micro} - Correct version"
        )
        return True
    else:
        print(
            f"❌ Python {version.major}.{version.minor}.{version.micro} - Expected Python 3.12.x"
        )
        return False


def check_virtual_environment():
    """Verify we're running in a virtual environment"""
    print("\n🔍 Checking virtual environment...")
    if hasattr(sys, "real_prefix") or (
        hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix
    ):
        print("✅ Running in virtual environment")
        print(f"   Virtual env path: {sys.prefix}")
        return True
    else:
        print("❌ Not running in virtual environment")
        return False


def check_firebase_modules():
    """Test Firebase module imports"""
    print("\n🔍 Checking Firebase modules...")

    modules_to_check = [
        "firebase_admin",
        "firebase_functions",
        "google.cloud.firestore",
        "google.cloud.secretmanager",
        "googleapiclient.discovery",
        "openai",
    ]

    all_passed = True
    for module in modules_to_check:
        try:
            __import__(module)
            print(f"✅ {module}")
        except ImportError as e:
            print(f"❌ {module} - {e}")
            all_passed = False

    return all_passed


def check_firebase_config():
    """Check Firebase configuration"""
    print("\n🔍 Checking Firebase configuration...")

    # Check if firebase.json exists in parent directory
    firebase_json = Path("../firebase.json")
    if firebase_json.exists():
        print("✅ firebase.json found")

        # Try to read and validate basic structure
        try:
            import json

            with open(firebase_json, "r") as f:
                config = json.load(f)

            if "functions" in config:
                functions_config = (
                    config["functions"][0]
                    if isinstance(config["functions"], list)
                    else config["functions"]
                )
                runtime = functions_config.get("runtime", "unknown")
                location = functions_config.get("location", "unknown")

                if runtime == "python312":
                    print(f"✅ Runtime: {runtime}")
                else:
                    print(f"❌ Runtime: {runtime} - Expected 'python312'")
                    return False

                if location == "us-central1":
                    print(f"✅ Location: {location}")
                else:
                    print(f"⚠️  Location: {location} - Expected 'us-central1'")

                return True
            else:
                print("❌ No functions configuration found in firebase.json")
                return False

        except Exception as e:
            print(f"❌ Error reading firebase.json: {e}")
            return False
    else:
        print("❌ firebase.json not found")
        return False


def check_requirements():
    """Check if all requirements are satisfied"""
    print("\n🔍 Checking requirements.txt dependencies...")

    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "list"],
            capture_output=True,
            text=True,
            check=True,
        )
        installed_packages = result.stdout.lower()

        # Key packages to check
        key_packages = [
            "firebase-admin",
            "firebase-functions",
            "google-cloud-firestore",
            "google-cloud-secret-manager",
            "google-api-python-client",
            "openai",
        ]

        all_found = True
        for package in key_packages:
            if package in installed_packages:
                print(f"✅ {package}")
            else:
                print(f"❌ {package} - Not found")
                all_found = False

        return all_found

    except subprocess.CalledProcessError as e:
        print(f"❌ Error checking installed packages: {e}")
        return False


def main():
    """Run all validation checks"""
    print("=" * 60)
    print("🔥 Firebase Cloud Functions Environment Validation")
    print("=" * 60)

    checks = [
        check_python_version,
        check_virtual_environment,
        check_firebase_modules,
        check_firebase_config,
        check_requirements,
    ]

    results = []
    for check in checks:
        try:
            result = check()
            results.append(result)
        except Exception as e:
            print(f"❌ Error during {check.__name__}: {e}")
            results.append(False)

    print("\n" + "=" * 60)
    print("📊 VALIDATION SUMMARY")
    print("=" * 60)

    passed = sum(results)
    total = len(results)

    if passed == total:
        print("🎉 ALL CHECKS PASSED - Environment is ready for deployment!")
        print("\n🚀 You can now deploy with:")
        print("   firebase deploy --only functions")
        return 0
    else:
        print(f"❌ {total - passed} check(s) failed out of {total}")
        print("\n🔧 Please fix the issues above before deploying.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
