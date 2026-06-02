param(
    [string]$TargetRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh",
    [string]$CodexHome = "$HOME\.codex"
)

$ErrorActionPreference = "Stop"

function Get-RunningLocalizedCopyProcesses {
    param([string]$PathPrefix)
    $fullPrefix = [System.IO.Path]::GetFullPath($PathPrefix).TrimEnd('\') + "\"
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -and $_.ExecutablePath.StartsWith($fullPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                ProcessId = $_.ProcessId
                ExecutablePath = $_.ExecutablePath
            }
        })
}

$installer = Join-Path $PSScriptRoot "install_codex_zh.ps1"

Write-Output ""
Write-Output "Codex Chinese localized copy updater"
Write-Output "This window will wait until the localized Codex copy is closed."
Write-Output "Close all Codex windows that were opened from the Chinese shortcut."
Write-Output ""

while ($true) {
    $running = Get-RunningLocalizedCopyProcesses -PathPrefix $TargetRoot
    if ($running.Count -eq 0) {
        break
    }

    Write-Output "Still waiting for the localized Codex copy to close:"
    $running | Select-Object Name,ProcessId,ExecutablePath | Format-Table -AutoSize
    Start-Sleep -Seconds 3
}

Write-Output "Localized Codex copy is closed. Updating translations..."
& $installer -TargetRoot $TargetRoot -CodexHome $CodexHome -ForceRefresh
