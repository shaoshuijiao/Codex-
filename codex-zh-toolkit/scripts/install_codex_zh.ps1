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

function Get-LocalizedShortcutName {
    return ("Codex " + [string]([char]0x4E2D) + [string]([char]0x6587) + [string]([char]0x7248) + ".lnk")
}

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
$nativeMenuScriptPath = Join-Path $toolDir "sync_codex_native_menu_zh.py"
$nativeMenuMapPath = Join-Path $toolDir "codex-native-menu-zh.json"

Ensure-Dir $TargetRoot
Ensure-Dir $toolDir

if ((Test-Path -LiteralPath $targetAppRoot) -and $ForceRefresh) {
    $running = Get-RunningLocalizedCopyProcesses -PathPrefix $targetAppRoot
    if ($running.Count -gt 0) {
        Write-Output "Codex localized copy is still running. Close it, then run this installer again."
        $running | Select-Object Name,ProcessId,ExecutablePath | Format-Table -AutoSize
        throw "Cannot refresh the localized copy while app.asar is in use."
    }
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
Copy-Item -LiteralPath (Join-Path $projectRoot "skills\sync_codex_native_menu_zh.py") -Destination $nativeMenuScriptPath -Force

$python = (Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $toolDir "sync_codex_zh_map.py") --codex-home $CodexHome --out $mapPath
if ($LASTEXITCODE -ne 0) {
    throw "Display localization map generator failed with exit code $LASTEXITCODE"
}

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

& $python $nativeMenuScriptPath --app-root $extractRoot --out $nativeMenuMapPath
if ($LASTEXITCODE -ne 0) {
    throw "Native menu localization generator failed with exit code $LASTEXITCODE"
}

if (Test-Path -LiteralPath $targetAsar) {
    Remove-Item -LiteralPath $targetAsar -Force
}
npx --yes asar pack $extractRoot $targetAsar --unpack "**/*.node"

$verify = npx --yes asar list $targetAsar | Select-String -Pattern 'webview\\codex-zh-patch\.js|webview\\codex-zh-map\.json|native-menu-locales\\zh-CN\.json|native-menu-locales\\codex-native-menu-zh\.json'
if (@($verify).Count -lt 4) {
    throw "Localized copy app.asar verification failed."
}

$launcher = Join-Path $TargetRoot "Start-Codex-zh.cmd"
$exe = Join-Path $targetAppRoot "Codex.exe"
@"
@echo off
start "" "$exe"
"@ | Set-Content -LiteralPath $launcher -Encoding ASCII

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop (Get-LocalizedShortcutName)
$legacyShortcutPath = Join-Path $desktop "Codex-ZH.lnk"
if (Test-Path -LiteralPath $legacyShortcutPath) {
    Remove-Item -LiteralPath $legacyShortcutPath -Force
}
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exe
$shortcut.WorkingDirectory = $targetAppRoot
$shortcut.Description = "Codex Chinese localized copy"
$shortcut.IconLocation = "$exe,0"
$shortcut.Save()

Remove-TreeRobust -Path $workRoot -AllowedRoot $env:TEMP

Write-Output "Codex localized copy is ready."
Write-Output "Launcher: $launcher"
Write-Output "Desktop shortcut: $shortcutPath"
Write-Output "Original app.asar backup: $backupAsar"
