# Quick Start Guide - Windows Installer

Get your first Windows installer built in under 10 minutes!

## Prerequisites

1. **Install .NET 8 SDK**
   ```powershell
   winget install Microsoft.DotNet.SDK.8
   ```

2. **Install Inno Setup** (optional, for installer)
   ```powershell
   winget install JRSoftware.InnoSetup
   ```

## Basic Build (No Signing)

### Step 1: Run Build Script

From repository root:

```powershell
.\packaging\windows\build-installer.ps1
```

This will:
- Build self-contained .NET 8 application
- Create single-file executable (~150MB)
- Generate checksums
- Output to `packaging/windows/output/v1.0.0/`

### Step 2: Test Application

```powershell
.\packaging\windows\output\latest\Talkies-1.0.0-win-x64.exe
```

**Note**: Windows will show "Unknown Publisher" warning since the app is not signed.

## Build with Inno Setup Installer

### Step 1: Create Inno Setup Script

Copy the example template:

```powershell
Copy-Item packaging\windows\Talkies.iss.example windows\Talkies.iss
```

### Step 2: Generate New GUID for AppId

Visit https://www.guidgenerator.com/ and generate a new GUID.

Edit `windows/Talkies.iss` and replace:
```pascal
AppId={{12345678-1234-1234-1234-123456789ABC}
```

With your new GUID. **Keep this GUID forever** - it's used for upgrade detection!

### Step 3: Build with Installer

```powershell
.\packaging\windows\build-installer.ps1
```

This will create TWO files:
1. `Talkies-1.0.0-win-x64.exe` - Standalone executable
2. `Talkies-Setup-1.0.0-win-x64.exe` - Installer

## Build with Code Signing

### Option A: Traditional Certificate (PFX)

If you have a code signing certificate:

```powershell
.\packaging\windows\build-installer.ps1 `
  -SigningCertificate "C:\path\to\certificate.pfx" `
  -CertificatePassword "your-password"
```

### Option B: Azure Trusted Signing (Recommended)

1. **Setup Azure Trusted Signing**
   - Create Azure account
   - Create "Trusted Signing" resource
   - Complete identity verification
   - Create certificate profile

2. **Create metadata file**

   Copy and edit the template:
   ```powershell
   Copy-Item packaging\windows\azure-metadata.json.example config\azure-metadata.json
   ```

   Edit `config/azure-metadata.json`:
   ```json
   {
     "Endpoint": "https://YOUR-ACCOUNT.codesigning.azure.net/",
     "CodeSigningAccountName": "YOUR-ACCOUNT-NAME",
     "CertificateProfileName": "YOUR-PROFILE-NAME"
   }
   ```

3. **Install Azure tools**
   ```powershell
   # Install .NET 8 Runtime
   winget install Microsoft.DotNet.Runtime.8

   # Install Azure Trusted Signing tools
   winget install Microsoft.Azure.TrustedSigningClientTools

   # Login to Azure
   az login
   ```

4. **Build and sign**
   ```powershell
   .\packaging\windows\build-installer.ps1 `
     -UseAzureTrustedSigning `
     -AzureMetadataFile "config\azure-metadata.json"
   ```

## Build for Different Architectures

### ARM64 (Surface Pro X, etc.)

```powershell
.\packaging\windows\build-installer.ps1 -Architecture arm64
```

### x86 (32-bit, legacy systems)

```powershell
.\packaging\windows\build-installer.ps1 -Architecture x86
```

## Clean Build

Remove all previous build artifacts:

```powershell
.\packaging\windows\build-installer.ps1 -Clean
```

## Advanced Usage

### Custom Version Number

```powershell
.\packaging\windows\build-installer.ps1 -Version "2.1.3"
```

### Debug Build

```powershell
.\packaging\windows\build-installer.ps1 -Configuration Debug
```

### Skip Installer Creation

```powershell
.\packaging\windows\build-installer.ps1 -SkipInnoSetup
```

### Skip Signing

```powershell
.\packaging\windows\build-installer.ps1 -SkipSigning
```

## Output Structure

After a successful build:

```
packaging/windows/output/
├── v1.0.0/
│   ├── Talkies-1.0.0-win-x64.exe          # Self-contained executable
│   ├── Talkies-Setup-1.0.0-win-x64.exe    # Inno Setup installer
│   └── checksums.txt                       # SHA256 checksums
└── latest/
    └── (links to latest version)
```

## Distribution

### Direct Download

Upload `Talkies-Setup-1.0.0-win-x64.exe` to your website or GitHub releases.

### GitHub Releases

```powershell
# Create release
gh release create v1.0.0 `
  --title "Talkies v1.0.0" `
  --notes "Release notes here" `
  packaging\windows\output\v1.0.0\*.exe
```

## Troubleshooting

### "Unknown Publisher" Warning

**Cause**: Application is not code signed.

**Solution**:
- Get a code signing certificate (see README.md)
- OR instruct users to click "More info" → "Run anyway"

### Large File Size (200MB+)

**Expected**: Self-contained builds include the full .NET 8 runtime (~150MB).

**To reduce**:
- Use framework-dependent build (requires users to install .NET 8)
- Accept larger size for better user experience (no dependencies)

### Inno Setup Not Found

**Solution**:
```powershell
# Install Inno Setup
winget install JRSoftware.InnoSetup

# OR download from
# https://jrsoftware.org/isinfo.php
```

### signtool.exe Not Found

**Solution**:
```powershell
# Install Windows SDK
winget install Microsoft.WindowsSDK

# OR download from
# https://developer.microsoft.com/windows/downloads/windows-sdk/
```

## Next Steps

1. **Test on clean machine**: Use a VM to test installation
2. **Get code signing certificate**: Eliminate "Unknown Publisher" warnings
3. **Setup CI/CD**: Automate builds with GitHub Actions (see README.md)
4. **Create MSIX package**: For Microsoft Store distribution

## Support

- **Full Documentation**: `packaging/windows/README.md`
- **GitHub Issues**: https://github.com/yourusername/talkies/issues
- **Website**: https://talkies.app

## Reference Commands

```powershell
# Basic unsigned build
.\packaging\windows\build-installer.ps1

# Build with PFX signing
.\packaging\windows\build-installer.ps1 -SigningCertificate "cert.pfx" -CertificatePassword "pass"

# Build with Azure signing
.\packaging\windows\build-installer.ps1 -UseAzureTrustedSigning -AzureMetadataFile "config\azure.json"

# ARM64 clean build
.\packaging\windows\build-installer.ps1 -Architecture arm64 -Clean

# Custom version
.\packaging\windows\build-installer.ps1 -Version "2.0.1"
```
