# SpendSense: Feature Ideas & Product Roadmap

This document outlines a roadmap for evolving SpendSense from an alpha-stage utility into a premium, market-ready financial tool.

## 1. Product Maturity Assessment
- **Current State:** Advanced Alpha. The core "Zero-Touch" loop (SMS capture -> Local Regex -> Merchant Memory -> Manual Fallback) is architecturally sound and resilient.
- **Strengths:** Local-first data integrity, "Learning Card" for generic ID protection, best-effort cloud sync.
- **Weaknesses:** Lacks visual storytelling (charts), onboarding is utilitarian, and "premium" polish (animations, haptics) is missing.

---

## 2. Must-Have Improvements (Alpha -> Beta)
*Focus: Core usability and basic modern expectations.*

- **[UX] Interactive Onboarding Walkthrough:**
    - Replace the "Setup Screen" with a multi-step welcome flow.
    - Explain *how* SpendSense works (SMS interception) to build trust.
    - Interactive permission granting (SMS, Notification, Microphone) with "Why we need this" explainers.
- **[Feature] Visual Spending Insights:**
    - **Category Pie Chart:** Visual breakdown of monthly spending on the Home Screen.
    - **Spending Trend:** A simple bar chart showing daily/weekly spending levels.
- **[Feature] Category Management UI:**
    - A dedicated screen to view, rename, or delete custom categories.
    - Ability to assign custom emojis to categories.
- **[Feature] Transaction Details View:**
    - Tap a transaction to see: Original SMS text, Sync Status (with error logs), and Fingerprint.
    - Manual edit/delete capability for historical records.
- **[UX] Search & Filter:**
    - Search history by merchant name or note.
    - Filter the main feed by category or date range.

---

## 3. Strong UX Improvements (Professionalism)
*Focus: Retention, engagement, and platform "feel".*

- **[System] Permission Center:**
    - A "Health" tab in Settings to manage all required permissions (SMS, Notification, Microphone, Battery Optimization).
    - Status indicators (Green/Yellow/Red) for each integration.
- **[UI] Real-Time Sync Indicators:**
    - Subtle "Cloud" icons on transaction items:
        - Gray: Pending sync.
        - Green: Synced to Sheets.
        - Red: Sync failed (tap to retry/see error).
- **[UI] Dark Mode Support:**
    - Full support for system-wide light/dark mode transitions.
- **[Feel] Haptic & Audio Feedback:**
    - Subtle "taptic" vibration upon successful transaction capture.
    - A gentle "confirmation" sound when a transaction is manually categorized.
- **[Accessibility] Accessibility Audit & Hardening:**
    - Ensure all buttons have minimum 48x48dp touch targets.
    - High-contrast text options and full Screen Reader (TalkBack) support for the "Learning Card."

---

## 4. Premium Enhancement Ideas (Monetization)
*Focus: Advanced power-user features and high-value integrations.*

- **[Data] Local Data Export:**
    - One-tap export of the entire ledger to CSV, JSON, or PDF for external tax filing or personal backup.
- **[System] Multi-Bank/Account Attribution:**
    - Detect which bank (HDFC, SBI, etc.) or UPI account the SMS originated from.
    - Track "Balance per Account" based on SMS balance alerts.
- **[AI] Advanced Insights (AI Power User):**
    - "Financial Assistant" tab using Claude/Gemini to answer questions like "How much did I spend on Swiggy last month?" or "Identify my most unnecessary expenses."
- **[UI] Home Screen Widgets:**
    - Quick-view widgets for "Total Spent Today" or "Monthly Budget Progress."
- **[Automation] Budgeting & Alerts:**
    - Set monthly limits per category.
    - Real-time "Budget Warning" notifications when crossing 80%/100% of a limit.

---

## 5. Future Roadmap (SpendSense 2.0)
*Focus: Strategic differentiators and next-gen tech.*

- **[AI] On-Device AI (Gemini Nano):**
    - Migrate classification from Claude API to Gemini Nano for on-device processing.
    - Benefit: Zero API costs for the user and 100% privacy (no SMS data leaves the phone).
- **[Integrations] UPI Deep Linking:**
    - Detected a "Bill Pay" or "Loan EMI" SMS? Provide a direct link to open GPay/PhonePe to complete the payment.
- **[Social] Shared Ledgers (Family Mode):**
    - Shared transaction pools for couples or roommates, syncing to a common Google Sheet.
- **[Domain] Investment & Asset Tracking:**
    - Intercept and track Mutual Fund SIPs, Stock purchases, and Gold investments from confirmation SMS.
- **[Vision] Receipt Scanning:**
    - Integrated camera tool to scan physical receipts and match them with SMS records or log cash payments.
