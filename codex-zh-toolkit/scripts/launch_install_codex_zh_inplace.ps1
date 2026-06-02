param(
    [string]$CodexHome = "$HOME\.codex",
    [string]$BackupRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh-backups"
)

$ErrorActionPreference = "Stop"

function Resolve-CodexAppRoot {
    $appx = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($appx -and $appx.InstallLocation) {
        $candidate = Join-Path $appx.InstallLocation "app"
        if (Test-Path -LiteralPath (Join-Path $candidate "resources\app.asar")) {
            return $candidate
        }
    }

    $processRoot = Get-CimInstance Win32_Process -Filter "Name = 'Codex.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath -like "*\OpenAI.Codex_*\app\Codex.exe" } |
        Select-Object -First 1 |
        ForEach-Object { Split-Path -Parent $_.ExecutablePath }

    if ($processRoot -and (Test-Path -LiteralPath (Join-Path $processRoot "resources\app.asar"))) {
        return $processRoot
    }

    throw "OpenAI.Codex installation was not found."
}

function Get-RunningOfficialCodex {
    param([string]$AppRoot)
    $prefix = [System.IO.Path]::GetFullPath($AppRoot).TrimEnd('\') + "\"
    return @(Get-CimInstance Win32_Process -Filter "Name = 'Codex.exe' OR Name = 'codex.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -and $_.ExecutablePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                ProcessId = $_.ProcessId
                ExecutablePath = $_.ExecutablePath
            }
        })
}

$appRoot = Resolve-CodexAppRoot
$installer = Join-Path $PSScriptRoot "install_codex_zh_inplace.ps1"

Write-Output ""
Write-Output "Codex in-place Chinese localization launcher"
Write-Output "This window will wait until official Codex processes are closed."
Write-Output "Close all Codex windows now. Do not press anything here."
Write-Output ""

while ($true) {
    $running = Get-RunningOfficialCodex -AppRoot $appRoot
    if ($running.Count -eq 0) {
        break
    }

    Write-Output "Still waiting for Codex to close. Running official Codex processes:"
    $running | Select-Object Name,ProcessId,ExecutablePath | Format-Table -AutoSize
    Start-Sleep -Seconds 3
}

Write-Output "Codex is closed. Starting installer..."
& $installer -CodexHome $CodexHome -BackupRoot $BackupRoot
Write-Output ""
Write-Output "If an administrator window opened, approve it and read the result there."
