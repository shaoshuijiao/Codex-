@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0codex-zh-toolkit\scripts\install_codex_zh_inplace.ps1"

echo.
echo Codex in-place Chinese localization installer
echo.
echo 1. Close Codex completely first.
echo 2. Return to this window and press any key.
echo 3. If Windows asks for administrator permission, click Yes.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','%SCRIPT%'"

echo.
echo The administrator installer window has been opened.
echo If that window reports success, open the original Codex icon again.
echo.
pause
