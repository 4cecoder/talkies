# Windows Installer Packaging Guide

This guide covers packaging and distribution options for the Talkies .NET 8 WPF application on Windows.

## Table of Contents

1. [Packaging Options Comparison](#packaging-options-comparison)
2. [Recommended Approach](#recommended-approach)
3. [Self-Contained Publishing](#self-contained-publishing)
4. [MSIX Packaging](#msix-packaging)
5. [MSI with WiX Toolset](#msi-with-wix-toolset)
6. [Inno Setup](#inno-setup)
7. [Code Signing](#code-signing)
8. [Automated Build Process](#automated-build-process)

---

## Packaging Options Comparison

| Feature | MSIX | WiX (MSI) | Inno Setup | Self-Contained EXE |
|---------|------|-----------|------------|-------------------|
| **Format** | .msix | .msi | .exe installer | Single .exe |
| **Cost** | Free | Free (open source) | Free (open source) | Free |
| **Microsoft Store** | Yes | No | No | No |
| **Auto-updates** | Built-in (Store) | Requires custom solution | Requires custom solution | Requires custom solution |
| **Complexity** | Medium | High (XML-based) | Low (Pascal script) | Very Low |
| **Enterprise Support** | Excellent | Excellent | Good | Limited |
| **Installation Size** | Small (shared runtime) | Medium | Medium | Large (~150MB) |
| **Clean Uninstall** | Excellent (sandboxed) | Good | Good | Manual |
| **Modern Windows** | Windows 10 1809+ | All Windows | All Windows | All Windows |
| **Signing Required** | Yes (Store) | Recommended | Recommended | Recommended |
| **Learning Curve** | Medium | Steep | Low | None |

## Recommended Approach

**For Talkies, we recommend a two-tier strategy:**

### 1. Primary: Self-Contained EXE + Inno Setup (Immediate)
- **Best for**: Quick distribution, GitHub releases, beta testing
- **Pros**:
  - Simplest to implement (can be done immediately)
  - Works on all Windows versions (7 SP1+)
  - No dependency concerns - includes .NET 8 runtime
  - Familiar installation experience for users
  - Free and open source
- **Cons**:
  - Larger file size (~150MB with runtime)
  - No automatic updates
  - Manual uninstall tracking
- **Use case**: Initial releases, direct downloads, beta program

### 2. Future: MSIX (Long-term)
- **Best for**: Microsoft Store distribution, enterprise deployment
- **Pros**:
  - Modern packaging format
  - Clean install/uninstall (containerized)
  - Automatic updates via Store
  - Better security model
  - Smaller size (shared runtime)
- **Cons**:
  - Windows 10 1809+ only
  - Requires Store submission ($19 one-time fee)
  - More complex setup
- **Use case**: Microsoft Store presence, enterprise customers

### Why Not WiX?
WiX MSI is excellent for enterprise scenarios but has a steep learning curve with XML-based configuration. For a consumer application like Talkies, the simpler Inno Setup provides 90% of the benefits with 10% of the complexity. WiX should be considered if you need advanced enterprise features like Group Policy deployment, custom actions, or complex upgrade logic.

---

## Self-Contained Publishing

Self-contained publishing bundles the .NET 8 runtime with your application, eliminating dependency concerns.

### Basic Configuration

Add to your `.csproj` file:

```xml
<PropertyGroup>
  <OutputType>WinExe</OutputType>
  <TargetFramework>net8.0-windows</TargetFramework>
  <UseWPF>true</UseWPF>

  <!-- Self-contained publishing settings -->
  <RuntimeIdentifier>win-x64</RuntimeIdentifier>
  <SelfContained>true</SelfContained>
  <PublishSingleFile>true</PublishSingleFile>
  <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
  <EnableCompressionInSingleFile>true</EnableCompressionInSingleFile>

  <!-- Optional: Trimming to reduce size (use with caution) -->
  <!-- <PublishTrimmed>true</PublishTrimmed> -->
</PropertyGroup>
```

### Command Line Publishing

```powershell
# Windows x64 (64-bit) - Most common
dotnet publish `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true

# Windows ARM64 (Surface Pro X, etc.)
dotnet publish -c Release -r win-arm64 --self-contained true

# Windows x86 (32-bit) - Legacy systems
dotnet publish -c Release -r win-x86 --self-contained true
```

### Output Location

Published files will be in:
```
windows/Talkies.Windows/bin/Release/net8.0-windows/win-x64/publish/
```

### Key Properties Explained

- **`RuntimeIdentifier`**: Specifies target OS/architecture (win-x64, win-arm64, win-x86)
- **`SelfContained`**: Includes .NET runtime (true) or requires user to install it (false)
- **`PublishSingleFile`**: Bundles everything into single .exe
- **`IncludeNativeLibrariesForSelfExtract`**: Includes native DLLs (NAudio, Whisper.net) in bundle
- **`EnableCompressionInSingleFile`**: Compresses bundle (reduces size ~20-30%)
- **`PublishTrimmed`**: Removes unused code (can break reflection - test thoroughly!)

### File Size Expectations

- **With runtime (self-contained)**: ~150-200 MB
- **Without runtime (framework-dependent)**: ~5-10 MB
- **With trimming**: ~80-100 MB (experimental, may cause issues)

---

## MSIX Packaging

MSIX is Microsoft's modern packaging format, designed for Windows 10/11 and Microsoft Store distribution.

### Prerequisites

1. **Windows 10 SDK** (version 10.0.22621.0 or later)
   - Includes `makeappx.exe` and packaging tools
   - Install via Visual Studio Installer or standalone

2. **MSIX Packaging Tool** (optional, for GUI)
   - Available from Microsoft Store
   - Simplifies package creation

### Method 1: Visual Studio (GUI)

1. **Add Windows Application Packaging Project**
   - Right-click solution → Add → New Project
   - Search for "Windows Application Packaging Project"
   - Select C# template

2. **Configure Project**
   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
       <RuntimeIdentifiers>win-x64;win-arm64</RuntimeIdentifiers>
       <UseWPF>true</UseWPF>
     </PropertyGroup>
   </Project>
   ```

3. **Add Project Reference**
   - Right-click Dependencies folder in packaging project
   - Add Project Reference → Select Talkies.Windows

4. **Edit Package.appxmanifest**
   - Set application identity, display name, logo
   - Configure capabilities (microphone access required)
   - Set minimum Windows version (Windows 10 1809 / build 17763)

5. **Build Package**
   - Right-click packaging project → Publish → Create App Packages
   - Choose sideloading or Store submission
   - Select architectures (x64, ARM64)
   - Configure signing certificate

### Method 2: Command Line

```powershell
# 1. Publish self-contained build
dotnet publish -c Release -r win-x64 --self-contained false

# 2. Create MSIX package (requires Package.appxmanifest)
makeappx pack /d "bin\Release\net8.0-windows\win-x64\publish" /p Talkies.msix

# 3. Sign package (required for installation)
signtool sign /fd SHA256 /a /f MyCertificate.pfx /p CertPassword Talkies.msix
```

### MSIX Capabilities Required

In `Package.appxmanifest`, declare:

```xml
<Capabilities>
  <Capability Name="internetClient" />
  <DeviceCapability Name="microphone" />
</Capabilities>
```

### Distribution Options

1. **Microsoft Store** ($19 one-time developer fee)
   - Automatic updates
   - Built-in payment processing
   - Discoverability

2. **Sideloading** (Enterprise/Direct)
   - Email/website distribution
   - Requires code signing certificate
   - Users must enable sideloading

3. **Microsoft Store for Business** (Enterprise)
   - Private store for organizations
   - Volume licensing

### Limitations

- **Windows 10 1809+** only (no Windows 7/8.1 support)
- **No per-user services** (session-0 services only)
- **No kernel drivers**
- **Sandboxed file system** (limited registry access)

---

## MSI with WiX Toolset

WiX (Windows Installer XML) creates traditional MSI packages with full Windows Installer features.

### Why Choose WiX?

- Enterprise deployment (Group Policy, SCCM)
- Complex installation logic
- Custom actions and dialogs
- Full Windows Installer feature set
- Precise upgrade/patching control

### Prerequisites

1. **Install WiX Toolset v5+**
   ```powershell
   # Global installation
   dotnet tool install --global wix

   # Verify installation
   wix --version
   ```

2. **Visual Studio Extension** (optional)
   - Install "HeatWave for VS2022" by FireGiant
   - Adds WiX project templates

### Project Structure

```
windows/
├── Talkies.Windows/           # Main WPF application
├── Talkies.Windows.Tests/     # Unit tests
└── Talkies.Installer/         # WiX installer project
    ├── Talkies.Installer.wixproj
    ├── Package.wxs            # Package identity & version
    ├── Folders.wxs            # Directory structure
    ├── Components.wxs         # Files to install
    └── UI.wxs                 # Custom dialogs (optional)
```

### Basic WiX Configuration

**Talkies.Installer.wixproj:**

```xml
<Project Sdk="WixToolset.Sdk/5.0.0">
  <PropertyGroup>
    <OutputType>Package</OutputType>
    <OutputName>Talkies-Setup</OutputName>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="WixToolset.UI.wixext" Version="5.0.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Talkies.Windows\Talkies.Windows.csproj" />
  </ItemGroup>
</Project>
```

**Package.wxs (Main Configuration):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package
    Name="Talkies"
    Manufacturer="Talkies Team"
    Version="1.0.0.0"
    UpgradeCode="YOUR-GUID-HERE">

    <MajorUpgrade
      DowngradeErrorMessage="A newer version is already installed." />

    <!-- Minimum Windows version: Windows 10 -->
    <Launch Condition="VersionNT >= 603"
            Message="This application requires Windows 10 or later." />

    <MediaTemplate EmbedCab="yes" />

    <Feature Id="MainFeature" Title="Talkies" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
      <ComponentGroupRef Id="ProductShortcuts" />
    </Feature>

    <!-- Standard UI with license agreement -->
    <UIRef Id="WixUI_InstallDir" />
    <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
  </Package>

  <Fragment>
    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="Talkies">
        <Directory Id="BinFolder" Name="bin" />
      </Directory>
    </StandardDirectory>

    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="ApplicationProgramsFolder" Name="Talkies" />
    </StandardDirectory>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="ProductComponents" Directory="BinFolder">
      <!-- Auto-generated by Heat or manual entries -->
      <Component Id="MainExecutable">
        <File Source="$(var.Talkies.Windows.TargetPath)" />
      </Component>
    </ComponentGroup>

    <ComponentGroup Id="ProductShortcuts" Directory="ApplicationProgramsFolder">
      <Component Id="ApplicationShortcut">
        <Shortcut Id="AppShortcut"
                  Name="Talkies"
                  Target="[BinFolder]Talkies.Windows.exe"
                  WorkingDirectory="BinFolder"
                  Icon="AppIcon.ico" />
        <RemoveFolder Id="CleanupShortcut" On="uninstall" />
        <RegistryValue Root="HKCU"
                       Key="Software\Talkies"
                       Name="installed"
                       Type="integer"
                       Value="1"
                       KeyPath="yes" />
      </Component>
    </ComponentGroup>
  </Fragment>

  <Fragment>
    <Icon Id="AppIcon.ico" SourceFile="..\..\branding\icon.ico" />
  </Fragment>
</Wix>
```

### Building with WiX

```powershell
# Build MSI package
dotnet build windows/Talkies.Installer/Talkies.Installer.wixproj -c Release

# Output location
windows/Talkies.Installer/bin/Release/Talkies-Setup.msi
```

### Using Heat for File Harvesting

Heat auto-generates component definitions from build output:

```powershell
# Generate components from publish directory
heat dir "windows\Talkies.Windows\bin\Release\net8.0-windows\win-x64\publish" `
  -cg PublishedFiles `
  -gg -sfrag -srd -sreg `
  -out Components.wxs
```

### Advanced Features

- **Custom Actions**: Run code during install/uninstall
- **Burn Bootstrapper**: Bundle .NET runtime installer with your MSI
- **Upgrades**: Automatic detection and upgrade of previous versions
- **Localization**: Multi-language installer support

---

## Inno Setup

Inno Setup is a free, open-source installer creator that's easier to learn than WiX but less powerful.

### Why Choose Inno Setup?

- **Simple Pascal-based scripting** (easier than XML)
- **Quick setup** (30 minutes to first installer)
- **Small installers** (~2MB overhead)
- **Good for consumer applications**
- **Extensive community support**

### Prerequisites

1. **Download Inno Setup**
   - Download from: https://jrsoftware.org/isinfo.php
   - Current version: 6.3.3 (as of 2025)
   - Install to `C:\Program Files (x86)\Inno Setup 6\`

2. **Optional: Inno Setup Preprocessor**
   - Included with standard installation
   - Enables advanced scripting features

### Basic Script Example

Create `windows/Talkies.iss`:

```pascal
#define MyAppName "Talkies"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Talkies Team"
#define MyAppURL "https://talkies.app"
#define MyAppExeName "Talkies.Windows.exe"

[Setup]
; Application identity
AppId={{YOUR-GUID-HERE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation paths
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output settings
OutputDir=packaging\windows\output
OutputBaseFilename=Talkies-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes

; Windows version requirements
MinVersion=10.0.17763
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64

; Visual settings
WizardStyle=modern
SetupIconFile=branding\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Privileges
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "launchAtStartup"; Description: "Launch Talkies at Windows startup"; GroupDescription: "Additional options:"

[Files]
; Main application files (from self-contained publish)
Source: "windows\Talkies.Windows\bin\Release\net8.0-windows\win-x64\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; Desktop shortcut (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Option to launch after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Registry]
; Launch at startup (optional task)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Talkies"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: launchAtStartup

[Code]
// Check if .NET 8 Runtime is installed (for framework-dependent builds)
function IsDotNetInstalled: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('dotnet', '--list-runtimes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function InitializeSetup: Boolean;
begin
  // For self-contained builds, always proceed
  Result := True;

  // Uncomment for framework-dependent builds:
  // if not IsDotNetInstalled then
  // begin
  //   MsgBox('This application requires .NET 8 Runtime. Please install it from https://dotnet.microsoft.com/download', mbError, MB_OK);
  //   Result := False;
  // end;
end;
```

### Building with Inno Setup

```powershell
# Command line compilation
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\Talkies.iss

# Output
packaging\windows\output\Talkies-Setup-1.0.0.exe
```

### Advanced Features

**Custom Pages:**
```pascal
[Code]
var
  CustomPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  CustomPage := CreateInputQueryPage(wpWelcome,
    'Installation Options', 'Configure Talkies',
    'Please specify additional options:');
  CustomPage.Add('API Key (optional):', False);
end;
```

**Dependency Installer:**
```pascal
[Files]
; Bundle .NET 8 Runtime installer
Source: "dependencies\windowsdesktop-runtime-8.0.0-win-x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; Install .NET if missing
Filename: "{tmp}\windowsdesktop-runtime-8.0.0-win-x64.exe"; Parameters: "/quiet /norestart"; Check: not IsDotNetInstalled
```

---

## Code Signing

Code signing is **essential** for Windows applications to avoid "Unknown Publisher" warnings and SmartScreen blocks.

### Why Sign Your Application?

1. **Trust**: Users see your verified publisher name
2. **Security**: Prevents tampering detection
3. **SmartScreen**: Avoids "Windows protected your PC" warnings
4. **Enterprise**: Required for many corporate environments

### Signing Options (2025)

#### Option 1: Traditional Code Signing Certificate

**Providers:**
- **DigiCert**: $474-599/year (most trusted)
- **Sectigo**: $179-299/year
- **GlobalSign**: $249-399/year

**Requirements (as of 2025):**
- Business validation (3+ years verifiable history)
- EV certificates require **hardware token** (FIPS 140-2 Level 2+)
- Standard certificates now also require hardware storage

**Process:**
1. Purchase certificate from CA
2. Complete business validation (3-7 days)
3. Receive USB hardware token or HSM credentials
4. Sign using signtool.exe

#### Option 2: Azure Trusted Signing (Recommended for 2025+)

**Microsoft's modern cloud-based signing service**

**Pricing:**
- **Basic**: $9.99/month (unlimited signatures)
- **Premium**: $24.99/month (with timestamping authority)

**Advantages:**
- No hardware token needed
- Instant setup (no 3-7 day wait)
- Cloud-based (sign from anywhere)
- Eliminates SmartScreen warnings immediately
- Integrated with CI/CD pipelines

**Requirements:**
- US or Canada-based organization
- 3+ years verifiable business history
- OR individual developer with established presence
- Azure subscription

**Setup Process:**

1. **Install Prerequisites**
   ```powershell
   # Install .NET 8 Runtime (required)
   winget install Microsoft.DotNet.Runtime.8

   # Install Trusted Signing Client Tools
   winget install -e --id Microsoft.Azure.TrustedSigningClientTools

   # Install Windows SDK (10.0.22621.755+)
   # Includes required signtool.exe
   winget install Microsoft.WindowsSDK
   ```

2. **Create Azure Trusted Signing Account**
   - Go to Azure Portal
   - Create "Trusted Signing" resource
   - Complete identity validation
   - Create certificate profile

3. **Configure Metadata File**

   Create `metadata.json`:
   ```json
   {
     "Endpoint": "https://your-account.codesigning.azure.net/",
     "CodeSigningAccountName": "your-account-name",
     "CertificateProfileName": "your-profile-name"
   }
   ```

4. **Authenticate**
   ```powershell
   # Login to Azure
   az login

   # Set subscription
   az account set --subscription "your-subscription-id"
   ```

### Signing Commands

#### With Traditional Certificate (PFX)

```powershell
# Sign single file
signtool sign `
  /f "path\to\certificate.pfx" `
  /p "certificate-password" `
  /fd SHA256 `
  /tr http://timestamp.digicert.com `
  /td SHA256 `
  /d "Talkies" `
  /du "https://talkies.app" `
  "Talkies.Windows.exe"

# Sign multiple files
signtool sign /f cert.pfx /p password /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 *.exe *.dll
```

#### With Azure Trusted Signing

```powershell
# Set paths
$SignToolPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
$DlibPath = "C:\Program Files\Azure Trusted Signing Client\x64\Azure.CodeSigning.Dlib.dll"
$MetadataPath = "C:\path\to\metadata.json"

# Sign with Azure Trusted Signing
& $SignToolPath sign `
  /v `
  /fd SHA256 `
  /tr "http://timestamp.acs.microsoft.com" `
  /td SHA256 `
  /dlib $DlibPath `
  /dmdf $MetadataPath `
  "Talkies.Windows.exe"
```

#### Verify Signature

```powershell
# Verify signature
signtool verify /pa /v "Talkies.Windows.exe"

# Check if file is signed
signtool verify /pa "Talkies.Windows.exe"
```

### Signing in CI/CD

**GitHub Actions Example:**

```yaml
name: Build and Sign

on:
  release:
    types: [created]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: 8.0.x

      - name: Publish
        run: dotnet publish -c Release -r win-x64 --self-contained true

      - name: Sign with Azure Trusted Signing
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
        run: |
          # Install tools
          dotnet tool install --global AzureSignTool

          # Sign
          AzureSignTool sign `
            --azure-key-vault-url ${{ secrets.AZURE_KEYVAULT_URL }} `
            --azure-key-vault-client-id ${{ env.AZURE_CLIENT_ID }} `
            --azure-key-vault-client-secret ${{ env.AZURE_CLIENT_SECRET }} `
            --azure-key-vault-tenant-id ${{ env.AZURE_TENANT_ID }} `
            --azure-key-vault-certificate ${{ secrets.AZURE_KEYVAULT_CERTIFICATE }} `
            --timestamp-rfc3161 http://timestamp.digicert.com `
            --timestamp-digest sha256 `
            "windows\Talkies.Windows\bin\Release\net8.0-windows\win-x64\publish\Talkies.Windows.exe"
```

### Timestamping

**Always include a timestamp** when signing. This ensures signatures remain valid even after your certificate expires.

**Recommended Timestamp Servers (2025):**
- **Azure**: `http://timestamp.acs.microsoft.com` (for Trusted Signing)
- **DigiCert**: `http://timestamp.digicert.com`
- **Sectigo**: `http://timestamp.sectigo.com`
- **GlobalSign**: `http://timestamp.globalsign.com`

### SmartScreen Reputation

Even with a valid certificate, new applications trigger SmartScreen warnings until they build reputation:

1. **Reputation builds over time** (downloads, installs)
2. **EV certificates** skip initial warnings
3. **Azure Trusted Signing** skips warnings immediately
4. **Standard certificates** require 2-4 weeks of downloads

---

## Automated Build Process

The included `build-installer.ps1` script automates the entire build, sign, and package workflow.

### Usage

```powershell
# Basic build (unsigned)
.\packaging\windows\build-installer.ps1

# Build with code signing (PFX certificate)
.\packaging\windows\build-installer.ps1 `
  -SigningCertificate "C:\certs\talkies.pfx" `
  -CertificatePassword "your-password"

# Build with Azure Trusted Signing
.\packaging\windows\build-installer.ps1 `
  -UseAzureTrustedSigning `
  -AzureMetadataFile "C:\config\metadata.json"

# Build specific architecture
.\packaging\windows\build-installer.ps1 -Architecture arm64

# Clean build
.\packaging\windows\build-installer.ps1 -Clean
```

### Script Features

1. **Automated publish** (self-contained, single-file)
2. **Code signing** (traditional or Azure Trusted Signing)
3. **Inno Setup compilation** (if installed)
4. **Output organization** (versioned releases)
5. **Verification** (signature validation)
6. **Multi-architecture** support (x64, ARM64, x86)

### Output Structure

```
packaging/windows/output/
├── v1.0.0/
│   ├── Talkies-1.0.0-win-x64.exe          # Signed single-file executable
│   ├── Talkies-Setup-1.0.0-win-x64.exe    # Inno Setup installer
│   └── checksums.txt                       # SHA256 checksums
└── latest/
    └── (symlinks to latest version)
```

---

## Troubleshooting

### Issue: "Unknown Publisher" Warning

**Cause**: Application is not code signed
**Solution**: Sign with a valid code signing certificate

### Issue: SmartScreen Blocks Application

**Cause**: New certificate hasn't built reputation
**Solutions**:
- Use EV certificate (bypasses initial block)
- Use Azure Trusted Signing (bypasses immediately)
- Wait 2-4 weeks while building reputation
- Encourage users to click "More info" → "Run anyway"

### Issue: Large File Size (200MB+)

**Cause**: Self-contained publishing includes full .NET runtime
**Solutions**:
- Use framework-dependent publishing (requires user has .NET 8 installed)
- Enable `PublishTrimmed` (test thoroughly - may break reflection)
- Accept larger size for better user experience

### Issue: Application Fails to Start

**Cause**: Missing dependencies or incompatible architecture
**Solutions**:
- Ensure `IncludeNativeLibrariesForSelfExtract=true`
- Check architecture matches target system (x64 vs ARM64)
- Verify Windows 10 or later
- Test on clean VM without development tools

### Issue: Inno Setup Compilation Fails

**Cause**: Missing files or incorrect paths
**Solutions**:
- Ensure `dotnet publish` completed successfully
- Verify all files exist in publish directory
- Check file paths in `.iss` script
- Use absolute paths where possible

---

## Next Steps

1. **Immediate** (Week 1):
   - Implement self-contained publishing
   - Create Inno Setup script
   - Test on clean Windows installations

2. **Short-term** (Month 1):
   - Obtain code signing certificate (or setup Azure Trusted Signing)
   - Implement automated build script
   - Create GitHub release workflow

3. **Long-term** (Quarter 1):
   - Develop MSIX package for Microsoft Store
   - Implement auto-update mechanism
   - Consider WiX for enterprise customers

---

## References

- [.NET Application Publishing](https://learn.microsoft.com/en-us/dotnet/core/deploying/)
- [Single-File Deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview)
- [MSIX Packaging](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-packaging-dot-net)
- [WiX Toolset v5+ Documentation](https://wixtoolset.org/docs/releasenotes/)
- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [Azure Trusted Signing](https://learn.microsoft.com/en-us/azure/trusted-signing/)
- [SignTool.exe Documentation](https://learn.microsoft.com/en-us/dotnet/framework/tools/signtool-exe)
- [Code Signing Best Practices](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool)

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/yourusername/talkies/issues
- Documentation: https://talkies.app/docs
- Email: support@talkies.app
