# Touch POS: summary of all requests so far

Written 2026-11-26 from the code of version 1.3.0, because the original chat was not available. Each item is something that was asked for and is built into the program. Nothing was found half built.

## Setup and sign in
- First run creates the first administrator: name, optional email, and a PIN of 4 to 8 digits.
- Sales staff are added in Admin. Each gets their own QR or NFC credential.
- Sign in with a PIN or by scanning a credential. Correct codes are accepted without pressing OK.
- Admin access: touch the club logo, then enter a PIN or scan a credential.
- Inactivity lock after the idle time set in Settings. Unlock with the operator's PIN or credential.
- Forgot PIN emails an administrator, who can issue a temporary PIN.

## Selling page
- Product search, and a layout each sales person arranges their own way: move cards with arrows, or Free layout to drag cards anywhere.
- Several people on one order with Add person, or by scanning another credential. Each person gets their own receipt, and the buyer also gets one listing what they bought for others.
- Quantity number pad, and press and hold.
- Customers who need supervision can buy only 1 box at a time: products ticked as box items, or any product if that setting is on.
- Per-transaction limits that tighten as stock falls, with a warning.
- Override code (2 to 8 digits) to allow more, for one customer or for everyone until turned off, with a red reminder bar while on. It also protects permanent deletion.
- Credential scanning: USB scanners or readers that type the code, camera QR scanning, and Web NFC where available.

## Customers
- Customer profiles with photos taken by camera or chosen from a file.
- Sales history per customer, spend summaries, and purchases made for other people.
- Tags, supervision, and an 8 ring qualification with date and sign-off by name.
- Phone wallet passes: Apple Wallet pass files (unsigned, need signing with an Apple Developer certificate), with an optional NFC entry.
- Customer pictures downloaded from web addresses or a folder (inside the app, and with the Fetch Pictures helper).

## Products and stock
- Products with price, stock, reorder level, category and picture.
- Multi-unit packs drawing from one shared stock pool.
- Stock forecast based on opening hours and an opening calendar.
- Stock alert emails to the manager.
- Deleted products move to Historic products and stay on past receipts.

## Sales, receipts and reports
- Every transaction gets its own numbered receipt, saved automatically as a PDF.
- Sales history by quarter, with grouping, sorting, selection and PDF email.
- Revenue line chart, money on the up-and-down axis and dates along the bottom.
- Today's takings on the Sales page, and permanent sale deletion behind the override code.

## Data
- Version 1.4.0: everything is stored in a SQLite database (touchpos.db) through a hidden helper, with customer pictures stored in the database.
- Customer import from CSV or JSON downloads picture web addresses straight away and stores them.
- Full backup as JSON, customers with photos as ZIP, products and sales as CSV.
- Import a full backup, a customer ZIP, or a products or customers list (CSV or JSON), choosing merge or replace first.
- Automatic daily backup.
- Settings for where receipts, backups and exports are saved. Default folder C:\ProgramData\TouchPOS\Files.

## Screen and hardware
- Zoom with A- and A+ buttons, Ctrl plus mouse wheel, Ctrl plus or minus, or pinch.
- On-screen keyboard.
- Full screen kiosk mode, and a Lock button.
- Two monitors: choose which monitor Touch POS opens on and which one shows the customer display. The second screen is a large read-only customer display that follows the till.
- Scroll bars hidden, toolbars stay in place, Escape closes a box, Enter does the main action.

## Windows program
- Runs offline in its own window using the Edge engine built into Windows (Chrome as a fallback). Works on 32-bit and 64-bit Windows 10 and 11.
- Installer for all users: program in Program Files\Touch POS, shared data in ProgramData\TouchPOS, desktop and Start menu shortcuts (normal, kiosk, Fetch Pictures, Uninstall), and an entry in Settings, Apps.
- Running setup again offers update (keeps data) or uninstall.
