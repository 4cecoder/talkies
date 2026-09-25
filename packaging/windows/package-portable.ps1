[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')]
    [string]$AppVersion,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$ReleaseLabel,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$projectPath = Join-Path $repositoryRoot 'windows/Talkies.Windows/Talkies.Windows.csproj'
$scratchRoot = Join-Path $env:RUNNER_TEMP "talkies-windows-package-$ReleaseLabel"
$publishDirectory = Join-Path $scratchRoot 'publish'
$extractDirectory = Join-Path $scratchRoot 'extracted'
$archivePath = Join-Path $OutputDirectory "Talkies-Windows-$ReleaseLabel.zip"

Remove-Item $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item $publishDirectory -ItemType Directory -Force | Out-Null
New-Item $OutputDirectory -ItemType Directory -Force | Out-Null

dotnet publish $projectPath `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    "-p:Version=$AppVersion" `
    --output $publishDirectory

foreach ($requiredFile in @(
    'Talkies.Windows.exe',
    'Talkies.Windows.dll',
    'Talkies.Windows.deps.json',
    'Talkies.Windows.runtimeconfig.json',
    'Resources/talkies-app-icon.ico'
)) {
    $publishedPath = Join-Path $publishDirectory $requiredFile
    if (-not (Test-Path $publishedPath -PathType Leaf)) {
        throw "Self-contained publish is missing required file: $requiredFile"
    }
}

Compress-Archive -Path (Join-Path $publishDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
Expand-Archive -Path $archivePath -DestinationPath $extractDirectory -Force

foreach ($requiredFile in @(
    'Talkies.Windows.exe',
    'Talkies.Windows.dll',
    'Talkies.Windows.deps.json',
    'Talkies.Windows.runtimeconfig.json',
    'Resources/talkies-app-icon.ico'
)) {
    $extractedPath = Join-Path $extractDirectory $requiredFile
    if (-not (Test-Path $extractedPath -PathType Leaf)) {
        throw "Release archive is missing required file after extraction: $requiredFile"
    }
}

if ((Get-Item (Join-Path $extractDirectory 'Talkies.Windows.exe')).Length -le 0) {
    throw 'Release archive contains an empty Talkies.Windows.exe.'
}

Write-Host "Created and smoke-tested $archivePath"
