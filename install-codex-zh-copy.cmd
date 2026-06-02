@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0codex-zh-toolkit\scripts\install_codex_zh.ps1"

echo.
echo Codex Chinese localized copy installer
echo.
echo This creates a separate local copy under:
echo   %LOCALAPPDATA%\OpenAI\Codex-zh
echo.
echo The official Store Codex installation will not be modified.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%" -ForceRefresh

echo.
echo If the PowerShell window reports success, open the desktop shortcut:
echo   Codex Chinese Version
echo.
pause
