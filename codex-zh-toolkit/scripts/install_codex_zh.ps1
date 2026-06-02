param(
    [string]$SourceAppRoot,
    [string]$TargetRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh",
    [string]$CodexHome = "$HOME\.codex",
    [switch]$ForceRefresh
)

$ErrorActionPreference = "Stop"

function Resolve-CodexAppRoot {
    if ($SourceAppRoot) {
        return (Resolve-Path -LiteralPath $SourceAppRoot).Path
    }

    $processRoot = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -eq "Codex" -and $_.Path -and $_.Path -like "*\OpenAI.Codex_*\app\Codex.exe" } |
        Select-Object -First 1 |
        ForEach-Object { Split-Path -Parent $_.Path }

    if ($processRoot -and (Test-Path -LiteralPath (Join-Path $processRoot "resources\app.asar"))) {
        return $processRoot
    }

    $appx = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($appx -and $appx.InstallLocation) {
        $appRoot = Join-Path $appx.InstallLocation "app"
        if (Test-Path -LiteralPath (Join-Path $appRoot "resources\app.asar")) {
            return $appRoot
        }
    }

    $packageRoot = Get-ChildItem -LiteralPath "C:\Program Files\WindowsApps" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "OpenAI.Codex_*_x64__2p2nqsd0c76g0" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $packageRoot) {
        throw "OpenAI.Codex WindowsApps app directory was not found."
    }

    $appRoot = Join-Path $packageRoot.FullName "app"
    if (-not (Test-Path -LiteralPath (Join-Path $appRoot "resources\app.asar"))) {
        throw "Codex app.asar was not found: $appRoot"
    }
    return $appRoot
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Remove-TreeRobust {
    param(
        [string]$Path,
        [string]$AllowedRoot
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullAllowedRoot = [System.IO.Path]::GetFullPath($AllowedRoot)
    if (-not $fullPath.StartsWith($fullAllowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside allowed root: $fullPath"
    }
    $emptyDir = Join-Path $env:TEMP ("codex-zh-empty-" + [Guid]::NewGuid().ToString("N"))
    Ensure-Dir $emptyDir
    robocopy $emptyDir $fullPath /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "robocopy cleanup failed with exit code $LASTEXITCODE"
    }
    Remove-Item -LiteralPath $emptyDir -Recurse -Force
    Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Resolve-CodexAppRoot
$sourceVersion = Split-Path -Leaf (Split-Path -Parent $sourceRoot)
$targetAppRoot = Join-Path $TargetRoot $sourceVersion
$targetResources = Join-Path $targetAppRoot "resources"
$targetAsar = Join-Path $targetResources "app.asar"
$backupAsar = Join-Path $targetResources "app.asar.original"
$workRoot = Join-Path $env:TEMP ("codex-zh-asar-" + [Guid]::NewGuid().ToString("N"))
$extractRoot = Join-Path $workRoot "app"
$toolDir = Join-Path $CodexHome "tools\codex-chinese"
$mapPath = Join-Path $toolDir "codex-zh-map.json"

Ensure-Dir $TargetRoot
Ensure-Dir $toolDir

if ((Test-Path -LiteralPath $targetAppRoot) -and $ForceRefresh) {
    Remove-TreeRobust -Path $targetAppRoot -AllowedRoot $TargetRoot
}

if (-not (Test-Path -LiteralPath $targetAppRoot)) {
    Write-Output "Copying Codex app to localized copy: $targetAppRoot"
    Ensure-Dir $targetAppRoot
    robocopy $sourceRoot $targetAppRoot /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "robocopy failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $backupAsar)) {
    Copy-Item -LiteralPath $targetAsar -Destination $backupAsar -Force
}

Copy-Item -LiteralPath (Join-Path $projectRoot "desktop\skill-display-patch.js") -Destination (Join-Path $toolDir "skill-display-patch.js") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "skills\sync_codex_zh_map.py") -Destination (Join-Path $toolDir "sync_codex_zh_map.py") -Force

$python = (Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $toolDir "sync_codex_zh_map.py") --codex-home $CodexHome --out $mapPath

Ensure-Dir $extractRoot
npx --yes asar extract $targetAsar $extractRoot

$webviewDir = Join-Path $extractRoot "webview"
$indexHtml = Join-Path $webviewDir "index.html"
if (-not (Test-Path -LiteralPath $indexHtml)) {
    throw "webview\index.html was not found after extracting app.asar."
}

Copy-Item -LiteralPath (Join-Path $toolDir "skill-display-patch.js") -Destination (Join-Path $webviewDir "codex-zh-patch.js") -Force
Copy-Item -LiteralPath $mapPath -Destination (Join-Path $webviewDir "codex-zh-map.json") -Force

$html = Get-Content -LiteralPath $indexHtml -Raw -Encoding UTF8
if ($html -notmatch 'codex-zh-patch\.js') {
    $insert = '    <script src="./codex-zh-patch.js"></script>' + "`r`n"
    $needle = '    <script type="module"'
    $idx = $html.IndexOf($needle)
    if ($idx -lt 0) {
        $needle = '</head>'
        $idx = $html.IndexOf($needle)
    }
    if ($idx -lt 0) {
        throw "Codex webview script injection point was not found: $indexHtml"
    }
    $html = $html.Insert($idx, $insert)
    Set-Content -LiteralPath $indexHtml -Value $html -Encoding UTF8
}

if (Test-Path -LiteralPath $targetAsar) {
    Remove-Item -LiteralPath $targetAsar -Force
}
npx --yes asar pack $extractRoot $targetAsar --unpack "**/*.node"

$launcher = Join-Path $TargetRoot "Start-Codex-zh.cmd"
$exe = Join-Path $targetAppRoot "Codex.exe"
@"
@echo off
start "" "$exe"
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Codex-ZH.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exe
$shortcut.WorkingDirectory = $targetAppRoot
$shortcut.Description = "Codex Chinese localized copy"
$shortcut.Save()

Remove-TreeRobust -Path $workRoot -AllowedRoot $env:TEMP

Write-Output "Codex localized copy is ready."
Write-Output "Launcher: $launcher"
Write-Output "Desktop shortcut: $shortcutPath"
Write-Output "Original app.asar backup: $backupAsar"
