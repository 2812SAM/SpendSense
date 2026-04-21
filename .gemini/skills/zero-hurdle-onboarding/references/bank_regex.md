# Indian Bank SMS Regex Reference

Use these patterns to extract amounts and merchant names locally from common Indian bank SMS. These patterns should be refined as more SMS formats are collected.

## HDFC Bank
- **Header:** AD-HDFCBK
- **Sample:** `Alert: You've spent Rs. 500.00 at Zomato on 2024-04-19. Transaction ID: 12345.`
- **Pattern:** `Rs\.?\s?([0-9,]+\.?[0-9]*)\s?at\s?(.*?)\son`

## ICICI Bank
- **Header:** VM-ICICIB
- **Sample:** `Dear Customer, your Acct XX123 is debited for INR 1,250.00 on 19-Apr-24. Info: VPS*Swiggy.`
- **Pattern:** `INR\s?([0-9,]+\.?[0-9]*)\s?on.*?Info:\s?(.*)`

## SBI (State Bank of India)
- **Header:** AX-SBIUPI
- **Sample:** `Transaction of Rs. 200.00 on SBI UPI with Ref No 1234567890 to Amazon.`
- **Pattern:** `Rs\.?\s?([0-9,]+\.?[0-9]*)\son.*?to\s?(.*)`

## Axis Bank
- **Header:** AX-AXISBK
- **Sample:** `Axis Bank: INR 350.00 debited from Acct XX999 on 19/04/24 for UPI/P2M/Uber/12345.`
- **Pattern:** `INR\s?([0-9,]+\.?[0-9]*)\sdebited.*?for\s?UPI/P2M/(.*?)/`

## Standard Keyword Extraction
If regex fails, look for these keywords to identify the merchant:
- `at [MERCHANT]`
- `to [MERCHANT]`
- `for [MERCHANT]`
- `Info: [MERCHANT]`
