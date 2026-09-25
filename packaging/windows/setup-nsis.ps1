[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$version = '3.12'
$archiveName = "nsis-$version.zip"
$archiveUrl = "https://downloads.sourceforge.net/project/nsis/NSIS%203/$version/$archiveName"
$expectedSha256 = '56581f90db321581c5381193d796fffcf2d24b2f8fed2160a6c6a3baa67f2c4f'
$toolRoot = Join-Path ([System.IO.Path]::GetTempPath()) "talkies-nsis-$version"
$archivePath = Join-Path ([System.IO.Path]::GetTempPath()) $archiveName

& curl.exe --fail --location --retry 3 --retry-all-errors --output $archivePath $archiveUrl
if ($LASTEXITCODE -ne 0) {
    throw "NSIS download failed (curl exit code $LASTEXITCODE)."
}

$actualSha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "NSIS archive SHA-256 mismatch. Expected $expectedSha256; got $actualSha256."
}

New-Item -Path $toolRoot -ItemType Directory -Force | Out-Null
Expand-Archive -Path $archivePath -DestinationPath $toolRoot -Force
$nsisRoot = Join-Path $toolRoot "nsis-$version"
$makensisPath = Join-Path $nsisRoot 'Bin/makensis.exe'
if (-not (Test-Path $makensisPath -PathType Leaf)) {
    throw "Verified NSIS archive is missing expected compiler: $makensisPath"
}

$env:NSISDIR = $nsisRoot
$env:Path = "$(Join-Path $nsisRoot 'Bin');$env:Path"
if ($env:GITHUB_PATH) {
    Add-Content -Path $env:GITHUB_PATH -Value (Join-Path $nsisRoot 'Bin')
}
if ($env:GITHUB_ENV) {
    Add-Content -Path $env:GITHUB_ENV -Value "NSISDIR=$nsisRoot"
}

Write-Host "Using verified NSIS $version from $archiveUrl"
& $makensisPath -VERSION
if ($LASTEXITCODE -ne 0) {
    throw "NSIS version check failed (exit code $LASTEXITCODE)."
}
