param(
    [string]$BackupRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh-backups",
    [switch]$NoAutoElevate
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-CodexAppRoot {
    $appx = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $appx -or -not $appx.InstallLocation) {
        throw "OpenAI.Codex installation was not found."
    }
    $candidate = Join-Path $appx.InstallLocation "app"
    if (-not (Test-Path -LiteralPath (Join-Path $candidate "resources\app.asar"))) {
        throw "Codex app.asar was not found."
    }
    return [pscustomobject]@{
        AppRoot = $candidate
        PackageFullName = $appx.PackageFullName
    }
}

function Get-RunningCodexProcesses {
    param([string]$AppRoot)
    $prefix = [System.IO.Path]::GetFullPath($AppRoot).TrimEnd('\') + "\"
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and $_.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
    })
}

function Grant-AdministratorsWrite {
    param([string]$Path)
    takeown.exe /F $Path /A | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "takeown failed for $Path with exit code $LASTEXITCODE"
    }
    icacls.exe $Path /grant "*S-1-5-32-544:F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "icacls grant failed for $Path with exit code $LASTEXITCODE"
    }
}

$resolved = Resolve-CodexAppRoot
$appRoot = $resolved.AppRoot
$asarPath = Join-Path $appRoot "resources\app.asar"
$backupAsar = Join-Path (Join-Path $BackupRoot $resolved.PackageFullName) "app.asar.original"

if (-not (Test-Path -LiteralPath $backupAsar)) {
    throw "Original backup was not found: $backupAsar"
}

$running = Get-RunningCodexProcesses -AppRoot $appRoot
if ($running.Count -gt 0) {
    Write-Output "Codex is still running from the official app directory."
    $running | Select-Object ProcessName,Id,MainWindowTitle,Path | Format-Table -AutoSize
    throw "Close Codex completely, then run this script again. The script will not stop Codex automatically."
}

if (-not (Test-IsAdmin)) {
    if ($NoAutoElevate) {
        throw "Administrator privileges are required to restore WindowsApps."
    }
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-BackupRoot", "`"$BackupRoot`""
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
    Write-Output "Started elevated restorer. Approve the UAC prompt."
    exit 0
}

try {
    Copy-Item -LiteralPath $backupAsar -Destination $asarPath -Force
} catch {
    Grant-AdministratorsWrite -Path $asarPath
    Copy-Item -LiteralPath $backupAsar -Destination $asarPath -Force
}

$verify = npx --yes asar list $asarPath | Select-String -Pattern 'webview\\codex-zh-patch\.js|webview\\codex-zh-map\.json'
if (@($verify).Count -gt 0) {
    throw "Restore verification failed: localization files are still present."
}

Write-Output "Codex official app.asar was restored from backup."
Write-Output "Restored from: $backupAsar"
