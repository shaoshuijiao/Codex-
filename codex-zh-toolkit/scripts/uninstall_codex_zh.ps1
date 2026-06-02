param(
    [string]$TargetRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh",
    [string]$CodexHome = "$HOME\.codex"
)

$ErrorActionPreference = "Stop"

function Get-LocalizedShortcutName {
    return ("Codex " + [string]([char]0x4E2D) + [string]([char]0x6587) + [string]([char]0x7248) + ".lnk")
}

Get-Process | Where-Object {
    $_.Path -and $_.Path.StartsWith($TargetRoot, [System.StringComparison]::OrdinalIgnoreCase)
} | Stop-Process -Force

if (Test-Path -LiteralPath $TargetRoot) {
    Remove-Item -LiteralPath $TargetRoot -Recurse -Force
}

$desktop = [Environment]::GetFolderPath("Desktop")
foreach ($shortcutName in @((Get-LocalizedShortcutName), "Codex-ZH.lnk")) {
    $shortcutPath = Join-Path $desktop $shortcutName
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }
}

$toolDir = Join-Path $CodexHome "tools\codex-chinese"
if (Test-Path -LiteralPath $toolDir) {
    Remove-Item -LiteralPath $toolDir -Recurse -Force
}

Write-Output "Codex localized copy and tool files were removed. Original Codex was not modified."
