# Zero-Hurdle Test Strategy

Perform these tests after each implementation phase to ensure reliability and no regressions.

## Phase 1: UX Bypass
- [ ] **Fresh Install Test**: Clear app data, install, and open. App should land on `HomeScreen` (if permissions granted) or a `PermissionRequestScreen`.
- [ ] **No-Key Launch**: Ensure `AppState` initializes without errors when `SharedPreferences` are empty.

## Phase 2: Local Parsing
- [ ] **Regex Accuracy**: Mock SMS messages for HDFC, ICICI, SBI, and Axis. Verify `LocalParserService` returns the correct `amount` and `merchant`.
- [ ] **Keyword Fallback**: Verify "Zomato" or "Uber" in a generic SMS triggers the correct category.

## Phase 3: Orchestration
- [ ] **No-Key Flow**: Receive an unknown SMS with no Claude key. Verify:
    - [ ] Transaction is saved to SQLite as `is_confirmed = 0`.
    - [ ] A notification is triggered.
    - [ ] "Review" banner appears on Home.
- [ ] **AI-Key Flow**: Add a valid key. Verify Claude is called only for ambiguous messages.

## Phase 4: Reliability
- [ ] **Deduplication**: Send the same SMS twice. Verify only ONE entry exists in the `transactions` table.
- [ ] **Offline Sync**: Disable internet, confirm a transaction. Verify `sync_status = 'pending'`. Re-enable internet and restart app. Verify sync happens automatically.

## Phase 5: UI Redesign
- [ ] **Toggle Persistence**: Turn off "Enable AI". Verify AI calls are bypassed.
- [ ] **Validation Flow**: Ensure the "Test Webhook" button still works in the new Settings UI.
