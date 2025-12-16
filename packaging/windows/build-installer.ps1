<#
.SYNOPSIS
    Build Windows installer for Talkies .NET 8 WPF application

.DESCRIPTION
    Automates the build, signing, and packaging process for Talkies Windows application.
    Supports self-contained publishing, code signing (traditional or Azure Trusted Signing),
    and Inno Setup installer creation.

.PARAMETER Architecture
    Target architecture: x64 (default), arm64, or x86

.PARAMETER Configuration
    Build configuration: Release (default) or Debug

.PARAMETER SigningCertificate
    Path to PFX certificate file for code signing

.PARAMETER CertificatePassword
    Password for PFX certificate (use secure string in production)

.PARAMETER UseAzureTrustedSigning
    Use Azure Trusted Signing instead of traditional certificate

.PARAMETER AzureMetadataFile
    Path to Azure Trusted Signing metadata.json file

.PARAMETER SkipSigning
    Skip code signing step (not recommended for production)

.PARAMETER SkipInnoSetup
    Skip Inno Setup installer creation

.PARAMETER Clean
    Clean output directories before build

.PARAMETER Version
    Override version number (default: read from .csproj)

.EXAMPLE
    .\build-installer.ps1
    Basic unsigned build for x64

.EXAMPLE
    .\build-installer.ps1 -SigningCertificate "C:\certs\talkies.pfx" -CertificatePassword "password"
    Build and sign with PFX certificate

.EXAMPLE
    .\build-installer.ps1 -UseAzureTrustedSigning -AzureMetadataFile "C:\config\metadata.json"
    Build and sign with Azure Trusted Signing

.EXAMPLE
    .\build-installer.ps1 -Architecture arm64 -Clean
    Clean build for ARM64

.NOTES
    Author: Talkies Team
    Requires: .NET 8 SDK, Windows SDK (for signing), Inno Setup (optional)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('x64', 'arm64', 'x86')]
    [string]$Architecture = 'x64',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',

    [Parameter(Mandatory=$false)]
    [string]$SigningCertificate,

    [Parameter(Mandatory=$false)]
    [string]$CertificatePassword,

    [Parameter(Mandatory=$false)]
    [switch]$UseAzureTrustedSigning,

    [Parameter(Mandatory=$false)]
    [string]$AzureMetadataFile,

    [Parameter(Mandatory=$false)]
    [switch]$SkipSigning,

    [Parameter(Mandatory=$false)]
    [switch]$SkipInnoSetup,

    [Parameter(Mandatory=$false)]
    [switch]$Clean,

    [Parameter(Mandatory=$false)]
    [string]$Version
)

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script configuration
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$WindowsDir = Join-Path $RootDir "windows"
$ProjectDir = Join-Path $WindowsDir "Talkies.Windows"
$ProjectFile = Join-Path $ProjectDir "Talkies.Windows.csproj"
$OutputBaseDir = Join-Path $PSScriptRoot "output"
$BrandingDir = Join-Path $RootDir "branding"

# Runtime identifier mapping
$RuntimeId = "win-$Architecture"

# Color output functions
function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Get version from project file or parameter
function Get-AppVersion {
    if ($Version) {
        return $Version
    }

    try {
        [xml]$projectXml = Get-Content $ProjectFile
        $versionNode = $projectXml.Project.PropertyGroup.Version

        if ($versionNode) {
            return $versionNode
        }

        # Default version if not specified
        return "1.0.0"
    }
    catch {
        Write-Info "Could not read version from project file, using default: 1.0.0"
        return "1.0.0"
    }
}

# Verify prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"

    # Check .NET SDK
    Write-Info "Checking .NET 8 SDK..."
    try {
        $dotnetVersion = dotnet --version
        Write-Success ".NET SDK version $dotnetVersion found"
    }
    catch {
        Write-Error-Custom ".NET 8 SDK not found. Please install from https://dotnet.microsoft.com/download"
        exit 1
    }

    # Check project file exists
    if (-not (Test-Path $ProjectFile)) {
        Write-Error-Custom "Project file not found: $ProjectFile"
        exit 1
    }
    Write-Success "Project file found"

    # Check for signing prerequisites if signing is enabled
    if (-not $SkipSigning) {
        if ($UseAzureTrustedSigning) {
            if (-not $AzureMetadataFile -or -not (Test-Path $AzureMetadataFile)) {
                Write-Error-Custom "Azure metadata file not found: $AzureMetadataFile"
                Write-Info "Create metadata.json with Azure Trusted Signing configuration"
                exit 1
            }
            Write-Success "Azure Trusted Signing metadata file found"

            # Check for Azure CLI
            try {
                $azVersion = az --version
                Write-Success "Azure CLI found"
            }
            catch {
                Write-Info "Azure CLI not found. You may need to authenticate manually."
            }
        }
        elseif ($SigningCertificate) {
            if (-not (Test-Path $SigningCertificate)) {
                Write-Error-Custom "Signing certificate not found: $SigningCertificate"
                exit 1
            }
            Write-Success "Signing certificate found"
        }
        else {
            Write-Info "No signing configuration provided. Build will be unsigned."
            Write-Info "Use -SkipSigning to suppress this message, or provide signing certificate."
        }

        # Check for signtool.exe
        $signtoolPaths = @(
            "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
            "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe",
            "C:\Program Files (x86)\Windows Kits\10\bin\10.0.18362.0\x64\signtool.exe"
        )

        $signtoolPath = $null
        foreach ($path in $signtoolPaths) {
            if (Test-Path $path) {
                $signtoolPath = $path
                break
            }
        }

        if (-not $signtoolPath -and -not $SkipSigning) {
            Write-Info "signtool.exe not found. Install Windows SDK from https://developer.microsoft.com/windows/downloads/windows-sdk/"
            Write-Info "Continuing without signing capability..."
        }
        else {
            $script:SignToolPath = $signtoolPath
            Write-Success "signtool.exe found at: $signtoolPath"
        }
    }

    # Check for Inno Setup
    if (-not $SkipInnoSetup) {
        $innoSetupPaths = @(
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
            "C:\Program Files\Inno Setup 6\ISCC.exe"
        )

        $innoSetupPath = $null
        foreach ($path in $innoSetupPaths) {
            if (Test-Path $path) {
                $innoSetupPath = $path
                break
            }
        }

        if (-not $innoSetupPath) {
            Write-Info "Inno Setup not found. Installer creation will be skipped."
            Write-Info "Download from: https://jrsoftware.org/isinfo.php"
            $script:SkipInnoSetup = $true
        }
        else {
            $script:InnoSetupPath = $innoSetupPath
            Write-Success "Inno Setup found at: $innoSetupPath"
        }
    }
}

# Clean output directories
function Invoke-Clean {
    Write-Header "Cleaning Output Directories"

    $publishDir = Join-Path $ProjectDir "bin\$Configuration\net8.0-windows\$RuntimeId\publish"

    if (Test-Path $publishDir) {
        Write-Info "Removing publish directory: $publishDir"
        Remove-Item $publishDir -Recurse -Force
        Write-Success "Publish directory cleaned"
    }

    if (Test-Path $OutputBaseDir) {
        Write-Info "Removing output directory: $OutputBaseDir"
        Remove-Item $OutputBaseDir -Recurse -Force
        Write-Success "Output directory cleaned"
    }
}

# Build and publish application
function Invoke-Publish {
    Write-Header "Publishing Application"

    Write-Info "Configuration: $Configuration"
    Write-Info "Architecture: $Architecture ($RuntimeId)"
    Write-Info "Version: $script:AppVersion"

    $publishArgs = @(
        "publish",
        $ProjectFile,
        "-c", $Configuration,
        "-r", $RuntimeId,
        "--self-contained", "true",
        "-p:PublishSingleFile=true",
        "-p:IncludeNativeLibrariesForSelfExtract=true",
        "-p:EnableCompressionInSingleFile=true",
        "-p:DebugType=embedded"
    )

    if ($Version) {
        $publishArgs += "-p:Version=$Version"
    }

    Write-Info "Running: dotnet $($publishArgs -join ' ')"

    try {
        & dotnet @publishArgs

        if ($LASTEXITCODE -ne 0) {
            throw "dotnet publish failed with exit code $LASTEXITCODE"
        }

        Write-Success "Application published successfully"

        # Verify output
        $publishDir = Join-Path $ProjectDir "bin\$Configuration\net8.0-windows\$RuntimeId\publish"
        $exePath = Join-Path $publishDir "Talkies.Windows.exe"

        if (-not (Test-Path $exePath)) {
            throw "Published executable not found: $exePath"
        }

        $fileSize = (Get-Item $exePath).Length / 1MB
        Write-Info "Executable size: $([math]::Round($fileSize, 2)) MB"

        $script:PublishDir = $publishDir
        $script:ExePath = $exePath

        return $exePath
    }
    catch {
        Write-Error-Custom "Publish failed: $_"
        exit 1
    }
}

# Sign executable
function Invoke-Sign {
    param([string]$FilePath)

    if ($SkipSigning) {
        Write-Info "Skipping code signing (as requested)"
        return
    }

    if (-not $SigningCertificate -and -not $UseAzureTrustedSigning) {
        Write-Info "No signing configuration provided. Skipping code signing."
        return
    }

    Write-Header "Code Signing"

    if (-not $script:SignToolPath) {
        Write-Info "signtool.exe not available. Skipping signing."
        return
    }

    try {
        if ($UseAzureTrustedSigning) {
            Write-Info "Signing with Azure Trusted Signing..."

            # Check for Azure Trusted Signing DLL
            $dlibPath = "C:\Program Files\Azure Trusted Signing Client\x64\Azure.CodeSigning.Dlib.dll"
            if (-not (Test-Path $dlibPath)) {
                Write-Info "Azure Trusted Signing client not found. Install with:"
                Write-Info "  winget install -e --id Microsoft.Azure.TrustedSigningClientTools"
                return
            }

            $signArgs = @(
                "sign",
                "/v",
                "/fd", "SHA256",
                "/tr", "http://timestamp.acs.microsoft.com",
                "/td", "SHA256",
                "/dlib", $dlibPath,
                "/dmdf", $AzureMetadataFile,
                $FilePath
            )
        }
        else {
            Write-Info "Signing with certificate: $SigningCertificate"

            $signArgs = @(
                "sign",
                "/f", $SigningCertificate,
                "/fd", "SHA256",
                "/tr", "http://timestamp.digicert.com",
                "/td", "SHA256",
                "/d", "Talkies",
                "/du", "https://talkies.app"
            )

            if ($CertificatePassword) {
                $signArgs += "/p"
                $signArgs += $CertificatePassword
            }

            $signArgs += $FilePath
        }

        Write-Info "Running: signtool $($signArgs -join ' ')"

        & $script:SignToolPath @signArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Success "File signed successfully: $(Split-Path -Leaf $FilePath)"

            # Verify signature
            & $script:SignToolPath verify /pa /v $FilePath | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Signature verified"
            }
        }
        else {
            Write-Info "Signing failed or was skipped. Continuing without signature."
        }
    }
    catch {
        Write-Info "Signing error: $_"
        Write-Info "Continuing without signature..."
    }
}

# Create Inno Setup installer
function Invoke-InnoSetup {
    if ($SkipInnoSetup -or -not $script:InnoSetupPath) {
        Write-Info "Skipping Inno Setup installer creation"
        return
    }

    Write-Header "Creating Inno Setup Installer"

    # Check for Inno Setup script
    $issFile = Join-Path $WindowsDir "Talkies.iss"

    if (-not (Test-Path $issFile)) {
        Write-Info "Inno Setup script not found: $issFile"
        Write-Info "Create Talkies.iss to enable installer generation"
        Write-Info "See documentation at: packaging/windows/README.md"
        return
    }

    try {
        Write-Info "Compiling Inno Setup script: $issFile"

        # Set environment variables for Inno Setup script
        $env:TALKIES_VERSION = $script:AppVersion
        $env:TALKIES_ARCH = $Architecture

        & $script:InnoSetupPath $issFile

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Inno Setup installer created successfully"

            # Find and sign the installer
            $installerPattern = "Talkies-Setup-*.exe"
            $installerFiles = Get-ChildItem -Path $OutputBaseDir -Filter $installerPattern -Recurse

            if ($installerFiles) {
                $installerPath = $installerFiles[0].FullName
                Write-Info "Installer created: $installerPath"

                # Sign the installer
                if (-not $SkipSigning) {
                    Invoke-Sign -FilePath $installerPath
                }

                $script:InstallerPath = $installerPath
            }
        }
        else {
            Write-Info "Inno Setup compilation failed"
        }
    }
    catch {
        Write-Info "Inno Setup error: $_"
    }
}

# Organize output files
function Invoke-OrganizeOutput {
    Write-Header "Organizing Output"

    # Create version-specific output directory
    $versionDir = Join-Path $OutputBaseDir "v$($script:AppVersion)"
    New-Item -ItemType Directory -Path $versionDir -Force | Out-Null

    # Copy executable
    $outputExeName = "Talkies-$($script:AppVersion)-$RuntimeId.exe"
    $outputExePath = Join-Path $versionDir $outputExeName

    if (Test-Path $script:ExePath) {
        Copy-Item $script:ExePath $outputExePath -Force
        Write-Success "Copied: $outputExeName"
    }

    # Copy installer if created
    if ($script:InstallerPath -and (Test-Path $script:InstallerPath)) {
        $installerName = "Talkies-Setup-$($script:AppVersion)-$RuntimeId.exe"
        $outputInstallerPath = Join-Path $versionDir $installerName
        Copy-Item $script:InstallerPath $outputInstallerPath -Force
        Write-Success "Copied: $installerName"
    }

    # Generate checksums
    Write-Info "Generating checksums..."
    $checksumFile = Join-Path $versionDir "checksums.txt"

    Get-ChildItem -Path $versionDir -Filter "*.exe" | ForEach-Object {
        $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
        "$($hash.Hash)  $($_.Name)" | Add-Content $checksumFile
    }
    Write-Success "Checksums saved to: checksums.txt"

    # Create/update 'latest' symlink (if on Windows 10+)
    try {
        $latestDir = Join-Path $OutputBaseDir "latest"

        if (Test-Path $latestDir) {
            Remove-Item $latestDir -Force -Recurse
        }

        # Note: Creating directory junctions requires admin privileges on Windows
        # Fallback to copying files if not admin
        try {
            New-Item -ItemType Junction -Path $latestDir -Target $versionDir -Force | Out-Null
            Write-Success "Created 'latest' junction"
        }
        catch {
            New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
            Copy-Item "$versionDir\*" $latestDir -Force
            Write-Success "Copied to 'latest' directory"
        }
    }
    catch {
        Write-Info "Could not create 'latest' link/copy: $_"
    }

    Write-Success "Output organized in: $versionDir"

    # List final output
    Write-Host "`nFinal Output Files:" -ForegroundColor Cyan
    Get-ChildItem -Path $versionDir -File | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  - $($_.Name) ($size MB)" -ForegroundColor White
    }
}

# Main execution
function Main {
    Write-Host @"

TPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPW
Q                                                           Q
Q   Talkies Windows Installer Build Script                Q
Q   .NET 8 WPF Application Packaging                      Q
Q                                                           Q
ZPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP]

"@ -ForegroundColor Cyan

    # Get version
    $script:AppVersion = Get-AppVersion

    # Verify prerequisites
    Test-Prerequisites

    # Clean if requested
    if ($Clean) {
        Invoke-Clean
    }

    # Build and publish
    $exePath = Invoke-Publish

    # Sign executable
    Invoke-Sign -FilePath $exePath

    # Create installer
    Invoke-InnoSetup

    # Organize output
    Invoke-OrganizeOutput

    Write-Header "Build Complete!"
    Write-Host "Build Summary:" -ForegroundColor Cyan
    Write-Host "  Version:      $($script:AppVersion)" -ForegroundColor White
    Write-Host "  Architecture: $Architecture" -ForegroundColor White
    Write-Host "  Configuration: $Configuration" -ForegroundColor White
    Write-Host "  Output:       $OutputBaseDir\v$($script:AppVersion)" -ForegroundColor White

    if ($SkipSigning -or (-not $SigningCertificate -and -not $UseAzureTrustedSigning)) {
        Write-Host "`n  WARNING: Build is not code signed!" -ForegroundColor Yellow
        Write-Host "  Users will see 'Unknown Publisher' warnings." -ForegroundColor Yellow
        Write-Host "  See documentation for code signing setup." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n  Code signing: Enabled" -ForegroundColor Green
    }

    Write-Host "`n"
}

# Run main function
try {
    Main
}
catch {
    Write-Error-Custom "Build failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
