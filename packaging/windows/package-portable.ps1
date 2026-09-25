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
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "talkies-windows-package-$ReleaseLabel-$([Guid]::NewGuid().ToString('N'))"
$publishDirectory = Join-Path $scratchRoot 'publish'
$extractDirectory = Join-Path $scratchRoot 'extracted'
$smokeInstallDirectory = Join-Path $scratchRoot 'smoke-install'
$archivePath = Join-Path $OutputDirectory "Talkies-Windows-$ReleaseLabel.zip"
$installerPath = Join-Path $OutputDirectory "Talkies-Windows-$ReleaseLabel-Setup.exe"
$installerScript = Join-Path $PSScriptRoot 'Talkies.nsi'

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

$nsis = Get-Command 'makensis.exe' -ErrorAction SilentlyContinue
$makensisPath = if ($null -ne $nsis) { $nsis.Source } else { $null }
if ($null -eq $nsis) {
    foreach ($candidate in @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS/makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS/makensis.exe')
    )) {
        if (Test-Path $candidate -PathType Leaf) {
            $makensisPath = $candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($makensisPath)) {
    throw 'NSIS (makensis.exe) is required to build the Windows setup installer.'
}

& $makensisPath `
    "-DAPP_VERSION=$AppVersion" `
    "-DPUBLISH_DIRECTORY=$publishDirectory" `
    "-DOUTPUT_PATH=$installerPath" `
    "-DREPOSITORY_ROOT=$repositoryRoot" `
    $installerScript
if ($LASTEXITCODE -ne 0) {
    throw "NSIS failed to build the Windows installer (exit code $LASTEXITCODE)."
}
if (-not (Test-Path $installerPath -PathType Leaf) -or (Get-Item $installerPath).Length -le 0) {
    throw 'NSIS did not produce a non-empty setup installer.'
}

function Assert-InstalledApplication([string]$Directory) {
    foreach ($requiredFile in @(
        'Talkies.Windows.exe',
        'Talkies.Windows.dll',
        'Talkies.Windows.deps.json',
        'Talkies.Windows.runtimeconfig.json',
        'Resources/talkies-app-icon.ico',
        'THIRD-PARTY-NOTICES.txt',
        'Uninstall.exe'
    )) {
        if (-not (Test-Path (Join-Path $Directory $requiredFile) -PathType Leaf)) {
            throw "Installer smoke test is missing installed file: $requiredFile"
        }
    }
}

# Run the actual per-user installer in an isolated temporary directory. Re-run
# it with a stale marker present to exercise its in-place upgrade behavior,
# then invoke its uninstaller and ensure application files are removed.
& $installerPath /S "/D=$smokeInstallDirectory"
if ($LASTEXITCODE -ne 0) {
    throw "Silent install smoke test failed (exit code $LASTEXITCODE)."
}
Write-Host "Installer smoke test requested install path: $smokeInstallDirectory"
$installRegistry = Get-ItemProperty -Path 'HKCU:\Software\Talkies' -Name InstallLocation -ErrorAction SilentlyContinue
$registeredInstallPath = if ($null -ne $installRegistry) { $installRegistry.InstallLocation } else { '<missing>' }
Write-Host "Installer registered install path: $registeredInstallPath"
if (Test-Path $smokeInstallDirectory -PathType Container) {
    $installedFileSample = Get-ChildItem -LiteralPath $smokeInstallDirectory -File -Recurse |
        Select-Object -First 12 -ExpandProperty FullName
    Write-Host "Installed file sample: $($installedFileSample -join '; ')"
} else {
    Write-Host 'Smoke install directory was not created.'
}
Assert-InstalledApplication $smokeInstallDirectory
$staleMarker = Join-Path $smokeInstallDirectory 'obsolete-stale-marker.tmp'
Set-Content -Path $staleMarker -Value 'stale files should not survive an upgrade'
& $installerPath /S "/D=$smokeInstallDirectory"
if ($LASTEXITCODE -ne 0) {
    throw "In-place upgrade smoke test failed (exit code $LASTEXITCODE)."
}
Assert-InstalledApplication $smokeInstallDirectory
if (Test-Path $staleMarker) {
    throw 'In-place upgrade left an obsolete application file in the install directory.'
}

$uninstallerPath = Join-Path $smokeInstallDirectory 'Uninstall.exe'
& $uninstallerPath /S
if ($LASTEXITCODE -ne 0) {
    throw "Silent uninstall smoke test failed (exit code $LASTEXITCODE)."
}
if (Test-Path (Join-Path $smokeInstallDirectory 'Talkies.Windows.exe')) {
    throw 'Uninstaller left the Talkies application executable behind.'
}

Remove-Item $scratchRoot -Recurse -Force
Write-Host "Created and smoke-tested $archivePath and $installerPath"
