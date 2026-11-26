# Touch POS usage

Touch POS needs Windows 10 or 11. It opens in its own window and works without internet, except for downloading customer pictures.

## Running without installing
Put the app folder (with its lib folder), icon.ico and the .cmd, .ps1 and README files in one folder, then run Start-TouchPOS.cmd. In this project that folder is src. icon.ico must be added first; see docs\handoff.md.

## Installing
Run the setup file. Running setup again offers update or uninstall, and updating keeps all data.

## Using it
The full guide for the selling page, screen and zoom, locking, two monitors, files and the override code is in src\README.txt.

## Where files go
Receipts, backups and exports are saved to C:\ProgramData\TouchPOS\Files unless changed in Settings, under Where to save files.
