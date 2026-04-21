/**
 * SpendSense — Google Apps Script Webhook
 * 
 * Deploy this as a Web App:
 *   Extensions → Apps Script → paste this → Deploy → New deployment
 *   → Web App → Execute as: Me → Who has access: Anyone → Deploy
 *
 * Receives JSON POST from the Flutter app.
 * Routes to correct sheet tab: Expenses or Loans.
 *
 * Sheet structure expected:
 *   Spreadsheet name: SpendSense
 *   Tab 1: Expenses  (headers: Date | Time | Amount | Merchant | Category | Note | Confidence | Type)
 *   Tab 2: Loans     (headers: Date | Time | Amount | Person | Reason | Status)
 */

const SHEET_EXPENSES = 'Expenses';
const SHEET_LOANS    = 'Loans';

// ── Main entry point — receives HTTP POST from Flutter app ────────────────
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    // Validate required fields
    if (!data.amount || !data.merchant || !data.type) {
      return _error('Missing required fields: amount, merchant, type');
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();

    if (data.type === 'LOAN') {
      _writeToLoans(ss, data);
    } else {
      _writeToExpenses(ss, data);
    }

    return _success();

  } catch (err) {
    return _error(err.toString());
  }
}

// ── Write to Expenses tab ─────────────────────────────────────────────────
function _writeToExpenses(ss, data) {
  const sheet = ss.getSheetByName(SHEET_EXPENSES);
  if (!sheet) throw new Error(`Sheet "${SHEET_EXPENSES}" not found`);

  sheet.appendRow([
    data.date       || _today(),
    data.time       || _now(),
    data.amount,
    data.merchant,
    data.category   || 'Others',
    data.note       || '',
    data.confidence || 'HIGH',
    'Expense',
  ]);
}

// ── Write to Loans tab ────────────────────────────────────────────────────
function _writeToLoans(ss, data) {
  const sheet = ss.getSheetByName(SHEET_LOANS);
  if (!sheet) throw new Error(`Sheet "${SHEET_LOANS}" not found`);

  sheet.appendRow([
    data.date     || _today(),
    data.time     || _now(),
    data.amount,
    data.merchant,            // person name
    data.note     || '',      // reason (from voice note)
    'Pending',                // repayment status — user can update manually
  ]);
}

// ── GET handler — health check ────────────────────────────────────────────
// Visit the web app URL in a browser to confirm it's deployed.
function doGet(e) {
  return ContentService
    .createTextOutput(JSON.stringify({
      status:  'ok',
      message: 'SpendSense webhook is running',
      time:    new Date().toISOString(),
    }))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── Manual test function — run this from Apps Script editor ──────────────
// Change dropdown to "testWrite" and click Run.
function testWrite() {
  const ss    = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_EXPENSES);

  sheet.appendRow([
    '17/04/2026',
    '13:42',
    '450',
    'Zomato',
    'Food',
    'Test entry — delete me',
    'HIGH',
    'Expense',
  ]);

  Logger.log('Test row written to Expenses tab successfully.');
}

// ── Helpers ───────────────────────────────────────────────────────────────
function _success() {
  return ContentService
    .createTextOutput(JSON.stringify({ status: 'success' }))
    .setMimeType(ContentService.MimeType.JSON);
}

function _error(message) {
  return ContentService
    .createTextOutput(JSON.stringify({ status: 'error', message: message }))
    .setMimeType(ContentService.MimeType.JSON);
}

function _today() {
  const d = new Date();
  return `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${d.getFullYear()}`;
}

function _now() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}
