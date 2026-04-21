# Security & Sensitive Information Guide

## Overview

SpendSense handles sensitive information like API keys, webhook URLs, and user credentials. This document explains how to keep them local and prevent accidental pushes to GitHub.

## What's Protected by .gitignore

The `.gitignore` file automatically excludes these files from Git:

### Configuration Files
- `.env` - Local environment variables
- `.env.local` - Local overrides
- `lib/config/secrets.dart` - Dart secrets file
- `lib/config/api_keys.dart` - API key constants
- `backend/.env.js` - Backend secrets

### Sensitive Files
- `*.pem`, `*.key` - Private encryption keys
- `*.jks`, `*.keystore` - Android keystores
- `google-services.json` - Firebase config
- `GoogleService-Info.plist` - iOS Firebase config
- `secrets.json` - General secrets file

### Credentials
- `android/key.properties` - Signing key properties
- `android/app/key.jks` - Signing keystore

## How to Set Up Locally

### Step 1: Create .env File
```bash
cp .env.example .env
```

Then edit `.env` and add your actual values:
```
CLAUDE_API_KEY=sk-ant-xxx...
SHEETS_WEBHOOK_URL=https://script.google.com/...
GOOGLE_OAUTH_CLIENT_ID=xxx.apps.googleusercontent.com
```

### Step 2: Load Environment Variables in Your App

In `flutter_application_1/lib/main.dart` or `lib/config/env_loader.dart`:

```dart
// Example: Using dotenv package (add to pubspec.yaml: dotenv: ^3.1.0)
import 'package:dotenv/dotenv.dart';

void main() async {
  // Load .env file locally (not available in production)
  await dotenv.load(fileName: ".env");
  
  String claudeApiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
  String sheetsWebhook = dotenv.env['SHEETS_WEBHOOK_URL'] ?? '';
  
  runApp(const MyApp());
}
```

Or use `SecureStorageService` (recommended for production):

```dart
// SecureStorageService stores encrypted values in Android Keystore
final secureStorage = SecureStorageService();

// Read at app startup
String? claudeKey = await secureStorage.getClaudeApiKey();

// User can input via Settings screen (setup_screen.dart)
await secureStorage.setClaudeApiKey(userInputKey);
```

### Step 3: Verify Before Pushing

Always check before pushing:

```bash
# See what files will be committed
git status

# See what files are ignored
git check-ignore -v *

# Dry run to verify nothing sensitive is included
git diff --cached --name-only
```

## Best Practices

### ✅ DO
- ✅ Use `.env.example` as a template for contributors
- ✅ Store production secrets in Android Keystore (SecureStorageService)
- ✅ Use GitHub Secrets for CI/CD (if using GitHub Actions)
- ✅ Review `.gitignore` after adding new config files
- ✅ Use `git status` before committing

### ❌ DON'T
- ❌ Commit `.env` files
- ❌ Hardcode API keys in source code
- ❌ Commit private keys or keystores
- ❌ Push Firebase/Google config files
- ❌ Share credentials in commit messages

## If You Accidentally Committed a Secret

If you realize you committed an API key or secret:

```bash
# Remove from Git history (rewrites history - only do locally!)
git rm --cached .env
git rm --cached lib/config/secrets.dart

# Commit the removal
git commit -m "Remove sensitive files"

# IMPORTANT: Rotate the exposed secret immediately (generate a new API key)
```

## Environment Variables in CI/CD

For GitHub Actions (used by copilot-setup-steps.yml), add secrets via:

1. Go to Settings → Secrets and variables → Actions
2. Add secrets like `CLAUDE_API_KEY`, `SHEETS_WEBHOOK_URL`
3. Access in workflow:
   ```yaml
   env:
     CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
   ```

## Reference

- `.gitignore` — Automatically excludes sensitive files
- `.env.example` — Template for required environment variables
- `lib/services/secure_storage_service.dart` — Handles encrypted local storage
- `lib/ui/screens/setup_screen.dart` — User-facing settings for optional keys

---

**Remember:** Your local `.env` file is YOUR responsibility. Git cannot protect it; you must ensure it's not committed and never shared.
