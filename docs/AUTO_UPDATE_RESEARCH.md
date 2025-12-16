# Auto-Update Systems Research for Talkies

**Document Version:** 1.0
**Last Updated:** 2025-12-16
**Purpose:** Comprehensive analysis of auto-update solutions for macOS and Windows desktop applications

---

## Executive Summary

This document provides an in-depth analysis of auto-update systems for the Talkies application across macOS (Swift) and Windows (.NET WPF) platforms. Based on extensive research, the recommended solutions are:

- **macOS:** Sparkle 2.x framework (industry standard, Swift-native, EdDSA signatures)
- **Windows:** NetSparkle (C# native, WPF support, compatible with Sparkle appcast format)
- **Update Server:** GitHub Releases (free, reliable, CDN-backed, version control integration)

Both solutions can share a similar appcast XML format and use GitHub Releases as a common update server, reducing infrastructure complexity while maintaining platform-specific optimizations.

---

## Table of Contents

1. [macOS Auto-Update Options](#1-macos-auto-update-options)
2. [Windows Auto-Update Options](#2-windows-auto-update-options)
3. [Cross-Platform Solutions](#3-cross-platform-solutions)
4. [Implementation Recommendations](#4-implementation-recommendations)
5. [Security Considerations](#5-security-considerations)
6. [References](#6-references)

---

## 1. macOS Auto-Update Options

### 1.1 Sparkle Framework

**Overview:** Sparkle is the de facto standard for macOS software updates, originally created by Andy Matuschak. It's an open-source Cocoa framework that has become ubiquitous in the Mac software ecosystem.

**Website:** https://sparkle-project.org/

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Industry Standard** | Used by thousands of macOS applications; proven track record |
| **Swift 6.0 Compatible** | Excellent Swift integration with modern async/await support |
| **Swift Package Manager** | Easy integration via SPM (no Xcode required) |
| **Delta Updates** | Binary diff updates (bsdiff/bspatch) reduce download sizes by 70-90% |
| **EdDSA Signatures** | Modern Ed25519 cryptographic signatures for security |
| **Sandboxed App Support** | Works with both sandboxed and non-sandboxed apps |
| **Customizable UI** | Native SwiftUI/AppKit components that match macOS design language |
| **Silent Updates** | Option for background updates with configurable user prompts |
| **Automatic Rollback** | Falls back to full updates if delta patching fails |
| **Active Maintenance** | Well-maintained with regular updates for new macOS versions |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **macOS-Only** | No cross-platform support (Windows/Linux need different solutions) |
| **Notarization Required** | Apps must be signed and notarized by Apple (Developer ID required - $99/year) |
| **Delta Generation Complexity** | Requires running `generate_appcast` tool for each release |
| **Learning Curve** | Initial setup requires understanding of appcast XML format and signing keys |
| **No Cloud Service** | Must host your own update server (though GitHub Releases works well) |

#### Implementation Complexity: **Medium**

**Setup Steps:**
1. Add Sparkle via Swift Package Manager: `https://github.com/sparkle-project/Sparkle`
2. Generate EdDSA key pair using `generate_keys` tool
3. Configure `Info.plist` with feed URL and public key
4. Initialize `SPUStandardUpdaterController` in `TalkiesApp.swift`
5. Create appcast XML with `generate_appcast` tool
6. Sign and notarize release builds
7. Upload archives and appcast to GitHub Releases

**Code Example:**
```swift
import Sparkle

@main
struct TalkiesApp: App {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
```

#### Delta Updates Details

Sparkle's delta update system is highly efficient:
- Uses bsdiff/bspatch algorithms for binary diffing
- Sparkle 2.1+ uses LZMA compression (smaller than older bzip2)
- Automatically generates `.delta` files for each version pair
- Falls back to full update if delta fails checksum verification
- Best practices: avoid renaming files, separate changing/static content

**Typical Size Savings:**
- Minor updates (bug fixes): 80-95% reduction
- Feature updates: 60-80% reduction
- Major updates: 40-70% reduction

### 1.2 Apple's Built-in Update Mechanisms

#### Mac App Store Updates

**Pros:**
- Completely managed by Apple (zero infrastructure)
- Automatic background updates
- Built-in user trust (App Store badge)
- Integrated with macOS System Preferences

**Cons:**
- 30% revenue cut for paid apps/subscriptions
- Strict app review process (can delay critical updates)
- Sandboxing required (limits functionality)
- Cannot target on-device transcription for Whisper (App Store privacy restrictions)
- No control over update timing
- Limited analytics

**Verdict:** ❌ **Not Recommended** for Talkies due to sandboxing limitations and Whisper.cpp integration requirements.

#### Notarization + Manual Updates

**Pros:**
- Simple approach: users download new DMG manually
- No framework dependencies

**Cons:**
- Poor user experience (manual checking/downloading)
- Lower adoption of updates
- No delta updates
- Users may run outdated/insecure versions

**Verdict:** ❌ **Not Recommended** - users expect automatic updates in 2025.

### 1.3 Custom Update Server Solution

**Pros:**
- Complete control over infrastructure
- Custom analytics and A/B testing
- Potential for user segmentation

**Cons:**
- High development cost (months of work)
- Ongoing maintenance burden
- CDN costs for bandwidth
- Security vulnerabilities if not done correctly
- Must implement code signing, delta updates, rollback logic

**Verdict:** ❌ **Not Recommended** - Sparkle provides all necessary features.

---

## 2. Windows Auto-Update Options

### 2.1 NetSparkle (NetSparkleUpdater)

**Overview:** NetSparkle is a C# software update framework inspired by Sparkle, designed for .NET applications. It's compatible with .NET 8.0 and has pre-built WPF UI components.

**GitHub:** https://github.com/NetSparkleUpdater/NetSparkle
**NuGet:** `NetSparkleUpdater.SparkleUpdater` + `NetSparkleUpdater.UI.WPF`

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Native .NET/C#** | Written entirely in C#, no P/Invoke or native dependencies |
| **.NET 8.0 Compatible** | Fully supports modern .NET with async/await patterns |
| **WPF UI Included** | Pre-built WPF windows for update prompts (customizable) |
| **EdDSA Signatures** | Same Ed25519 signing as Sparkle (secure, modern) |
| **Appcast Compatible** | Similar XML format to Sparkle (can share structure) |
| **NuGet Integration** | Easy installation via Visual Studio/Rider package manager |
| **Active Maintenance** | Version 3.0+ actively maintained (updated 2024) |
| **Cross-Platform .NET** | Also supports Avalonia UI (for future Linux .NET port) |
| **Highly Configurable** | UserInteractionMode settings (download-only, silent, etc.) |
| **Release Notes Support** | Markdown/HTML release notes displayed in update dialog |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **No Built-in Delta Updates** | Downloads full installers each time (no binary diffs) |
| **Smaller Community** | Less widely used than Squirrel.Windows or WinSparkle |
| **Documentation Gaps** | Some advanced features lack detailed guides |
| **90-Second Timeout** | Update launcher only waits 90 seconds for app to close |
| **Less Mature** | Newer than WinSparkle/Squirrel (fewer edge cases tested) |

#### Implementation Complexity: **Medium**

**Setup Steps:**
1. Install NuGet packages: `NetSparkleUpdater.SparkleUpdater` + `NetSparkleUpdater.UI.WPF`
2. Generate Ed25519 keys using `netsparkle-generate-appcast` CLI tool
3. Initialize `SparkleUpdater` in `App.xaml.cs` or `MainViewModel.cs`
4. Create appcast XML with version info and release notes
5. Sign installer with Authenticode certificate (optional but recommended)
6. Upload installer and appcast to GitHub Releases

**Code Example:**
```csharp
using NetSparkleUpdater;
using NetSparkleUpdater.SignatureVerifiers;
using NetSparkleUpdater.UI.WPF;

public class MainViewModel
{
    private SparkleUpdater _sparkle;

    public void InitializeUpdater()
    {
        _sparkle = new SparkleUpdater(
            "https://github.com/yourorg/talkies/releases/latest/download/appcast.xml",
            new Ed25519Checker(SecurityMode.Strict, "YOUR_PUBLIC_KEY")
        )
        {
            UIFactory = new UIFactory(System.Drawing.Icon.ExtractAssociatedIcon(Assembly.GetEntryAssembly().Location)),
            RelaunchAfterUpdate = true,
            CustomInstallerArguments = "/SILENT /CLOSEAPPLICATIONS"
        };

        _sparkle.StartLoop(true, true); // Check now, then periodically
    }
}
```

### 2.2 WinSparkle

**Overview:** A Windows port of the original Sparkle framework, written in C++ with C API for language bindings.

**Website:** https://winsparkle.org/

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Mature & Stable** | Used by many Windows applications since 2012 |
| **Language Agnostic** | C API works with C++, C#, Python, etc. via P/Invoke |
| **Automatic UI** | Built-in update dialogs (Windows native look) |
| **Delta Updates** | Supports binary delta patches (smaller downloads) |
| **App Store Style** | User-friendly update experience |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **C++ Native Library** | Requires P/Invoke for .NET integration (more complex) |
| **No Official .NET Binding** | Must write your own interop code |
| **Less Active Development** | Slower release cycle compared to NetSparkle |
| **Older Signature System** | Still uses DSA signatures (EdDSA support unclear) |
| **Deployment Complexity** | Must bundle native DLL with .NET app |

#### Implementation Complexity: **High** (for .NET)

**Verdict:** ⚠️ **Not Recommended** for Talkies - NetSparkle is better suited for .NET 8.0 WPF.

### 2.3 Squirrel.Windows

**Overview:** An installation and update framework popular in the Electron ecosystem, designed for per-user installations with silent updates.

**GitHub:** https://github.com/Squirrel/Squirrel.Windows

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Silent Updates** | Philosophy of automatic, user-transparent updates |
| **Delta Updates** | Efficient binary delta patches |
| **Update Channels** | Built-in support for stable/beta/nightly channels |
| **C# Native** | Written in C# for .NET applications |
| **Electron Integration** | Very popular in Electron app community |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **Project Status** | Officially deprecated in 2019; maintenance unclear |
| **No GUI by Design** | No built-in update dialogs (silent-only approach) |
| **Installation Model** | Optimized for per-user installs (harder for machine-wide) |
| **Update Restrictions** | Can only update when app runs as installing user |
| **Uncertain Future** | Sporadic community commits, no clear maintainer |
| **Security Concerns** | May not receive timely security patches |

#### Implementation Complexity: **Medium-High**

**Verdict:** ❌ **Not Recommended** - deprecated status and lack of GUI makes NetSparkle a better choice.

### 2.4 ClickOnce Deployment

**Overview:** Microsoft's official deployment technology for .NET applications, integrated into Visual Studio.

**Documentation:** https://learn.microsoft.com/en-us/dotnet/desktop/wpf/app-development/deploying-a-wpf-application-wpf

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Microsoft Official** | Built into .NET and Visual Studio |
| **Automatic Updates** | Checks for updates on every launch |
| **Easy Deployment** | Publish directly from Visual Studio |
| **Rollback Support** | Can revert to previous versions |
| **Start Menu Integration** | Automatic shortcuts and uninstall entries |
| **Online/Offline Modes** | Can run from network or install locally |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **Security Warnings** | Users see trust prompts (not automatically granted full trust) |
| **Limited API in .NET 7+** | ApplicationDeployment class deprecated; must use environment variables |
| **File Extension Issues** | Publishes with `.deploy` extensions by default (can disable) |
| **.NET Framework Dependency** | Requires .NET runtime pre-installed on client |
| **Perceived as Legacy** | Less popular for modern .NET apps (vs. MSIX) |
| **Deployment Complexity** | Understanding manifest/signing can be confusing |

#### Implementation Complexity: **Low-Medium**

**Verdict:** ⚠️ **Possible Alternative** but NetSparkle offers more control and modern .NET 8+ support.

### 2.5 MSIX with Auto-Update

**Overview:** Modern Windows app packaging format with built-in update support via App Installer files (.appinstaller).

**Documentation:** https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Modern Windows Standard** | Recommended by Microsoft for Windows 10/11 |
| **Built-in Auto-Update** | Native support via .appinstaller files |
| **Sideload Support** | Can distribute outside Windows Store (since Windows 10 1709) |
| **Update Configuration** | Check on launch, scheduled checks (every 6 hours), or manual |
| **Automatic Repair** | Self-healing if files corrupted |
| **No Sideloading Toggle** | Windows 11 doesn't require enabling sideload mode |
| **Delta Updates** | Windows can download only changed blocks |
| **Trusted Certificates** | Code signing creates system trust |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **Packaging Complexity** | Creating MSIX packages has learning curve |
| **Windows 10 1709+** | Requires relatively modern Windows (2017+) |
| **AppInstaller Requirement** | Updates only work when installed via .appinstaller file |
| **Limited Analytics** | No built-in update metrics/tracking |
| **Restrictions** | Some legacy APIs unavailable in MSIX containerization |
| **Tooling** | Requires Advanced Installer, Visual Studio, or MSIX Hero |

#### Implementation Complexity: **Medium-High**

**Verdict:** ⚠️ **Future Consideration** - excellent long-term solution but steeper learning curve than NetSparkle.

### 2.6 WinGet (Windows Package Manager)

**Overview:** Microsoft's official package manager, similar to apt/brew, with automatic update capabilities.

**Documentation:** https://learn.microsoft.com/en-us/windows/package-manager/winget/

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Official Microsoft Tool** | Shipped with Windows 11 by default |
| **Central Repository** | Listed in winget community repository |
| **CLI Auto-Update** | `winget upgrade --all` updates everything |
| **Free Distribution** | No hosting costs (uses GitHub Releases) |
| **Integration Options** | Works with Intune MDM for enterprise |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **User-Initiated Only** | No automatic background updates (user must run command) |
| **Manifest Submission** | Must submit PRs to winget-pkgs repository |
| **Approval Delays** | Community review required for each version |
| **No Built-in GUI** | Command-line only (no update prompts in app) |
| **Limited Adoption** | Users must know to use winget |

#### Implementation Complexity: **Low** (for listing) / **N/A** (for in-app updates)

**Verdict:** ✅ **Supplementary Distribution** - great for power users but doesn't replace in-app updates.

---

## 3. Cross-Platform Solutions

### 3.1 GitHub Releases as Update Server

**Overview:** GitHub Releases provides free, reliable hosting for application releases with built-in version tagging, release notes, and CDN-backed asset downloads.

#### Pros

| Advantage | Description |
|-----------|-------------|
| **Free Hosting** | No bandwidth costs, even for large files |
| **Global CDN** | Fast downloads worldwide via GitHub's infrastructure |
| **Version Control Integration** | Git tags automatically become releases |
| **Release Notes** | Markdown-formatted changelogs per version |
| **API Access** | Programmatic access for automated tooling |
| **Access Control** | Public/private releases for beta testing |
| **Reliability** | GitHub's 99.9%+ uptime SLA |
| **CI/CD Integration** | Easily automated with GitHub Actions |

#### Cons

| Disadvantage | Description |
|--------------|-------------|
| **File Size Limits** | 2 GB per file, 10 GB per release (sufficient for most apps) |
| **No Custom Analytics** | Can't track download metrics beyond basic stats |
| **Rate Limiting** | API calls limited (60/hour unauthenticated, 5000/hour authenticated) |
| **GitHub Dependency** | Outages affect update availability |

#### Implementation

**Directory Structure:**
```
talkies/
├── releases/
│   ├── mac/
│   │   ├── Talkies-1.0.0.dmg
│   │   ├── Talkies-1.0.1.dmg
│   │   └── appcast.xml
│   └── windows/
│       ├── TalkiesSetup-1.0.0.exe
│       ├── TalkiesSetup-1.0.1.exe
│       └── appcast.xml
```

**GitHub Actions Workflow:**
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release-mac:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build macOS app
        run: cd mac && swift build -c release
      - name: Notarize
        run: ./scripts/notarize.sh
      - name: Generate appcast
        run: ./bin/generate_appcast releases/mac/
      - name: Upload Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            releases/mac/*.dmg
            releases/mac/appcast.xml

  release-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Windows installer
        run: cd windows && dotnet build -c Release
      - name: Sign installer
        run: ./scripts/sign-windows.ps1
      - name: Generate appcast
        run: ./bin/netsparkle-generate-appcast releases/windows/
      - name: Upload Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            releases/windows/*.exe
            releases/windows/appcast.xml
```

**Appcast URL Pattern:**
- macOS: `https://github.com/yourorg/talkies/releases/latest/download/appcast-mac.xml`
- Windows: `https://github.com/yourorg/talkies/releases/latest/download/appcast-win.xml`

### 3.2 Semantic Versioning

**Specification:** https://semver.org/

#### Format: MAJOR.MINOR.PATCH

- **MAJOR:** Incompatible API changes (e.g., 1.0.0 → 2.0.0)
- **MINOR:** Backward-compatible new features (e.g., 1.0.0 → 1.1.0)
- **PATCH:** Backward-compatible bug fixes (e.g., 1.0.0 → 1.0.1)

#### Pre-release Tags

- **Alpha:** `1.0.0-alpha.1` (very early, unstable)
- **Beta:** `1.0.0-beta.1` (feature-complete, testing)
- **Release Candidate:** `1.0.0-rc.1` (final testing before stable)

#### Examples

| Version | Meaning |
|---------|---------|
| `1.0.0` | First stable release |
| `1.1.0` | Added new feature (e.g., sentiment analysis plugin) |
| `1.1.1` | Fixed bug in sentiment analysis |
| `1.2.0-beta.1` | First beta of upcoming 1.2.0 release |
| `2.0.0` | Breaking change (e.g., new settings file format) |

### 3.3 Update Channels

#### Stable Channel

**Purpose:** Production-ready releases for all users
**Cadence:** Every 4-8 weeks
**Version:** `X.Y.Z` (no suffix)
**Testing:** Full QA, beta period completed
**Rollout:** 100% of users

**Appcast URL:** `appcast.xml` or `appcast-stable.xml`

#### Beta Channel

**Purpose:** Early access to upcoming features for testers
**Cadence:** Every 1-2 weeks
**Version:** `X.Y.Z-beta.N`
**Testing:** Automated tests + manual smoke testing
**Rollout:** Opt-in only (10-20% of active users)

**Appcast URL:** `appcast-beta.xml`

#### Nightly Channel (Optional)

**Purpose:** Bleeding-edge builds for developers/power users
**Cadence:** Daily (automated)
**Version:** `X.Y.Z-nightly.YYYYMMDD`
**Testing:** Automated tests only
**Rollout:** Opt-in only (<5% of users)

**Appcast URL:** `appcast-nightly.xml`

#### Implementation

**Settings UI:**
```
Update Channel: [Stable ▼]
                 Stable (Recommended)
                 Beta (Early access to new features)
                 Nightly (Unstable, for testing only)

☐ Automatically download and install updates
☐ Notify me when updates are available
```

**Config Storage:**
- macOS: `UserDefaults` → `com.yourorg.talkies.updateChannel`
- Windows: `~/.talkies/config.json` → `"updateChannel": "stable"`

**Channel Switching:**
```csharp
// Windows (NetSparkle)
public void SetUpdateChannel(string channel)
{
    string appcastUrl = channel switch
    {
        "beta" => "https://github.com/yourorg/talkies/releases/latest/download/appcast-beta.xml",
        "nightly" => "https://github.com/yourorg/talkies/releases/latest/download/appcast-nightly.xml",
        _ => "https://github.com/yourorg/talkies/releases/latest/download/appcast.xml"
    };

    _sparkle.AppcastUrl = appcastUrl;
    _sparkle.CheckForUpdatesAtUserRequest();
}
```

---

## 4. Implementation Recommendations

### 4.1 Recommended Solution: macOS

**Framework:** Sparkle 2.x
**Integration Method:** Swift Package Manager
**Update Server:** GitHub Releases
**Signature Method:** EdDSA (Ed25519)

#### Implementation Plan

**Phase 1: Basic Setup (2-3 days)**
1. Add Sparkle via SPM to `mac/Package.swift`
2. Generate EdDSA key pair (store private key in 1Password/secrets manager)
3. Configure `Info.plist` with feed URL and public key
4. Initialize updater in `TalkiesApp.swift`
5. Add "Check for Updates..." menu item in app menu

**Phase 2: Release Automation (2-3 days)**
1. Create GitHub Actions workflow for macOS builds
2. Integrate code signing with Apple Developer ID certificate
3. Add notarization step (required for macOS 10.15+)
4. Generate appcast XML with `generate_appcast` tool
5. Upload DMG and appcast to GitHub Releases

**Phase 3: Delta Updates (1-2 days)**
1. Configure `generate_appcast` to create delta patches
2. Test delta update process between versions
3. Verify fallback to full update on delta failure

**Phase 4: Polish (1-2 days)**
1. Customize update dialog UI with SwiftUI
2. Add release notes markdown rendering
3. Test update flow end-to-end (various macOS versions)
4. Add analytics/telemetry for update adoption rates

**Total Estimate:** 6-10 days

#### Code Integration Points

**File:** `mac/Sources/Talkies/TalkiesApp.swift`
```swift
import Sparkle

@main
struct TalkiesApp: App {
    @StateObject private var appState = AppState()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
```

**File:** `mac/Sources/Talkies/Views/CheckForUpdatesView.swift`
```swift
import SwiftUI
import Sparkle

struct CheckForUpdatesView: View {
    @ObservedObject var updater: SPUUpdater

    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
```

**File:** `mac/Info.plist`
```xml
<key>SUFeedURL</key>
<string>https://github.com/yourorg/talkies/releases/latest/download/appcast-mac.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY_HERE</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

### 4.2 Recommended Solution: Windows

**Framework:** NetSparkle (NetSparkleUpdater)
**Integration Method:** NuGet Package Manager
**Update Server:** GitHub Releases
**Signature Method:** EdDSA (Ed25519)

#### Implementation Plan

**Phase 1: Basic Setup (2-3 days)**
1. Install NuGet packages: `NetSparkleUpdater.SparkleUpdater` + `NetSparkleUpdater.UI.WPF`
2. Generate EdDSA key pair with `netsparkle-generate-appcast` CLI
3. Initialize updater in `MainViewModel.cs` or `App.xaml.cs`
4. Add "Check for Updates" menu item to MainWindow

**Phase 2: Installer Creation (2-3 days)**
1. Create Inno Setup or WiX installer project
2. Configure installer for silent install (`/SILENT /CLOSEAPPLICATIONS`)
3. Sign installer with Authenticode certificate (optional but recommended)
4. Test install/uninstall flow on clean Windows VM

**Phase 3: Release Automation (2-3 days)**
1. Create GitHub Actions workflow for Windows builds
2. Build installer with `dotnet publish` + packaging tool
3. Generate appcast XML with version/release notes
4. Upload installer and appcast to GitHub Releases

**Phase 4: Polish (1-2 days)**
1. Customize WPF update dialog appearance
2. Add release notes rendering (Markdown/HTML)
3. Test update flow on Windows 10/11
4. Add update settings to SettingsView (auto-update toggle, channel selection)

**Total Estimate:** 7-11 days

#### Code Integration Points

**File:** `windows/Talkies.Windows/ViewModels/MainViewModel.cs`
```csharp
using NetSparkleUpdater;
using NetSparkleUpdater.SignatureVerifiers;
using NetSparkleUpdater.UI.WPF;
using System.Reflection;

namespace Talkies.Windows.ViewModels
{
    public class MainViewModel : ViewModelBase
    {
        private SparkleUpdater _sparkle;

        public void InitializeUpdater()
        {
            var appcastUrl = _settingsService.UpdateChannel switch
            {
                "beta" => "https://github.com/yourorg/talkies/releases/latest/download/appcast-win-beta.xml",
                _ => "https://github.com/yourorg/talkies/releases/latest/download/appcast-win.xml"
            };

            _sparkle = new SparkleUpdater(
                appcastUrl,
                new Ed25519Checker(SecurityMode.Strict, "YOUR_PUBLIC_KEY")
            )
            {
                UIFactory = new UIFactory(Icon.ExtractAssociatedIcon(Assembly.GetEntryAssembly().Location)),
                RelaunchAfterUpdate = true,
                CustomInstallerArguments = "/SILENT /CLOSEAPPLICATIONS",
                CheckServerFileName = false // Don't validate server filename
            };

            // Check for updates on startup (silent)
            _sparkle.StartLoop(checkNow: true, forceInitialCheck: false);

            // Optional: Show update UI after initialization
            _sparkle.CheckForUpdatesQuietly();
        }

        public ICommand CheckForUpdatesCommand => new RelayCommand(() =>
        {
            _sparkle?.CheckForUpdatesAtUserRequest();
        });

        public void Dispose()
        {
            _sparkle?.Dispose();
        }
    }
}
```

**File:** `windows/Talkies.Windows/App.xaml.cs`
```csharp
protected override void OnStartup(StartupEventArgs e)
{
    base.OnStartup(e);

    var mainViewModel = new MainViewModel();
    mainViewModel.InitializeUpdater();

    var mainWindow = new MainWindow
    {
        DataContext = mainViewModel
    };

    mainWindow.Show();
}
```

**File:** `windows/Talkies.Windows/Views/SettingsView.xaml`
```xml
<StackPanel>
    <TextBlock Text="Updates" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>

    <CheckBox IsChecked="{Binding AutoCheckForUpdates}" Margin="0,5">
        <TextBlock Text="Automatically check for updates" TextWrapping="Wrap"/>
    </CheckBox>

    <CheckBox IsChecked="{Binding AutoDownloadUpdates}" Margin="0,5">
        <TextBlock Text="Automatically download and install updates" TextWrapping="Wrap"/>
    </CheckBox>

    <StackPanel Margin="0,10,0,0">
        <TextBlock Text="Update Channel:" Margin="0,0,0,5"/>
        <ComboBox SelectedItem="{Binding UpdateChannel}" Width="200" HorizontalAlignment="Left">
            <ComboBoxItem Content="Stable (Recommended)"/>
            <ComboBoxItem Content="Beta"/>
        </ComboBox>
    </StackPanel>

    <Button Content="Check for Updates Now"
            Command="{Binding CheckForUpdatesCommand}"
            Margin="0,15,0,0"
            Width="200"
            HorizontalAlignment="Left"/>
</StackPanel>
```

### 4.3 Shared Update Server Infrastructure

**Repository Structure:**
```
talkies/
├── .github/
│   └── workflows/
│       ├── release-mac.yml
│       ├── release-windows.yml
│       └── release-combined.yml
├── releases/
│   ├── mac/
│   │   └── appcast-mac.xml (generated)
│   └── windows/
│       └── appcast-win.xml (generated)
├── scripts/
│   ├── generate-appcast-mac.sh
│   ├── generate-appcast-windows.ps1
│   ├── notarize-mac.sh
│   └── sign-windows.ps1
└── keys/
    ├── README.md (how to generate keys)
    └── .gitignore (never commit private keys!)
```

**Appcast XML Format (Sparkle-compatible):**
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Talkies for macOS</title>
        <link>https://talkies.app</link>
        <description>Voice transcription updates</description>
        <language>en</language>

        <item>
            <title>Version 1.1.0 - AI Enhancement Features</title>
            <sparkle:releaseNotesLink>https://github.com/yourorg/talkies/releases/tag/v1.1.0</sparkle:releaseNotesLink>
            <pubDate>Mon, 16 Dec 2024 12:00:00 +0000</pubDate>
            <enclosure
                url="https://github.com/yourorg/talkies/releases/download/v1.1.0/Talkies-1.1.0.dmg"
                sparkle:version="1.1.0"
                sparkle:shortVersionString="1.1.0"
                sparkle:edSignature="BASE64_SIGNATURE_HERE"
                length="45829120"
                type="application/octet-stream"/>

            <!-- Delta update from 1.0.0 to 1.1.0 -->
            <sparkle:deltas>
                <enclosure
                    url="https://github.com/yourorg/talkies/releases/download/v1.1.0/Talkies-1.0.0-to-1.1.0.delta"
                    sparkle:version="1.1.0"
                    sparkle:shortVersionString="1.1.0"
                    sparkle:deltaFrom="1.0.0"
                    sparkle:edSignature="DELTA_SIGNATURE_HERE"
                    length="8294400"
                    type="application/octet-stream"/>
            </sparkle:deltas>
        </item>

        <item>
            <title>Version 1.0.0 - Initial Release</title>
            <sparkle:releaseNotesLink>https://github.com/yourorg/talkies/releases/tag/v1.0.0</sparkle:releaseNotesLink>
            <pubDate>Mon, 01 Dec 2024 12:00:00 +0000</pubDate>
            <enclosure
                url="https://github.com/yourorg/talkies/releases/download/v1.0.0/Talkies-1.0.0.dmg"
                sparkle:version="1.0.0"
                sparkle:shortVersionString="1.0.0"
                sparkle:edSignature="BASE64_SIGNATURE_HERE"
                length="43958016"
                type="application/octet-stream"/>
        </item>
    </channel>
</rss>
```

**Benefits of Shared Infrastructure:**
- Single source of truth for releases (Git tags)
- Consistent versioning across platforms
- Automated release process via GitHub Actions
- Free CDN-backed hosting
- Version control for appcast files
- Easy rollback capabilities

---

## 5. Security Considerations

### 5.1 Code Signing Requirements

#### macOS

**Certificate:** Apple Developer ID Application Certificate
**Cost:** $99/year (Apple Developer Program membership)
**Process:**
1. Create certificate signing request (CSR) in Keychain Access
2. Submit CSR to Apple Developer portal
3. Download and install certificate
4. Sign app with `codesign` command
5. Notarize app with Apple's notary service
6. Staple notarization ticket to DMG

**Security Benefits:**
- Proves app origin (users can verify developer identity)
- Gatekeeper allows app to run without warnings
- Required for auto-updates to work properly
- Prevents malware from impersonating your app

**Sparkle Requirement:** EdDSA signatures (in addition to code signing)

#### Windows

**Certificate:** Authenticode Code Signing Certificate
**Cost:** $70-$500/year (varies by Certificate Authority)
**Providers:**
- DigiCert (expensive but trusted)
- Sectigo (affordable, widely accepted)
- SSL.com (budget option)

**Process:**
1. Purchase certificate from CA
2. Complete identity verification (business validation)
3. Install certificate in Windows certificate store
4. Sign EXE/MSI with `signtool.exe`

**Security Benefits:**
- SmartScreen doesn't block signed apps (after reputation builds)
- Users see verified publisher name
- Required for Windows Store/MSIX
- Prevents tampering detection

**NetSparkle Requirement:** EdDSA signatures (in addition to Authenticode)

### 5.2 EdDSA (Ed25519) Signatures

**Overview:** EdDSA is a modern, secure signature algorithm recommended by both Sparkle and NetSparkle for verifying update authenticity.

**Advantages over DSA/RSA:**
- Smaller key size (256-bit vs 2048-bit RSA)
- Faster signature generation/verification
- Immune to timing attacks
- More secure cryptographic properties

**Key Generation:**

**macOS (Sparkle):**
```bash
# Download generate_keys tool from Sparkle releases
./bin/generate_keys

# Output:
# Private key (keep secret!): AbCdEf1234567890...
# Public key (add to Info.plist): XyZ123AbCdEf...
```

**Windows (NetSparkle):**
```bash
# Install CLI tool
dotnet tool install --global NetSparkleUpdater.Tools.AppCastGenerator

# Generate keys
netsparkle-generate-appcast --generate-keys

# Output:
# Private key: base64_private_key_string
# Public key: base64_public_key_string
```

**Storage:**
- **Private Key:** Store in secrets manager (GitHub Secrets, 1Password, Azure Key Vault)
- **Public Key:** Embed in application (Info.plist, app.config, hardcoded string)

**Usage:**
- Sign each release with private key (automated in CI/CD)
- App verifies downloads using embedded public key
- Man-in-the-middle attacks prevented (even if HTTPS compromised)

### 5.3 HTTPS Requirements

**Both Sparkle and NetSparkle require HTTPS for appcast URLs.**

**Why HTTPS is Mandatory:**
- Prevents attackers from injecting malicious updates
- Protects appcast XML from tampering
- GitHub Releases uses HTTPS by default

**Certificate Validation:**
- Sparkle enforces certificate pinning
- NetSparkle validates server certificates
- Self-signed certificates will fail (use proper CA certs)

### 5.4 Update Rollback Strategy

**Scenario:** Critical bug in new version requires reverting users to previous version.

**Sparkle Approach:**
1. Publish new release with older version number (e.g., 1.0.1 to fix broken 1.1.0)
2. Update appcast to show 1.0.1 as latest
3. Users on 1.1.0 will "downgrade" to 1.0.1 (if configured to allow)

**NetSparkle Approach:**
- Similar to Sparkle (version-based rollback)
- Can configure to allow downgrades with `AllowDowngrade = true`

**Best Practice:**
- Test thoroughly before releasing (use beta channel first)
- Monitor crash reports and analytics post-release
- Keep last 3-5 versions available in GitHub Releases
- Document rollback procedure in runbooks

### 5.5 Privacy Considerations

**Update Check Data Transmitted:**
- Current app version
- Operating system version
- System architecture (x86_64, arm64)
- IP address (for geolocation/CDN routing)

**Privacy-Friendly Practices:**
- Don't collect user identifiers (no device IDs, email, etc.)
- Use aggregated analytics only (e.g., "1000 users on v1.0.0")
- Document data collection in privacy policy
- Respect "do not check for updates" setting

**GDPR Compliance:**
- Update checks don't require consent (legitimate interest)
- Don't log personally identifiable information
- Provide opt-out in settings (disable auto-checks)

---

## 6. References

### Documentation

**Sparkle:**
- Official Documentation: https://sparkle-project.org/documentation/
- GitHub Repository: https://github.com/sparkle-project/Sparkle
- Delta Updates Guide: https://sparkle-project.org/documentation/delta-updates/
- Publishing Updates: https://sparkle-project.org/documentation/publishing/

**NetSparkle:**
- GitHub Repository: https://github.com/NetSparkleUpdater/NetSparkle
- Documentation Site: https://netsparkleupdater.github.io/NetSparkle/
- NuGet Package: https://www.nuget.org/packages/NetSparkleUpdater.SparkleUpdater

**macOS Code Signing:**
- Notarizing macOS Software: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Code Signing Guide: https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/

**Windows Update Solutions:**
- MSIX Auto-Update: https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview
- ClickOnce Deployment: https://learn.microsoft.com/en-us/dotnet/desktop/wpf/app-development/deploying-a-wpf-application-wpf
- WinGet Documentation: https://learn.microsoft.com/en-us/windows/package-manager/winget/

**Semantic Versioning:**
- SemVer Specification: https://semver.org/

### Articles & Guides

- "The best update frameworks for Windows": https://omaha-consulting.com/best-update-framework-for-windows
- "macOS Notarization, Code Signing, and Sparkle": https://duo.com/labs/tech-notes/macos-notarization-hardware-backed-code-signing-keys-and-sparkle-code-signing-issues
- "Seamless Updates for Windows Apps": https://www.oneleet.com/blog/crafting-a-custom-windows-auto-updater-for-go-powered-desktop-apps
- "Distributing Windows Applications": https://www.augmentedmind.de/2021/05/30/distributing-windows-applications/

### Tools

**Appcast Generators:**
- Sparkle: `generate_appcast` (bundled with framework)
- NetSparkle: `dotnet tool install --global NetSparkleUpdater.Tools.AppCastGenerator`

**Code Signing:**
- macOS: `codesign`, `xcrun notarytool`
- Windows: `signtool.exe` (Windows SDK)

**Packaging:**
- macOS: `create-dmg` (https://github.com/create-dmg/create-dmg)
- Windows: Inno Setup (https://jrsoftware.org/isinfo.php), WiX Toolset (https://wixtoolset.org/)

**MSIX Tools:**
- MSIX Hero: https://msixhero.net/
- Advanced Installer: https://www.advancedinstaller.com/

---

## Appendix A: Cost Analysis

### Infrastructure Costs

| Component | macOS | Windows | Notes |
|-----------|-------|---------|-------|
| **Developer Certificate** | $99/year | $70-500/year | Apple Developer Program / Authenticode cert |
| **Update Server Hosting** | $0 | $0 | GitHub Releases (free tier sufficient) |
| **CDN Bandwidth** | $0 | $0 | Included with GitHub |
| **Delta Update Storage** | $0 | N/A | GitHub Releases included |
| **Monitoring/Analytics** | $0-49/mo | $0-49/mo | Optional (Sentry, Mixpanel, etc.) |
| **Total Year 1** | $99-687 | $70-1088 | Depends on certificate provider |

**Conclusion:** Very affordable - primary cost is code signing certificates (mandatory for security).

### Development Time Estimate

| Phase | macOS (Sparkle) | Windows (NetSparkle) |
|-------|-----------------|----------------------|
| Initial Setup | 2-3 days | 2-3 days |
| Release Automation | 2-3 days | 2-3 days |
| Installer Creation | 1 day (DMG) | 2-3 days (EXE + config) |
| Delta Updates | 1-2 days | N/A (not supported) |
| Polish & Testing | 1-2 days | 1-2 days |
| **Total** | **6-10 days** | **7-11 days** |

**Combined Estimate:** 13-21 days for both platforms (parallelizable if separate developers)

---

## Appendix B: Comparison Table Summary

| Feature | Sparkle (macOS) | NetSparkle (Windows) | Squirrel.Windows | ClickOnce | MSIX |
|---------|-----------------|----------------------|------------------|-----------|------|
| **Delta Updates** | ✅ Yes (bsdiff) | ❌ No | ✅ Yes | ❌ No | ✅ Yes |
| **EdDSA Signatures** | ✅ Ed25519 | ✅ Ed25519 | ❌ No | ⚠️ Authenticode | ⚠️ Authenticode |
| **Swift/C# Native** | ✅ Swift | ✅ C# | ✅ C# | ✅ .NET | ⚠️ Packaging |
| **WPF UI Support** | N/A | ✅ Yes | ❌ No GUI | ⚠️ Basic | ⚠️ Limited |
| **Active Maintenance** | ✅ Active | ✅ Active | ❌ Deprecated | ⚠️ Legacy | ✅ Microsoft |
| **GitHub Integration** | ✅ Excellent | ✅ Good | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual |
| **Update Channels** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Limited | ⚠️ Limited |
| **Setup Complexity** | 🟡 Medium | 🟡 Medium | 🟡 Medium-High | 🟢 Low-Medium | 🔴 Medium-High |
| **Documentation** | 🟢 Excellent | 🟡 Good | 🔴 Minimal | 🟢 Microsoft | 🟢 Microsoft |

**Legend:**
- ✅ Full Support
- ⚠️ Limited/Partial Support
- ❌ Not Supported/Not Recommended
- 🟢 Low Complexity
- 🟡 Medium Complexity
- 🔴 High Complexity

---

## Appendix C: Decision Matrix

### Scoring Criteria (1-5 scale, 5 = best)

| Criterion | Weight | Sparkle | NetSparkle | Squirrel | ClickOnce | MSIX |
|-----------|--------|---------|------------|----------|-----------|------|
| **Ease of Integration** | 20% | 4 | 4 | 3 | 5 | 2 |
| **Security Features** | 25% | 5 | 5 | 2 | 3 | 4 |
| **Delta Updates** | 15% | 5 | 2 | 4 | 2 | 4 |
| **Maintenance Burden** | 15% | 5 | 4 | 2 | 4 | 3 |
| **User Experience** | 15% | 5 | 4 | 3 | 3 | 4 |
| **Documentation** | 10% | 5 | 3 | 2 | 4 | 4 |
| **Weighted Score** | 100% | **4.75** | **3.90** | **2.60** | **3.60** | **3.40** |

### Recommendations

#### For Talkies macOS App:
🏆 **Winner: Sparkle 2.x**
- Highest overall score (4.75/5.0)
- Industry standard with proven reliability
- Best-in-class delta updates (70-90% bandwidth savings)
- Native Swift integration
- Excellent documentation and community support

#### For Talkies Windows App:
🏆 **Winner: NetSparkle**
- Second-highest score (3.90/5.0)
- Native C# with full WPF support
- Modern .NET 8.0 compatible
- Similar architecture to Sparkle (easier maintenance)
- Active development and updates

#### Alternative Consideration:
If you need Windows Store distribution in the future, plan a migration path to **MSIX** (score: 3.40/5.0) after initial release. MSIX can coexist with NetSparkle for sideload users while offering Store auto-updates.

---

## Conclusion

After comprehensive research and analysis, the recommended auto-update solution for Talkies is:

1. **macOS:** Sparkle 2.x framework with GitHub Releases
2. **Windows:** NetSparkle with GitHub Releases
3. **Shared Infrastructure:** GitHub Actions CI/CD, semantic versioning, stable/beta channels

This combination provides:
- ✅ Industry-standard solutions on both platforms
- ✅ Modern EdDSA cryptographic signatures
- ✅ Native Swift and C# integration
- ✅ Minimal infrastructure costs ($0 hosting)
- ✅ Excellent user experience with automatic updates
- ✅ Delta updates on macOS (70-90% bandwidth savings)
- ✅ Support for beta testing channels
- ✅ Active maintenance and community support

**Next Steps:**
1. Review implementation plans in Section 4
2. Generate EdDSA key pairs for both platforms
3. Set up GitHub Actions workflows for automated releases
4. Obtain code signing certificates (Apple Developer ID + Windows Authenticode)
5. Implement Sparkle in macOS app (6-10 day estimate)
6. Implement NetSparkle in Windows app (7-11 day estimate)
7. Test end-to-end update flow on both platforms
8. Document update process in developer runbooks

---

**Document Prepared By:** Claude (Anthropic AI Assistant)
**Research Date:** December 16, 2025
**Version:** 1.0
