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

# Put legal materials beside both portable and installed builds. The native
# backends bundled by Whisper.net and LLamaSharp are distinct from Talkies.
$licenseDirectory = Join-Path $publishDirectory 'licenses'
New-Item $licenseDirectory -ItemType Directory -Force | Out-Null
$dotnetLicenseDirectory = Join-Path $licenseDirectory 'dotnet'
New-Item $dotnetLicenseDirectory -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $repositoryRoot 'LICENSE') (Join-Path $publishDirectory 'LICENSE')
Copy-Item (Join-Path $PSScriptRoot 'THIRD-PARTY-NOTICES.txt') `
    (Join-Path $publishDirectory 'THIRD-PARTY-NOTICES.txt')
Copy-Item (Join-Path $repositoryRoot 'packaging\shared\licenses\llama.cpp-MIT.txt') `
    (Join-Path $licenseDirectory 'llama.cpp-MIT.txt')
Copy-Item (Join-Path $repositoryRoot 'packaging\shared\licenses\whisper.cpp-MIT.txt') `
    (Join-Path $licenseDirectory 'whisper.cpp-MIT.txt')
Copy-Item (Join-Path $repositoryRoot 'packaging\shared\licenses\LLamaSharp-MIT.txt') `
    (Join-Path $licenseDirectory 'LLamaSharp-MIT.txt')
Copy-Item (Join-Path $repositoryRoot 'packaging\shared\licenses\NAudio-MIT.txt') `
    (Join-Path $licenseDirectory 'NAudio-MIT.txt')

$whisperReference = Select-String -Path $projectPath `
    -Pattern '<PackageReference Include="Whisper.net" Version="([^"]+)"' |
    Select-Object -First 1
if ($null -eq $whisperReference -or $whisperReference.Matches.Count -eq 0) {
    throw 'Could not determine the pinned Whisper.net package version for its license.'
}
$whisperVersion = $whisperReference.Matches[0].Groups[1].Value
$nugetRoot = if ($env:NUGET_PACKAGES) {
    $env:NUGET_PACKAGES
} else {
    Join-Path $env:USERPROFILE '.nuget/packages'
}
$whisperLicense = Join-Path $nugetRoot "whisper.net/$whisperVersion/LICENSE"
if (-not (Test-Path $whisperLicense -PathType Leaf)) {
    throw "Whisper.net license file is missing from restored package ${whisperVersion}: $whisperLicense"
}
Copy-Item $whisperLicense (Join-Path $licenseDirectory 'Whisper.net-MIT.txt')
$newtonsoftReference = Select-String -Path $projectPath `
    -Pattern '<PackageReference Include="Newtonsoft.Json" Version="([^"]+)"' |
    Select-Object -First 1
if ($null -eq $newtonsoftReference -or $newtonsoftReference.Matches.Count -eq 0) {
    throw 'Could not determine the pinned Newtonsoft.Json package version for its license.'
}
$newtonsoftVersion = $newtonsoftReference.Matches[0].Groups[1].Value
$newtonsoftLicense = Join-Path $nugetRoot "newtonsoft.json/$newtonsoftVersion/LICENSE.md"
if (-not (Test-Path $newtonsoftLicense -PathType Leaf)) {
    throw "Newtonsoft.Json license file is missing from restored package ${newtonsoftVersion}: $newtonsoftLicense"
}
Copy-Item $newtonsoftLicense (Join-Path $licenseDirectory 'Newtonsoft.Json-MIT.md')

# Read the resolved app dependency graph, not only top-level PackageReferences,
# so newly bundled NuGet packages cannot silently arrive without an attribution.
$assetsPath = Join-Path (Split-Path -Parent $projectPath) 'obj/project.assets.json'
if (-not (Test-Path $assetsPath -PathType Leaf)) {
    throw "Restored NuGet dependency manifest is missing: $assetsPath"
}
$assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json
$nugetLicenseDirectory = Join-Path $licenseDirectory 'nuget'
$nugetAttributions = [System.Collections.Generic.List[string]]::new()
New-Item $nugetLicenseDirectory -ItemType Directory -Force | Out-Null
foreach ($library in $assets.libraries.PSObject.Properties) {
    if ($library.Value.type -ne 'package') {
        continue
    }
    $packageSeparator = $library.Name.IndexOf('/')
    if ($packageSeparator -lt 1 -or $packageSeparator -eq ($library.Name.Length - 1)) {
        throw "Unexpected NuGet library identifier in project.assets.json: $($library.Name)"
    }
    $packageId = $library.Name.Substring(0, $packageSeparator)
    $packageVersion = $library.Name.Substring($packageSeparator + 1)
    $packageRoot = Join-Path $nugetRoot "$($packageId.ToLowerInvariant())/$($packageVersion.ToLowerInvariant())"
    $nuspec = Get-ChildItem -LiteralPath $packageRoot -Filter '*.nuspec' -File | Select-Object -First 1
    if ($null -eq $nuspec) {
        throw "NuGet package has no .nuspec metadata: $packageId $packageVersion"
    }
    [xml]$packageMetadata = Get-Content -LiteralPath $nuspec.FullName -Raw
    $metadata = $packageMetadata.SelectSingleNode("//*[local-name()='metadata']")
    $packageLicense = $metadata.SelectSingleNode("./*[local-name()='license']")
    $licenseType = if ($null -ne $packageLicense) { $packageLicense.GetAttribute('type') } else { '' }
    $licenseValue = if ($null -ne $packageLicense) { $packageLicense.InnerText.Trim() } else { '' }
    $licenseUrlNode = $metadata.SelectSingleNode("./*[local-name()='licenseUrl']")
    $licenseUrl = if ($null -ne $licenseUrlNode) { $licenseUrlNode.InnerText.Trim() } else { '' }
    $copyrightNode = $metadata.SelectSingleNode("./*[local-name()='copyright']")
    $authorsNode = $metadata.SelectSingleNode("./*[local-name()='authors']")
    $copyright = if ($null -ne $copyrightNode) { $copyrightNode.InnerText.Trim() } else { '' }
    $authors = if ($null -ne $authorsNode) { $authorsNode.InnerText.Trim() } else { '' }
    $packageLicenseDirectory = Join-Path $nugetLicenseDirectory "$($packageId.ToLowerInvariant())-$packageVersion"
    New-Item $packageLicenseDirectory -ItemType Directory -Force | Out-Null

    if ($licenseType -eq 'expression') {
        if ($licenseValue -ne 'MIT') {
            throw "NuGet package $packageId $packageVersion declares unsupported license expression '$licenseValue'; add its exact license text before distributing it."
        }
        $nugetAttributions.Add("$packageId $packageVersion | MIT | $copyright | $authors | $licenseUrl")
    } elseif ($licenseType -eq 'file') {
        $packageLicensePath = Join-Path $packageRoot $licenseValue
        if (-not (Test-Path $packageLicensePath -PathType Leaf) -or (Get-Item $packageLicensePath).Length -le 0) {
            throw "NuGet package $packageId $packageVersion is missing its declared license file: $packageLicensePath"
        }
        Copy-Item $packageLicensePath (Join-Path $packageLicenseDirectory (Split-Path -Leaf $licenseValue))
        $nugetAttributions.Add("$packageId $packageVersion | license file: licenses/nuget/$($packageId.ToLowerInvariant())-$packageVersion/$(Split-Path -Leaf $licenseValue) | $copyright | $authors | $licenseUrl")
    } elseif (-not [string]::IsNullOrWhiteSpace($licenseUrl)) {
        # Legacy packages may only provide a license URL. Preserve that exact
        # metadata; the .NET ThirdPartyNotices file is shipped alongside it.
        $nugetAttributions.Add("$packageId $packageVersion | license URL: $licenseUrl | $copyright | $authors")
    } else {
        throw "NuGet package $packageId $packageVersion declares no license expression, file, or URL."
    }

    Get-ChildItem -LiteralPath $packageRoot -File -Recurse |
        Where-Object { $_.Name -match '^(LICENSE|NOTICE|COPYING)(\..*)?$|^THIRD-PARTY-NOTICES(\..*)?$' } |
        ForEach-Object {
            $relativeFile = [System.IO.Path]::GetRelativePath($packageRoot, $_.FullName)
            $destination = Join-Path $packageLicenseDirectory $relativeFile
            New-Item (Split-Path -Parent $destination) -ItemType Directory -Force | Out-Null
            Copy-Item $_.FullName $destination
        }
}
if ($nugetAttributions.Count -eq 0) {
    throw 'The restored NuGet graph contained no package license metadata.'
}
$nugetAttributions.Sort([System.StringComparer]::OrdinalIgnoreCase)
$nugetAttributions | Set-Content -LiteralPath (Join-Path $licenseDirectory 'NuGet-MIT-ATTRIBUTIONS.txt') -Encoding utf8
Copy-Item (Join-Path $repositoryRoot 'packaging\shared\licenses\MIT-LICENSE-TEXT.txt') `
    (Join-Path $licenseDirectory 'NuGet-MIT-LICENSE.txt')

# Self-contained publish carries the runtime binaries, but does not guarantee
# the installation-level .NET redistribution notices are in its output.
$dotnetRoot = $env:DOTNET_ROOT
if ([string]::IsNullOrWhiteSpace($dotnetRoot)) {
    $dotnetCommand = Get-Command 'dotnet.exe' -ErrorAction SilentlyContinue
    if ($null -eq $dotnetCommand) {
        $dotnetCommand = Get-Command 'dotnet' -ErrorAction Stop
    }
    $dotnetRoot = Split-Path -Parent $dotnetCommand.Source
}
foreach ($dotnetNotice in @('LICENSE.txt', 'ThirdPartyNotices.txt')) {
    $dotnetNoticeSource = Join-Path $dotnetRoot $dotnetNotice
    if (-not (Test-Path $dotnetNoticeSource -PathType Leaf) -or (Get-Item $dotnetNoticeSource).Length -le 0) {
        throw ".NET installation is missing its redistribution notice: $dotnetNoticeSource"
    }
    Copy-Item $dotnetNoticeSource (Join-Path $dotnetLicenseDirectory $dotnetNotice)
}

$expectedLegalFiles = @('LICENSE', 'THIRD-PARTY-NOTICES.txt') + @(
    Get-ChildItem -LiteralPath $licenseDirectory -File -Recurse |
        ForEach-Object { [System.IO.Path]::GetRelativePath($publishDirectory, $_.FullName) }
)
foreach ($requiredNotice in $expectedLegalFiles) {
    $noticePath = Join-Path $publishDirectory $requiredNotice
    if (-not (Test-Path $noticePath -PathType Leaf) -or (Get-Item $noticePath).Length -le 0) {
        throw "Release publish directory is missing a non-empty legal file: $requiredNotice"
    }
}

Compress-Archive -Path (Join-Path $publishDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
Expand-Archive -Path $archivePath -DestinationPath $extractDirectory -Force

foreach ($requiredFile in @(
    'Talkies.Windows.exe',
    'Talkies.Windows.dll',
    'Talkies.Windows.deps.json',
    'Talkies.Windows.runtimeconfig.json',
    'Resources/talkies-app-icon.ico',
    'LICENSE',
    'THIRD-PARTY-NOTICES.txt'
)) {
    $extractedPath = Join-Path $extractDirectory $requiredFile
    if (-not (Test-Path $extractedPath -PathType Leaf)) {
        throw "Release archive is missing required file after extraction: $requiredFile"
    }
}

foreach ($requiredNotice in $expectedLegalFiles) {
    $noticePath = Join-Path $extractDirectory $requiredNotice
    if (-not (Test-Path $noticePath -PathType Leaf) -or (Get-Item $noticePath).Length -le 0) {
        throw "Release archive is missing a non-empty legal file after extraction: $requiredNotice"
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
        'Uninstall.exe'
    )) {
        if (-not (Test-Path (Join-Path $Directory $requiredFile) -PathType Leaf)) {
            throw "Installer smoke test is missing installed file: $requiredFile"
        }
    }
    foreach ($requiredNotice in $expectedLegalFiles) {
        $noticePath = Join-Path $Directory $requiredNotice
        if (-not (Test-Path $noticePath -PathType Leaf) -or (Get-Item $noticePath).Length -le 0) {
            throw "Installer smoke test is missing a non-empty legal file: $requiredNotice"
        }
    }
}

# Run the actual per-user installer in an isolated temporary directory. Re-run
# it with a stale marker present to exercise its in-place upgrade behavior,
# then invoke its uninstaller and ensure application files are removed.
$installProcess = Start-Process -FilePath $installerPath -ArgumentList @('/S', "/D=$smokeInstallDirectory") -Wait -PassThru
if ($installProcess.ExitCode -ne 0) {
    throw "Silent install smoke test failed (exit code $($installProcess.ExitCode))."
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
$upgradeProcess = Start-Process -FilePath $installerPath -ArgumentList @('/S', "/D=$smokeInstallDirectory") -Wait -PassThru
if ($upgradeProcess.ExitCode -ne 0) {
    throw "In-place upgrade smoke test failed (exit code $($upgradeProcess.ExitCode))."
}
Assert-InstalledApplication $smokeInstallDirectory
if (Test-Path $staleMarker) {
    throw 'In-place upgrade left an obsolete application file in the install directory.'
}

$uninstallerPath = Join-Path $smokeInstallDirectory 'Uninstall.exe'
$uninstallProcess = Start-Process -FilePath $uninstallerPath -ArgumentList '/S' -Wait -PassThru
if ($uninstallProcess.ExitCode -ne 0) {
    throw "Silent uninstall smoke test failed (exit code $($uninstallProcess.ExitCode))."
}
if (Test-Path (Join-Path $smokeInstallDirectory 'Talkies.Windows.exe')) {
    throw 'Uninstaller left the Talkies application executable behind.'
}

Remove-Item $scratchRoot -Recurse -Force
Write-Host "Created and smoke-tested $archivePath and $installerPath"
