param(
    [string]$TargetRoot = "${env:LOCALAPPDATA}\OpenAI\Codex-zh",
    [string]$CodexHome = "$HOME\.codex"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetAppRoot = Get-ChildItem -LiteralPath $TargetRoot -Directory -ErrorAction Stop |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $targetAppRoot) {
    throw "Codex localized copy was not found. Run install_codex_zh.ps1 first."
}

$targetResources = Join-Path $targetAppRoot.FullName "resources"
$backupAsar = Join-Path $targetResources "app.asar.original"
$targetAsar = Join-Path $targetResources "app.asar"
$workRoot = Join-Path $env:TEMP ("codex-zh-refresh-" + [Guid]::NewGuid().ToString("N"))
$extractRoot = Join-Path $workRoot "app"
$toolDir = Join-Path $CodexHome "tools\codex-chinese"
$mapPath = Join-Path $toolDir "codex-zh-map.json"
$nativeMenuMapPath = Join-Path $toolDir "codex-native-menu-zh.json"

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

if (-not (Test-Path -LiteralPath $backupAsar)) {
    throw "Original app.asar backup was not found: $backupAsar"
}

$running = Get-RunningLocalizedCopyProcesses -PathPrefix $targetAppRoot.FullName
if ($running.Count -gt 0) {
    Write-Output "Codex localized copy is still running. Close it, then run this refresh again."
    $running | Select-Object Name,ProcessId,ExecutablePath | Format-Table -AutoSize
    throw "Cannot refresh the localized copy while app.asar is in use."
}

$python = (Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $projectRoot "skills\sync_codex_zh_map.py") --codex-home $CodexHome --out $mapPath
if ($LASTEXITCODE -ne 0) {
    throw "Display localization map generator failed with exit code $LASTEXITCODE"
}

npx --yes asar extract $targetAsar $extractRoot
$webviewDir = Join-Path $extractRoot "webview"
$indexHtml = Join-Path $webviewDir "index.html"
Copy-Item -LiteralPath (Join-Path $projectRoot "desktop\skill-display-patch.js") -Destination (Join-Path $webviewDir "codex-zh-patch.js") -Force
Copy-Item -LiteralPath $mapPath -Destination (Join-Path $webviewDir "codex-zh-map.json") -Force

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

& $python (Join-Path $projectRoot "skills\sync_codex_native_menu_zh.py") --app-root $extractRoot --out $nativeMenuMapPath
if ($LASTEXITCODE -ne 0) {
    throw "Native menu localization generator failed with exit code $LASTEXITCODE"
}

Remove-Item -LiteralPath $targetAsar -Force
npx --yes asar pack $extractRoot $targetAsar --unpack "**/*.node"
$verify = npx --yes asar list $targetAsar | Select-String -Pattern 'webview\\codex-zh-patch\.js|webview\\codex-zh-map\.json|native-menu-locales\\zh-CN\.json|native-menu-locales\\codex-native-menu-zh\.json'
if (@($verify).Count -lt 4) {
    throw "Refreshed localized copy app.asar verification failed."
}
if (Test-Path -LiteralPath $workRoot) {
    $emptyDir = Join-Path $env:TEMP ("codex-zh-empty-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $emptyDir | Out-Null
    robocopy $emptyDir $workRoot /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "robocopy cleanup failed with exit code $LASTEXITCODE"
    }
    Remove-Item -LiteralPath $emptyDir -Recurse -Force
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "Codex localization map has been refreshed: $targetAsar"
