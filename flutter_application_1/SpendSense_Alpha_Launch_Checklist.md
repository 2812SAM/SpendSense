# SpendSense Alpha Launch Checklist

Last updated: 2026-04-19

## Product Readiness (Zero-Hurdle)

- [ ] Confirm the app works **instantly** without entering any API keys or URLs
- [ ] Verify local regex accurately parses amounts from common bank SMS (HDFC, ICICI, SBI, AXIS)
- [ ] Confirm "First Seen" merchants can be categorized manually and remembered in Local Storage
- [ ] Confirm SMS permissions are requested immediately upon launch
- [ ] Confirm transactions are saved to the local ledger **before** any attempt to sync
- [ ] Verify **SecureStorageService** correctly encrypts and protects API keys/URLs
- [ ] Confirm all **Unit Tests** for `LocalParserService` pass on every build
- [ ] Confirm person-to-person and Loan flows behave correctly using local keywords

## Advanced Features (Optional)

- [ ] Verify Claude API integration works as an optional upgrade (if key provided)
- [ ] Verify Google Sheets sync works via the optional Webhook (if URL provided)
- [ ] Verify low-confidence transactions from the **AI path** trigger popup/digest
- [ ] Verify malformed Claude responses fall back to manual review without data loss

## Android Runtime Checks

- [ ] Verify SMS permission prompt appears on first launch
- [ ] Verify notification permission prompt appears on Android 13+
- [ ] Verify microphone permission works for voice confirmation
- [ ] Verify notification tap opens the correct popup or digest screen
- [ ] Verify the daily digest reminder is scheduled for 9 PM India time
- [ ] Verify app behavior after force close and device reboot

## UX Checks (Onboarding)

- [ ] Confirm the initial "Setup Screen" is **not blocking** or skipped for first-run users
- [ ] Confirm a "Connection Status" UI exists to show if AI/Cloud features are active or missing
- [ ] Confirm settings screen allows adding/editing keys later without starting from scratch
- [ ] Confirm the home screen updates immediately after a manual or voice confirmation

## Release Prep

- [ ] Replace debug signing with a real release signing config
- [ ] Set final Play Store-safe application ID and package ownership details
- [ ] Add privacy policy covering SMS reading, microphone use, and local-first data storage
- [ ] Decide and document data retention policy for local ledger
- [ ] Add crash/error logging (e.g., Sentry) before opening alpha to external testers

## Alpha Exit Criteria

SpendSense is ready for a controlled alpha when all of the following are true:

- [ ] **Plug-and-Play:** A user can install the app and see their first transaction within 2 minutes with ZERO technical setup.
- [ ] **Privacy:** No data is transmitted to Claude or Google unless the user opted-in via settings.
- [ ] **Reliability:** No transaction loss observed across 50+ mixed test transactions on 2+ real Android devices.
- [ ] **Learning:** Merchant memory successfully eliminates duplicate review prompts for the same merchant.

