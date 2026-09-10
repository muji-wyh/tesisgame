param(
    [Parameter(Mandatory = $true)][string]$Package,
    [string]$Mapping = (Join-Path $PSScriptRoot '..\docs\assets\unity-food-icons.mapping.json'),
    [switch]$InspectOnly,
    [string]$Python = 'python',
    [string]$UnityCli = (Join-Path $env:USERPROFILE '.local\bin\unity.exe'),
    [string]$EditorPath = 'C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$helper = Join-Path $PSScriptRoot 'unity-art-package.py'
$packagePath = (Resolve-Path -LiteralPath $Package).Path

if ($InspectOnly) {
    & $Python $helper inspect $packagePath
    if ($LASTEXITCODE -ne 0) { throw 'Unity package inspection failed.' }
    exit 0
}

if (!(Test-Path -LiteralPath $UnityCli -PathType Leaf)) { throw "Unity CLI not found: $UnityCli" }
if (!(Test-Path -LiteralPath $EditorPath -PathType Leaf)) { throw "Unity Editor not found: $EditorPath" }
$mappingPath = (Resolve-Path -LiteralPath $Mapping).Path
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$runDirectory = Join-Path $repoRoot "build\unity-art-import\$runId"
$preparedJson = & $Python $helper prepare $packagePath $mappingPath $runDirectory $repoRoot
if ($LASTEXITCODE -ne 0) { throw 'Unity artwork selection failed; no Editor was launched.' }
$prepared = ($preparedJson -join "`n") | ConvertFrom-Json
$staging = Join-Path $repoRoot "build\unity-asset-staging\$runId"
New-Item -ItemType Directory -Path (Join-Path $staging 'Assets'), (Join-Path $staging 'Packages'), (Join-Path $staging 'ProjectSettings') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $staging 'Packages\manifest.json') -Value '{"dependencies":{}}' -Encoding UTF8
$editorVersion = Split-Path (Split-Path (Split-Path $EditorPath -Parent) -Parent) -Leaf
Set-Content -LiteralPath (Join-Path $staging 'ProjectSettings\ProjectVersion.txt') -Value "m_EditorVersion: $editorVersion" -Encoding UTF8
$editorLog = Join-Path $runDirectory 'unity-import.log'
$editorArguments = @('run', $staging, '--editor-path', $EditorPath, '--timeout', '300', '--', '-batchmode', '-nographics', '-quit', '-importPackage', $prepared.art_package, '-logFile', $editorLog)
Write-Output "Importing selected PNGs with Unity CLI into $staging"
& $UnityCli @editorArguments
$editorExit = $LASTEXITCODE
@{ cli = $UnityCli; editor = $EditorPath; arguments = $editorArguments; exit_code = $editorExit; log = $editorLog } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory 'unity-command.json') -Encoding UTF8
if ($editorExit -ne 0) { throw "Unity import failed ($editorExit). See $editorLog" }
& $Python $helper verify (Join-Path $runDirectory 'prepared.json') $staging $repoRoot
if ($LASTEXITCODE -ne 0) { throw 'Unity output verification failed; Godot overrides were not updated.' }
Write-Output "Verified Godot PNG overrides in assets/imported-unity. Import evidence: $runDirectory"
