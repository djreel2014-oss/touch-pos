TOUCH POS FOR WINDOWS  (version 1.4.1)
======================================
Needs nothing except Windows 10 or 11 (32-bit or 64-bit). Opens in its own window using the
Microsoft Edge engine that is part of Windows. Works without internet (except downloading
customer pictures from web addresses).

INSTALL / UPDATE: run Setup-TouchPOS-1.4.1.cmd. Running Setup again offers update or uninstall.
Updating keeps all your data.

SELLING PAGE
  Search products, arrange them your own way (Arrange button: move with the arrows, or switch
  on Free layout and drag cards anywhere). Each sales person has their own layout.
  Several people on one order: use + Add person (or scan another credential). Tap a person to
  add products for them. Everyone gets their own receipt; the buyer also gets a receipt that lists
  what they bought for other people.
  A customer who requires supervision can buy only 1 box at a time (tick "Box item" on a product,
  or use the setting for any product). Enter the override code to allow more: for that customer,
  or for everyone until you turn it off (a red bar reminds you while it is on).

SCREEN
  A- / A+ buttons, Ctrl + mouse wheel, or pinch to zoom. The keyboard button shows an on-screen
  keyboard. Scroll bars are hidden; lists scroll, toolbars stay put. Esc closes a box, Enter does
  the main action. The till locks after the idle time set in Settings: unlock with your PIN
  (no OK needed) or your QR / NFC credential. Forgot PIN emails an administrator, who can issue a
  temporary PIN (Staff and credentials > Temp PIN).

TWO MONITORS
  Settings > Monitors > Detect monitors: choose which monitor Touch POS opens on and which one the
  customer display uses. "Second screen" on the customer card or profile opens a large display
  window that follows the till.

DATABASE AND CUSTOMER IMPORT
  All data (customers with their pictures, products, sales, staff and settings) is kept in a
  SQLite database: C:\ProgramData\TouchPOS\touchpos.db. A small hidden helper starts with
  Touch POS to look after it. Always start Touch POS from its shortcut so the helper runs.
  Import a customer list (.csv or .json) in the administrator area > Import and export. Picture
  web addresses in the file (columns such as Photo URL, photo_url, picture or image) are downloaded
  straight away and stored in the database. Google Drive and Dropbox share links work too.
  Column names are matched loosely: a name column, or First name and Last name, plus email, phone,
  mobile, address, status, nickname and a member number such as Hello Club id. Supervision comes
  from Shoot unaccompanied and Probationary safety, the 8 ring from 8-ring group signed off and
  Signed off by. Dates such as 14/05/2025 are read day first. Importing the same list again
  updates members (matched by member number or email) instead of adding them twice.
  Data from version 1.3.0 moves into the database by itself the first time 1.4.0 starts.

FILES
  Settings > Where to save files lets you choose folders for receipts, backups and exports.
  By default files go to C:\ProgramData\TouchPOS\Files. Receipts are saved automatically.

OVERRIDE CODE (2 to 8 digits): Settings. It also protects permanent deletion.
