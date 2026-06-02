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

if (-not (Test-Path -LiteralPath $backupAsar)) {
    throw "Original app.asar backup was not found: $backupAsar"
}

$python = (Get-Command python.exe -ErrorAction Stop).Source
& $python (Join-Path $projectRoot "skills\sync_codex_zh_map.py") --codex-home $CodexHome --out $mapPath

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

Remove-Item -LiteralPath $targetAsar -Force
npx --yes asar pack $extractRoot $targetAsar --unpack "**/*.node"
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
