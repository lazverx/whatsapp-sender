@echo off
title WhatsApp Auto Sender
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================================
echo           MEMULAI WHATSAPP AUTO SENDER...
echo ============================================================
echo.

if not exist "%~dp0kirim_wa.ps1" (
    echo [ERROR] File "kirim_wa.ps1" tidak ditemukan di folder:
    echo %~dp0
    echo Pastikan file kirim_wa.bat dan kirim_wa.ps1 berada di folder yang sama!
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kirim_wa.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [INFO] Program dihentikan atau keluar dengan kode: %ERRORLEVEL%
)

echo.
echo Tekan tombol apa saja untuk menutup jendela ini...
pause >nul
