param(
    [string]$CodexHome = "$HOME\.codex",
    [string]$BackupRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh-backups",
    [switch]$PrepareOnly,
    [switch]$NoAutoElevate
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Resolve-CodexAppRoot {
    $appx = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($appx -and $appx.InstallLocation) {
        $candidate = Join-Path $appx.InstallLocation "app"
        if (Test-Path -LiteralPath (Join-Path $candidate "resources\app.asar")) {
            return [pscustomobject]@{
                AppRoot = $candidate
                PackageFullName = $appx.PackageFullName
                Version = [string]$appx.Version
            }
        }
    }

    $processRoot = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -eq "Codex" -and $_.Path -and $_.Path -like "*\OpenAI.Codex_*\app\Codex.exe" } |
        Select-Object -First 1 |
        ForEach-Object { Split-Path -Parent $_.Path }

    if ($processRoot -and (Test-Path -LiteralPath (Join-Path $processRoot "resources\app.asar"))) {
        $packageName = Split-Path -Leaf (Split-Path -Parent $processRoot)
        return [pscustomobject]@{
            AppRoot = $processRoot
            PackageFullName = $packageName
            Version = "unknown"
        }
    }

    throw "OpenAI.Codex installation was not found."
}

function Assert-SafeCodexPath {
    param([string]$AppRoot)
    $full = [System.IO.Path]::GetFullPath($AppRoot)
    if ($full -notlike "C:\Program Files\WindowsApps\OpenAI.Codex_*\app") {
        throw "Refusing to patch unexpected app root: $full"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $full "resources\app.asar"))) {
        throw "Codex app.asar was not found under: $full"
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

function Inject-CodexZh {
    param(
        [string]$SourceAsar,
        [string]$OutputAsar,
        [string]$MapPath,
        [string]$PatchPath
    )

    $workRoot = Join-Path $env:TEMP ("codex-zh-inplace-" + [Guid]::NewGuid().ToString("N"))
    $extractRoot = Join-Path $workRoot "app"
    try {
        Ensure-Dir $extractRoot
        npx --yes asar extract $SourceAsar $extractRoot

        $webviewDir = Join-Path $extractRoot "webview"
        $indexHtml = Join-Path $webviewDir "index.html"
        if (-not (Test-Path -LiteralPath $indexHtml)) {
            throw "webview\index.html was not found after extracting app.asar."
        }

        Copy-Item -LiteralPath $PatchPath -Destination (Join-Path $webviewDir "codex-zh-patch.js") -Force
        Copy-Item -LiteralPath $MapPath -Destination (Join-Path $webviewDir "codex-zh-map.json") -Force

        $html = Get-Content -LiteralPath $indexHtml -Raw -Encoding UTF8
        if ($html -notmatch 'codex-zh-patch\.js') {
            $insert = '    <script src="./codex-zh-patch.js"></script>' + "`r`n"
            $idx = $html.IndexOf('    <script type="module"')
            if ($idx -lt 0) {
                $idx = $html.IndexOf('</head>')
            }
            if ($idx -lt 0) {
                throw "Codex webview script injection point was not found."
            }
            $html = $html.Insert($idx, $insert)
            Set-Content -LiteralPath $indexHtml -Value $html -Encoding UTF8
        }

        if (Test-Path -LiteralPath $OutputAsar) {
            Remove-Item -LiteralPath $OutputAsar -Force
        }
        npx --yes asar pack $extractRoot $OutputAsar --unpack "**/*.node"
    } finally {
        if (Test-Path -LiteralPath $workRoot) {
            $emptyDir = Join-Path $env:TEMP ("codex-zh-empty-" + [Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Force -Path $emptyDir | Out-Null
            robocopy $emptyDir $workRoot /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            Remove-Item -LiteralPath $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolved = Resolve-CodexAppRoot
$appRoot = $resolved.AppRoot
Assert-SafeCodexPath -AppRoot $appRoot

$asarPath = Join-Path $appRoot "resources\app.asar"
$backupDir = Join-Path $BackupRoot $resolved.PackageFullName
$toolDir = Join-Path $CodexHome "tools\codex-chinese"
$mapPath = Join-Path $toolDir "codex-zh-map.json"
$patchPath = Join-Path $toolDir "skill-display-patch.js"
$stagedAsar = Join-Path $backupDir "app.asar.patched"
$backupAsar = Join-Path $backupDir "app.asar.original"

Ensure-Dir $backupDir
Ensure-Dir $toolDir
Copy-Item -LiteralPath (Join-Path $projectRoot "desktop\skill-display-patch.js") -Destination $patchPath -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "skills\sync_codex_zh_map.py") -Destination (Join-Path $toolDir "sync_codex_zh_map.py") -Force

$python = (Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $toolDir "sync_codex_zh_map.py") --codex-home $CodexHome --out $mapPath

if (-not (Test-Path -LiteralPath $backupAsar)) {
    Copy-Item -LiteralPath $asarPath -Destination $backupAsar -Force
}

Inject-CodexZh -SourceAsar $asarPath -OutputAsar $stagedAsar -MapPath $mapPath -PatchPath $patchPath

$verify = npx --yes asar list $stagedAsar | Select-String -Pattern 'webview\\codex-zh-patch\.js|webview\\codex-zh-map\.json'
if (@($verify).Count -lt 2) {
    throw "Patched app.asar verification failed."
}

if ($PrepareOnly) {
    Write-Output "Prepared patched app.asar only."
    Write-Output "Patched asar: $stagedAsar"
    Write-Output "Original backup: $backupAsar"
    exit 0
}

$running = Get-RunningCodexProcesses -AppRoot $appRoot
if ($running.Count -gt 0) {
    Write-Output "Codex is still running from the official app directory."
    $running | Select-Object ProcessName,Id,MainWindowTitle,Path | Format-Table -AutoSize
    throw "Close Codex completely, then run this script again. The script will not stop Codex automatically."
}

if (-not (Test-IsAdmin)) {
    if ($NoAutoElevate) {
        throw "Administrator privileges are required to patch WindowsApps."
    }
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-CodexHome", "`"$CodexHome`"",
        "-BackupRoot", "`"$BackupRoot`""
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
    Write-Output "Started elevated installer. Approve the UAC prompt."
    exit 0
}

try {
    Copy-Item -LiteralPath $stagedAsar -Destination $asarPath -Force
} catch {
    Grant-AdministratorsWrite -Path $asarPath
    Copy-Item -LiteralPath $stagedAsar -Destination $asarPath -Force
}

$installedVerify = npx --yes asar list $asarPath | Select-String -Pattern 'webview\\codex-zh-patch\.js|webview\\codex-zh-map\.json'
if (@($installedVerify).Count -lt 2) {
    throw "Installed app.asar verification failed."
}

Write-Output "Codex official app.asar was patched in place."
Write-Output "Original backup: $backupAsar"
