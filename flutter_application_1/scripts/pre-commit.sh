#!/bin/bash

# SpendSense Pre-commit Hook
# --------------------------
# This script ensures code quality by running formatting checks, 
# static analysis, secret scanning, and unit tests.
#
# To install this hook:
# 1. Copy or link this file to .git/hooks/pre-commit
#    ln -s ../../flutter_application_1/scripts/pre-commit.sh .git/hooks/pre-commit
# 2. Ensure it is executable:
#    chmod +x .git/hooks/pre-commit

set -e # Exit immediately if a command exits with a non-zero status.

# Determine the root of the repo
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT_DIR="$REPO_ROOT/flutter_application_1"

echo "🚀 Running SpendSense Pre-commit Hook..."

# Navigate to the project directory
cd "$PROJECT_DIR"

# 1. Format Check
echo "🎨 Checking formatting..."
dart format . --set-exit-if-changed
if [ $? -ne 0 ]; then
  echo "❌ Formatting issues found. Please run 'dart format .' and stage the changes."
  exit 1
fi

# 2. Static Analysis
echo "🔍 Running flutter analyze..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "❌ Flutter analysis failed. Please fix the issues before committing."
  exit 1
fi

# 3. Secret Scanning
echo "🛡️  Scanning for hardcoded secrets..."
# Patterns to detect potential secrets and hardcoded credentials
# - SECRET_PATTERN: Keywords followed by assignment to a string
# - FORBIDDEN_KEYWORDS: Specific prefixes like sk-ant- (Claude) or Apps Script IDs
SECRET_PATTERN="(AI_KEY|SECRET|API_KEY|PASSWORD|AUTH_TOKEN|WEBHOOK_URL)\s*=\s*['\"].+['\"]"
FORBIDDEN_KEYWORDS="sk-ant-|AKfycb"

# Search for the patterns, excluding known safe directories and files
SECRETS_FOUND=$(grep -riE "$SECRET_PATTERN|$FORBIDDEN_KEYWORDS" . \
  --exclude-dir={.git,build,.dart_tool,scripts,test} \
  --exclude={*.md,analysis_options.yaml,pubspec.yaml,*.lock} || true)

if [ ! -z "$SECRETS_FOUND" ]; then
  echo "❌ Potential hardcoded secrets found:"
  echo "$SECRETS_FOUND" | sed 's/^/  /'
  echo "--------------------------------------------------------"
  echo "CRITICAL: Do not commit plain-text secrets!"
  echo "Please use SecureStorageService or environment variables."
  exit 1
fi

# 4. Unit Tests
echo "🧪 Running flutter test..."
flutter test
if [ $? -ne 0 ]; then
  echo "❌ Flutter tests failed. Please fix tests before committing."
  exit 1
fi

echo "✅ All checks passed! Proceeding with commit."
exit 0
