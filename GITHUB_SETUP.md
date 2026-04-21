# Publishing SpendSense to GitHub

Follow these steps to create a GitHub repository and push your code safely.

## Step 1: Create a GitHub Repository

1. Go to [github.com/new](https://github.com/new)
2. Create a new repository named `spendsense`
3. **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Click **Create repository**

## Step 2: Verify Local Setup

Before pushing, verify that sensitive files won't be committed:

```bash
cd E:\SpendSense

# See what will be committed
git status

# Verify .env, secrets, and keys are ignored
git check-ignore -v .env
git check-ignore -v android/key.properties
git check-ignore -v lib/config/secrets.dart
```

**Expected output:** All should show as ignored ✓

## Step 3: Add Files and Create Initial Commit

```bash
cd E:\SpendSense

# Stage all files (except .gitignore'd ones)
git add .

# Review what's staged
git status

# Create initial commit with proper message
git commit -m "Initial commit: SpendSense local-first expense tracker

- Local SQLite ledger for transaction persistence
- SMS ingestion and parsing
- Optional Claude API integration for categorization
- Optional Google Sheets sync via Apps Script webhook
- SecureStorageService for encrypted local storage of API keys

See SECURITY.md for sensitive information handling."
```

## Step 4: Connect to GitHub and Push

Replace `YOUR_USERNAME` with your actual GitHub username:

```bash
cd E:\SpendSense

# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/spendsense.git

# Rename default branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

## Step 5: Configure GitHub for Safety

### Add Branch Protection (Optional but Recommended)

1. Go to your repo: `github.com/YOUR_USERNAME/spendsense`
2. Settings → Branches → Add rule
3. Branch name pattern: `main`
4. Enable:
   - ✓ Require pull request reviews before merging
   - ✓ Require status checks to pass
   - ✓ Require code reviews from code owners

### Add Repository Secrets (for GitHub Actions)

If you plan to use GitHub Actions (via `.github/workflows/copilot-setup-steps.yml`):

1. Settings → Secrets and variables → Actions
2. New repository secret
3. Add:
   - `CLAUDE_API_KEY` = your Claude API key
   - `SHEETS_WEBHOOK_URL` = your Google Apps Script webhook

These won't be visible in logs and won't be committed to the repo.

## Step 6: Local Development Continues

After pushing, your local `.env` file remains private:

```bash
# Your local changes won't be tracked
git status  # Should show nothing

# Update only your local config
echo "CLAUDE_API_KEY=sk-ant-xxxxx" > .env
# This won't ever be committed (it's in .gitignore)
```

## Verify Everything is Set Up Correctly

Run these checks:

```bash
# 1. Verify .gitignore is working
git ls-files | grep -E "\.env|secrets|key\." 
# Should return nothing

# 2. Check .gitignore file exists on GitHub
git ls-files --others --exclude-standard
# Should show nothing suspicious

# 3. Verify remote is set
git remote -v
# Should show: origin https://github.com/YOUR_USERNAME/spendsense.git

# 4. Check commit history
git log --oneline -5
```

## Common Issues

### Issue: "Sensitive file was pushed by mistake"

Solution:
```bash
# Remove from GitHub (rewrites history)
git rm --cached .env
git commit -m "Remove .env from history"
git push --force-with-lease origin main

# IMPORTANT: Rotate any exposed secrets immediately!
```

### Issue: Can't push - authentication error

Solution:
```bash
# Generate Personal Access Token: github.com/settings/personal-access-tokens/new
# Permissions needed: repo (all), workflow

# Use token as password
git push -u origin main
# When prompted for password, paste the token
```

### Issue: ".env changes showing as modified"

Solution (don't commit, just ignore):
```bash
# Tell Git to ignore local changes to .env
git update-index --skip-worktree .env

# If you need to restore tracking later:
git update-index --no-skip-worktree .env
```

## Next Steps

After pushing to GitHub, you can:

- ✅ Use GitHub Issues for feature tracking
- ✅ Enable GitHub Actions with `copilot-setup-steps.yml`
- ✅ Collaborate with contributors (they'll use `.env.example`)
- ✅ Deploy from GitHub (with secrets configured)
- ✅ Use Copilot CLI: `copilot` in the repo directory

## Security Reminder

⚠️ **Never:**
- Share `.env` files
- Commit API keys
- Paste secrets in issue descriptions
- Store credentials in code comments

📖 See **SECURITY.md** for detailed information.
