@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0codex-zh-toolkit\scripts\launch_install_codex_zh_copy.ps1"

echo.
echo Codex Chinese localized copy installer
echo.
echo This creates or updates a separate local copy under:
echo   %LOCALAPPDATA%\OpenAI\Codex-zh
echo.
echo The official Store Codex installation will not be modified.
echo If Codex is open from the Chinese shortcut, the updater will wait.
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%"

echo.
echo If the PowerShell window reports success, open the desktop shortcut:
echo   Codex Chinese Version
echo.
pause
