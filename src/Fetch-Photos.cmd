@echo off
title Touch POS - download customer pictures
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fetch-photos.ps1"
pause
