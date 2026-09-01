# SpendSense: Long-Term Product Vision & Roadmap

This document serves as the high-level strategic roadmap for SpendSense. It outlines the core pillars of future development to transform the app from a transaction logger into a comprehensive personal finance assistant.

---

## 1. Advanced Financial Visualization
**Goal:** Provide the user with a bird's-eye view of their spending habits across different time horizons.

- **Multi-Period Graphs:**
    - **Daily:** Granular view of today's spending vs. yesterday.
    - **Weekly:** Identifying weekday vs. weekend spending spikes.
    - **Monthly:** Budget vs. Actual comparisons.
    - **Yearly:** Trend analysis to identify seasonal spending patterns (e.g., higher expenses in Diwali/December).
- **Interactive Dashboards:** Tappable charts to drill down from a category (e.g., "Food") into specific merchants (e.g., "Zomato").

---

## 2. Intelligence & Pattern Analysis
**Goal:** Use the collected data to provide actionable financial advice.

- **Predictive Insights:** "Based on your last 3 months, you are likely to spend ₹X on Electricity this month."
- **Financial Goal Alignment:** Nudges when spending in a "Fun" category is eating into "Savings" goals.
- **Spending Anomalies:** Alerts for unusual transactions (e.g., "You spent 3x more on Fuel this week than your average").

---

## 3. Social & Contact Integration
**Goal:** Simplify peer-to-person tracking by bridging the gap between SMS and your address book.

- **Contact Sync:** Map phone numbers found in SMS or UPI IDs (e.g., `9876543210@okaxis`) to real names in the phone's contact list.
- **Peer History:** View a dedicated ledger for a specific friend (e.g., "All transactions with Girdhar").

---

## 4. Specialized Modes: "Trip/Tour Mode"
**Goal:** Handle temporary high-intensity spending periods without "polluting" regular monthly averages.

- **Event-Based Grouping:** Create a "Trip to Goa" container. All expenses within these dates are moved into this trip.
- **Group Splitting:** 
    - Support "Paid by me for all" or "Paid by friend for me."
    - Automatic "Who owes whom" calculation at the end of the trip.
- **Budget Isolation:** Treat trip expenses as a "One-time cost" so the regular "Monthly Food Budget" doesn't look broken.

---

## 5. SpendSense Active Pay (The UPI Pivot)
**Goal:** Eliminate data ambiguity by handling transactions directly via UPI integration.

- **Direct Context:** By initiating payments within the app, SpendSense gains 100% accurate merchant and category data at the source, removing the need for AI-guessing or Regex on those specific transactions.
- **Hybrid Ledger:** Combine "Direct Payments" (Active) with "SMS Ingestion" (Passive) to create a complete financial ledger that is both "Zero-Touch" for external payments and "Zero-Ambiguity" for internal ones.
- **Frictionless Workflow:** Move from "Log after the fact" to "Pay and Log in one tap."

---

## 6. Source Attribution (Multi-Bank Support)
**Goal:** Provide a complete view of "Where the money came from," not just "Where it went."

- **Automatic Bank Detection:** Leverage bank-specific SMS patterns to automatically tag transactions with the source account (e.g., HDFC Credit Card, SBI Savings).
- **Multi-Account Dashboards:** View separate spending trends and balances for different bank accounts within a single app.
- **Credit vs. Debit Intelligence:** Automatically differentiate between credit card spending (debt) and savings account spending (liquidity).

---

## 7. Historical Reconciliation (Statement Import)
**Goal:** Build a complete financial history by importing official bank statements.

- **Bulk Ingestion:** Support PDF/CSV statement imports from major banks to instantly populate the ledger with historical data, allowing for immediate insights upon app installation.
- **Smart Reconciliation:** Automatically match statement entries against SMS-captured transactions using Transaction IDs (UTR) to ensure 100% accuracy without double-counting.
- **Privacy-Preserving Parsing:** Perform all PDF/CSV parsing locally on the device, ensuring that sensitive financial statements never leave the user's phone.

---

## 8. Future Scope Suggestions (New)
Beyond the core goals, here are professional features to enhance SpendSense:

- **A. Auto-Subscription Management:** 
    - Identify recurring monthly payments (Netflix, Spotify, Gym, Broadband).
    - Provide a "Upcoming Bill" calendar.
    - Alert for price hikes in subscriptions.
- **B. Investment vs. Expense Tracking:** 
    - Differentiate between "Money Spent" (Expense) and "Money Moved" (Investment in Zerodha, Groww, etc.).
    - Show "Net Worth Growth" by tracking how much was invested vs. consumed.
- **C. Document/Receipt OCR:** 
    - For physical cash payments that don't send SMS, allow the user to snap a photo of the bill.
    - Use on-device AI to extract the amount and merchant.
- **D. Professional Reports:** 
    - One-tap export to PDF/Excel for tax filing or reimbursement claims.
- **E. Multi-Account Balancing:** 
    - Identify "Self-Transfers" between your own HDFC and SBI accounts to avoid double-counting income/expenses.

---

## 6. Implementation Philosophy
All future features must strictly adhere to the project's core mandates:
1. **Local-First:** All heavy lifting (Graphs, OCR, Pattern Analysis) happens on the phone.
2. **Privacy-Focused:** Social features must be opt-in and never upload contact lists to a central server.
3. **Zero-Hurdle:** New features should "just work" as soon as the relevant data is captured.
