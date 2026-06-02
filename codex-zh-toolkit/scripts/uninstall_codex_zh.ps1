param(
    [string]$TargetRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh",
    [string]$CodexHome = "$HOME\.codex"
)

$ErrorActionPreference = "Stop"

Get-Process | Where-Object {
    $_.Path -and $_.Path.StartsWith($TargetRoot, [System.StringComparison]::OrdinalIgnoreCase)
} | Stop-Process -Force

if (Test-Path -LiteralPath $TargetRoot) {
    Remove-Item -LiteralPath $TargetRoot -Recurse -Force
}

$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex-ZH.lnk"
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

$toolDir = Join-Path $CodexHome "tools\codex-chinese"
if (Test-Path -LiteralPath $toolDir) {
    Remove-Item -LiteralPath $toolDir -Recurse -Force
}

Write-Output "Codex localized copy and tool files were removed. Original Codex was not modified."
