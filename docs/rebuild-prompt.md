# Prompt: build a Touch POS style app from scratch

Written 2026-11-26 from the features of Touch POS 1.4.0. Copy everything below the line into a new chat.

---

Build a complete touch-screen point of sale program for Windows, for a members' club shop. Build all of it, not a demo, and give me every file plus the build steps.

## Fixed requirements (these must not change)

1. Standalone. It must run on Windows 10 and 11, both 32-bit and 64-bit, with nothing else to install: no runtime, framework, database server, web server or browser add-on. Anything it needs must ship inside its own installer, or already be part of Windows.
2. Offline. Everything works without internet. The only things that use the internet are downloading customer pictures from web addresses, creating phone wallet passes, and sending email.
3. One installer. It installs for all Windows users, with a program folder in Program Files and one shared data folder in ProgramData that every user can write to. It adds desktop and Start menu shortcuts (normal, full screen kiosk, and uninstall) and an entry in Windows Settings, Apps. Running the installer again offers to update, keeping all data, or to uninstall. Uninstall asks whether to keep the data. Each version's installer has its own file name that includes the version number.
4. Portable mode. The program can also run straight from its folder without installing, keeping its data in a Data folder beside it.
5. One local database. All data is kept in a single SQLite database file in the data folder: products, customers with their pictures stored inside the database, sales, staff, settings, layouts and devices. Saving must be reliable, with no silent failures and no size limits that a few thousand customers with pictures could reach. If saving fails, say so on screen.
6. Touch first, with a keyboard and mouse working too. Big buttons, no hover-only controls, and scroll bars hidden while lists still scroll and toolbars stay in place.

You may choose the programming language and toolkit. First tell me which one you chose and how it meets requirements 1 to 5, including how the SQLite engine is included, before writing the code.

## Staff and security

- First run creates the first administrator: name, optional email, and a PIN of 4 to 8 digits.
- Staff have the role Administrator or Sales. Administrators add, edit and remove staff.
- Each staff member and each customer gets a credential code shown as a QR code, which can also be written to an NFC tag.
- Sign in with a PIN or by scanning a credential. A correct code is accepted as soon as it is complete, without pressing OK.
- To reach the administrator area, touch the club logo, then enter an administrator PIN or scan an administrator credential. An Exit admin button leaves it.
- The till locks after an idle time set in Settings. Unlock with the PIN or credential of the person signed in. There is also a Lock button.
- Forgot PIN sends an email to an administrator, who can issue a temporary PIN that must be changed when first used.
- An override code of 2 to 8 digits, set by an administrator, unlocks limits and protects permanent deletion. Store PINs and codes as salted hashes, never as plain text.

## Selling page

- Product cards with picture, name, price and stock, grouped into categories with category tabs, and a search box.
- Each sales person arranges their own layout. In Arrange mode, cards move with arrow buttons, or with Free layout switched on, cards can be dragged anywhere.
- Choose the customer by scanning their credential, or by searching with Pick customer. Walk-in sales are allowed.
- Several people on one order: Add person, or scan another credential. Tap a person to add products for them. Everyone gets their own receipt, and the buyer also gets a receipt listing what they bought for the others.
- Set quantities with a number pad, and press and hold to repeat.
- Supervision: a customer marked as needing supervision can buy only 1 box item per transaction (products ticked as Box item, or any product if that setting is on). Entering the override code allows more, either for that customer or for everyone until it is turned off. A red bar stays on screen while the override for everyone is on.
- Per-transaction limits: administrators write rules that cap how many of a product one sale can contain, tightening as stock falls. Later rules override earlier ones. If a limit is hit, explain it and offer the override code.
- Take payment shows the total. Staff take the money in the till or on the card terminal, then tap how it was paid. Payment methods: cash as the default, linked card payment providers picked from a searchable list, and custom methods the administrator adds.
- Each completed sale gets its own numbered receipt, saved automatically as a PDF in the receipts folder, and it can be emailed.
- Recent purchases for the current customer are shown on the selling page.

## Customers

- Customer record: id, name, email, phone, notes, picture, tags, supervision status (requires supervision, or cleared, with who certified it and the date), and an 8 ring qualification with whether they qualified, who signed it off and the date.
- Pictures come from the camera, a file, or a web address, with a crop tool (drag to move, slider or plus and minus to zoom, showing exactly what will be kept). Store them square, about 400 by 400 pixels, as JPEG inside the database.
- The customer profile shows their sales history, a spend summary, and purchases made for other people.
- Administrators choose the customer card layout, including the picture size.
- Phone wallet passes: create a Google Wallet link for a customer's credential, using a service account entered in Settings, and email it to them. Also produce Apple Wallet pass files, unsigned, with instructions for signing them with an Apple Developer Pass Type ID certificate. There is an optional NFC entry. Private keys are kept on this computer only and never put in exports.
- Deleting a customer needs the override code, and can also delete their sales records if chosen.

## Customer import with pictures

- Import a customer list from CSV or JSON. Recognise common column names, case-insensitively: id, name, email, phone, notes, supervision, certified_by, certified_date, 8_ring_qualified, 8_ring_signed_by, 8_ring_date, and for the picture photo_url, photourl, picture, picture_url, image, image_url or photo.
- Before anything changes, show what was found and ask: Merge (add new customers and update matching ones, matched by id, then by email) or Replace.
- Straight after the import, download every picture web address in the file and store the picture in the database. Show progress (for example "12 of 240: Ann Smith") with a Stop button, then a summary of how many were saved and which failed, with a plain reason for each failure (site not reachable, the site answered 404, the address is a web page and not a picture, larger than 20 MB).
- Download the pictures from the program itself, not from a browser page, so websites cannot block it. Turn Google Drive and Dropbox share links into direct download links. Use TLS 1.2 or newer, a 20 second timeout and a 20 MB limit.
- Buttons to download missing pictures, download all again, and import pictures from a folder, matching each file to a customer by id, email or full name.
- Show how many customers are in the database and how many have a stored picture.

## Products and stock

- Product: name, description, category, price, stock, reorder level, picture, units per pack, maximum per sale, source (supplier), and Box item.
- Multi-unit packs take their stock from one shared stock pool.
- Move several products to a category at once.
- Deleted products go to Historic products and still appear on past receipts. Permanently deleting historic products needs the override code.
- Stock forecast: the average sold per open hour over the last 14 days (or since the first sale), projected across the opening days and hours and the closed dates. Show days of stock left, and a suggested order covering the next 14 days of opening.
- Settings for opening days and hours, and an opening calendar for closed dates and special hours.
- Stock alert email to the manager listing what needs reordering.

## Sales and reports

- Sales log with today's takings, sales by quarter, grouping, sorting, multi-select, and PDF export and email of the selection.
- Revenue line chart with money on the vertical axis and dates along the bottom.
- Permanently deleting a sale needs the override code.

## Data, backup and import

- Exports: a full backup (JSON with everything except private keys), customers with pictures (ZIP), products (CSV) and sales (CSV).
- Imports: a full backup, a customer ZIP, or a products or customers list (CSV or JSON). Always choose merge or replace first, and offer to restore settings and staff from a full backup.
- Automatic backup once a day, kept in the backups folder.
- Settings choose the folders for receipts, backups and exports. The default is a Files folder inside the data folder.
- Permanent deletion section, for administrators only, with each action needing the override code: delete all sales, all historic products, all customers, or erase everything and start setup again.
- A newer version moves data from an older version into its database automatically the first time it starts.

## Screen and hardware

- Zoom with A minus and A plus buttons, Ctrl plus mouse wheel, Ctrl plus or minus, and two-finger pinch. Remember the zoom level.
- Built-in on-screen keyboard that can be switched on.
- Full screen kiosk mode. Leaving full screen shows a cover saying "Touch the screen to return to full screen". Only an administrator can turn kiosk mode off. The kiosk shortcut starts in this mode.
- Two monitors: Detect monitors in Settings, then choose which monitor the till opens on and which one shows the customer display. The customer display is a large read-only window that follows the till: customer, picture, items and total.
- Readers: USB QR and barcode scanners and NFC readers that type the code like a keyboard, camera QR scanning, and pairing USB, HID or serial readers in a Paired devices list. Choose which camera to use.

## Settings

Store name, currency symbol, manager email, idle lock time, on-screen keyboard, monitors, folders, opening hours and calendar, payment methods, wallet pass settings, card layout, supervision rules, limit rules, override code, and kiosk start.

## Deliverables

1. All source files, the database layout (tables and columns), and the build script that makes the installer.
2. A readme for users covering install, update, uninstall, first run, selling, customers, importing with pictures, backups, two monitors, kiosk mode and the override code.
3. A short test list I can run to check every section above.
