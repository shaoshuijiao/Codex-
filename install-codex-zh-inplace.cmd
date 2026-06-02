@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0codex-zh-toolkit\scripts\launch_install_codex_zh_inplace.ps1"

echo.
echo Codex in-place Chinese localization installer
echo.
echo 1. A PowerShell window will open and wait for Codex to close.
echo 2. Close Codex completely.
echo 3. If Windows asks for administrator permission, click Yes.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%"

echo.
echo The waiting installer window has been opened.
echo If that window reports success, open the original Codex icon again.
echo.
pause
