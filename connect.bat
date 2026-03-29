@echo off
:: =========================================================
:: kOS Telnet Connection
:: Edit KOS_HOST and KOS_PORT to match your setup
:: =========================================================

SET KOS_HOST=127.0.0.1
SET KOS_PORT=5410

:: plink gives both interactive terminal AND piped I/O for scripted access
"C:\Program Files\PuTTY\plink.exe" -telnet %KOS_HOST% -P %KOS_PORT%
