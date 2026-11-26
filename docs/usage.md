# Touch POS usage

Touch POS needs Windows 10 or 11. It opens in its own window and works without internet, except for downloading customer pictures.

## Test it without installing
Run src\Start-TouchPOS.cmd. Add the word kiosk after it for full screen. If Touch POS has never been installed, its data is kept in src\Data, so testing this way doesn't touch an installed copy. Once it is installed, both use the shared data in C:\ProgramData\TouchPOS.

## First run
It asks you to create the first administrator: your name, an optional email, and a PIN of 4 to 8 digits. Add sales staff afterwards in Admin.

## Install
Run the newest installer in dist, for example Setup-TouchPOS-1.4.0.cmd. Older versions stay in dist, so you can go back to one. Windows asks for administrator permission. It installs to Program Files\Touch POS for all users and makes desktop and Start menu shortcuts. Running it again offers update, which keeps your data, or uninstall.

## Build the installer
After changing anything in src, rebuild the installer:
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Setup.ps1
It writes dist\Setup-TouchPOS-<version>.cmd, taking the version from installer_exe.ps1. Change the version there (and APPVER in index.html) before building a new release.

## Using it
The full guide is in src\README.txt. The list of every feature is in docs\features.md.

## Customer database and import
All data is kept in a SQLite database, touchpos.db, in C:\ProgramData\TouchPOS (or src\Data when testing without installing). A hidden helper looks after it and starts with Touch POS, so always start Touch POS from its shortcut or Start-TouchPOS.cmd. Opening index.html directly shows a warning that the database is not running.

To import customers: administrator area, Import and export, Choose file, then pick a .csv or .json list and choose Merge or Replace. Picture web addresses in the file (columns such as photo_url, picture or image) download straight away and are stored in the database. The Customer pictures box shows how many customers have a stored picture, and has buttons to retry. If something goes wrong, the helper writes helper.log next to the database.

## Where files go
Receipts, backups and exports are saved to C:\ProgramData\TouchPOS\Files unless changed in Settings, under Where to save files.
