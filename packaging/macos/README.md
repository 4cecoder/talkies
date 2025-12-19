# macOS Installer Packaging Guide for Talkies

This guide documents the complete process for creating distributable macOS installers for the Talkies Swift/SwiftUI application, including DMG creation, code signing, and notarization.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [DMG Creation](#dmg-creation)
4. [Code Signing](#code-signing)
5. [Notarization](#notarization)
6. [Package Installer (.pkg) Alternative](#package-installer-pkg-alternative)
7. [Automated Build Script](#automated-build-script)
8. [Troubleshooting](#troubleshooting)

---

## Overview

macOS applications can be distributed in two primary formats:

- **DMG (Disk Image)**: Most common for consumer applications. Provides a drag-and-drop install experience with custom branding.
- **PKG (Package)**: More suitable for enterprise deployment or applications requiring system-level installation.

For Talkies, we recommend DMG distribution as it provides the best user experience for a menu bar application.

---

## Prerequisites

### Required Tools

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **create-dmg** (Recommended tool for DMG creation)
   ```bash
   brew install create-dmg
   ```
   - GitHub: https://github.com/create-dmg/create-dmg
   - Alternative: https://github.com/sindresorhus/create-dmg (Node.js-based)

3. **Apple Developer Account** ($99/year)
   - Required for code signing and notarization
   - Sign up at: https://developer.apple.com

### Required Certificates

1. **Developer ID Application Certificate**
   - Used to sign the application bundle
   - Obtained from Apple Developer Portal

2. **Developer ID Installer Certificate** (for .pkg only)
   - Used to sign package installers
   - Obtained from Apple Developer Portal

### Obtaining Certificates

1. Visit [Apple Developer Account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Create a new certificate:
   - Select **Developer ID Application**
   - Follow CSR (Certificate Signing Request) generation steps
   - Download and install in Keychain Access

---

## DMG Creation

### What is a DMG?

A DMG (Disk Image) is macOS's preferred format for distributing applications. When mounted, it shows:
- Your application bundle
- A symbolic link to `/Applications` folder
- Optional: Custom background image, license agreement, volume icon

### Step-by-Step DMG Creation

#### 1. Build Your Application

```bash
cd /home/fource/talkies/mac
swift build -c release
```

The compiled binary will be at `.build/release/Talkies`. However, for macOS distribution, you need an `.app` bundle.

#### 2. Create Application Bundle

Since we're using Swift Package Manager (not Xcode), we need to manually create the `.app` bundle structure:

```bash
# Create bundle structure
mkdir -p "Talkies.app/Contents/MacOS"
mkdir -p "Talkies.app/Contents/Resources"

# Copy binary
cp .build/release/Talkies "Talkies.app/Contents/MacOS/Talkies"

# Make executable
chmod +x "Talkies.app/Contents/MacOS/Talkies"
```

#### 3. Create Info.plist

Create `Talkies.app/Contents/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Talkies</string>
    <key>CFBundleIdentifier</key>
    <string>com.talkies.app</string>
    <key>CFBundleName</key>
    <string>Talkies</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Talkies needs access to your microphone for voice transcription.</string>
</dict>
</plist>
```

#### 4. Add Application Icon (Optional)

```bash
# If you have an .icns file
cp path/to/AppIcon.icns "Talkies.app/Contents/Resources/AppIcon.icns"

# Update Info.plist to reference it
# Add: <key>CFBundleIconFile</key><string>AppIcon.icns</string>
```

#### 5. Create DMG with create-dmg

Using the `create-dmg` tool:

```bash
create-dmg \
  --volname "Talkies" \
  --volicon "path/to/volume-icon.icns" \
  --background "path/to/background.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "Talkies.app" 200 190 \
  --hide-extension "Talkies.app" \
  --app-drop-link 600 185 \
  "Talkies-1.0.0.dmg" \
  "Talkies.app"
```

**Parameters Explained:**
- `--volname`: Name shown when DMG is mounted
- `--volicon`: Custom icon for mounted volume
- `--background`: Background image (recommend 800x400 or 1600x800 for Retina)
- `--window-pos`: Initial window position (x, y)
- `--window-size`: Window dimensions (width, height)
- `--icon-size`: Application icon size in pixels
- `--icon "Talkies.app" 200 190`: Position of app icon (x, y)
- `--app-drop-link 600 185`: Position of Applications folder symlink
- `--hide-extension`: Hide .app extension in Finder

### Manual DMG Creation (Without create-dmg)

If you prefer manual control:

```bash
# Create a temporary DMG
hdiutil create -size 200m -fs HFS+J -volname "Talkies" temp.dmg

# Mount it
hdiutil attach temp.dmg -mountpoint /Volumes/Talkies

# Copy app
cp -R "Talkies.app" /Volumes/Talkies/

# Create Applications symlink
ln -s /Applications /Volumes/Talkies/Applications

# Customize window appearance (optional, requires AppleScript)
# ... (see detailed AppleScript examples below)

# Unmount
hdiutil detach /Volumes/Talkies

# Convert to compressed, read-only DMG
hdiutil convert temp.dmg -format UDZO -o "Talkies-1.0.0.dmg"

# Cleanup
rm temp.dmg
```

### Background Image Guidelines

For professional DMG appearance:

1. **Dimensions**: 800x400 pixels (standard) or 1600x800 (Retina)
2. **Format**: PNG with transparency
3. **Design Tips**:
   - Include visual arrows pointing from app to Applications folder
   - Use brand colors and logo
   - Keep it simple and uncluttered
   - Test on both light and dark macOS themes

---

## Code Signing

Code signing is **mandatory** for distributing macOS apps outside the App Store. Unsigned apps will be blocked by Gatekeeper.

### Why Code Sign?

1. **Security**: Proves app comes from identified developer
2. **Gatekeeper**: Allows app to run without warnings
3. **App Translocation Prevention**: Without signing, macOS may randomize app path
4. **Notarization Requirement**: Must be signed before notarization

### Checking Available Signing Identities

```bash
security find-identity -v -p codesigning
```

Output should show:
```
1) ABCDEF1234567890 "Developer ID Application: Your Name (TEAMID)"
```

### Signing the Application Bundle

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --options runtime \
  --entitlements Talkies.entitlements \
  "Talkies.app"
```

**Parameters Explained:**
- `--deep`: Sign all nested code (frameworks, plugins)
- `--force`: Replace existing signature
- `--verify`: Verify signature after signing
- `--verbose`: Show detailed output
- `--sign "..."`: Your Developer ID certificate name
- `--options runtime`: Enable Hardened Runtime (required for notarization)
- `--entitlements`: Plist file specifying required permissions

### Creating Entitlements File

Create `Talkies.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>

    <!-- Audio recording permission -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- If using network for LLM plugins -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Disable library validation if using dynamic libraries -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

### Signing the DMG

After creating the DMG, sign it too:

```bash
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
  "Talkies-1.0.0.dmg"
```

### Verifying Signatures

```bash
# Verify app bundle
codesign --verify --verbose=4 "Talkies.app"

# Verify DMG
codesign --verify --verbose=4 "Talkies-1.0.0.dmg"

# Check signature details
codesign -dvvv "Talkies.app"
```

### Common Code Signing Issues

1. **"resource fork, Finder information, or similar detritus not allowed"**
   ```bash
   xattr -cr "Talkies.app"  # Remove extended attributes
   ```

2. **"bundle format unrecognized, invalid, or unsuitable"**
   - Ensure Info.plist is valid
   - Check bundle structure (MacOS/ and Resources/ folders)

3. **Certificate expired**
   - Apps signed with expired certificates can still run if they were valid at signing time
   - For new builds, renew certificate in Apple Developer Portal

---

## Notarization

Notarization is Apple's automated malware scanning service. Starting with macOS Catalina, all apps distributed outside the App Store **must be notarized**.

### Notarization Process Overview

1. **Upload** app to Apple's notarization service
2. **Scan** for malicious content and code signing issues
3. **Receive ticket** if approved (typically < 1 hour)
4. **Staple ticket** to app bundle/DMG
5. **Distribute** with embedded ticket

### Prerequisites

- App must be signed with Developer ID Application certificate
- Hardened Runtime enabled (`--options runtime`)
- Valid entitlements
- No known malware or security issues

### Step 1: Create App-Specific Password

For notarization, you need an app-specific password (not your Apple ID password):

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Under **Security > App-Specific Passwords**, generate one
4. Save it securely (e.g., in Keychain)

Store in Keychain for CLI use:

```bash
xcrun notarytool store-credentials "talkies-notary-profile" \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### Step 2: Submit for Notarization

```bash
xcrun notarytool submit "Talkies-1.0.0.dmg" \
  --keychain-profile "talkies-notary-profile" \
  --wait
```

**Parameters:**
- `--wait`: Block until notarization completes (can take 5-60 minutes)
- `--keychain-profile`: Use stored credentials

**Output:**
```
Conducting pre-submission checks for Talkies-1.0.0.dmg and initiating connection to the Apple notary service...
Submission ID received
  id: 12345678-abcd-1234-abcd-123456789012
Successfully uploaded file
  id: 12345678-abcd-1234-abcd-123456789012
  path: Talkies-1.0.0.dmg
Waiting for processing to complete.
Current status: Accepted........
Processing complete
  id: 12345678-abcd-1234-abcd-123456789012
  status: Accepted
```

### Step 3: Check Notarization Status (if not using --wait)

```bash
xcrun notarytool info "12345678-abcd-1234-abcd-123456789012" \
  --keychain-profile "talkies-notary-profile"
```

### Step 4: Staple the Ticket

After approval, attach the notarization ticket to your DMG:

```bash
xcrun stapler staple "Talkies-1.0.0.dmg"
```

**Output:**
```
Processing: Talkies-1.0.0.dmg
Processing: Talkies-1.0.0.dmg
The staple and validate action worked!
```

### Step 5: Verify Stapling

```bash
xcrun stapler validate "Talkies-1.0.0.dmg"
```

### Step 6: Verify Gatekeeper Acceptance

```bash
spctl -a -t open --context context:primary-signature -v "Talkies-1.0.0.dmg"
```

**Expected output:**
```
Talkies-1.0.0.dmg: accepted
source=Notarized Developer ID
```

### Notarization for .app Bundles

If notarizing the app before creating DMG:

```bash
# Create a zip for notarization
ditto -c -k --keepParent "Talkies.app" "Talkies.zip"

# Submit zip
xcrun notarytool submit "Talkies.zip" \
  --keychain-profile "talkies-notary-profile" \
  --wait

# Staple ticket to app
xcrun stapler staple "Talkies.app"

# Now create DMG with notarized app
create-dmg ... "Talkies.app"
```

### Troubleshooting Notarization

1. **Check Logs**
   ```bash
   xcrun notarytool log "12345678-abcd-1234-abcd-123456789012" \
     --keychain-profile "talkies-notary-profile"
   ```

2. **Common Issues:**
   - **Missing Hardened Runtime**: Add `--options runtime` to codesign
   - **Invalid Signature**: Re-sign with `--force` flag
   - **Missing Entitlements**: Ensure microphone entitlement is present
   - **Library Validation**: Add `com.apple.security.cs.disable-library-validation` entitlement if using third-party libraries

3. **Notarization Delays (2025 Known Issue)**
   - Some users report delays on Apple Silicon with macOS Sequoia
   - If stuck > 2 hours, try re-submitting

---

## Package Installer (.pkg) Alternative

For enterprise deployment or apps requiring system-level installation, use `.pkg` format.

### When to Use .pkg

- Installing to protected system directories
- Running post-install scripts
- Installing multiple components (app + CLI tools)
- Enterprise/MDM deployment

### Creating a Basic Package

#### Step 1: Build Component Package

```bash
pkgbuild --root "Talkies.app" \
  --identifier "com.talkies.app" \
  --version "1.0.0" \
  --install-location "/Applications" \
  --sign "Developer ID Installer: Your Name (TEAMID)" \
  "Talkies-component.pkg"
```

#### Step 2: Create Distribution Package (Optional)

For advanced installers with custom UI:

```bash
# Generate distribution XML
productbuild --synthesize \
  --package "Talkies-component.pkg" \
  "distribution.xml"

# Edit distribution.xml to customize installer

# Build final product
productbuild --distribution "distribution.xml" \
  --package-path . \
  --sign "Developer ID Installer: Your Name (TEAMID)" \
  "Talkies-1.0.0.pkg"
```

#### Step 3: Notarize the Package

```bash
# Submit for notarization
xcrun notarytool submit "Talkies-1.0.0.pkg" \
  --keychain-profile "talkies-notary-profile" \
  --wait

# Staple ticket
xcrun stapler staple "Talkies-1.0.0.pkg"
```

### Distribution XML Customization

Edit `distribution.xml` for:
- Custom welcome/readme/license screens
- Installation checks (OS version, disk space)
- Post-install scripts
- Component selection UI

Example:

```xml
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Talkies</title>
    <welcome file="welcome.html"/>
    <license file="license.txt"/>
    <readme file="readme.html"/>
    <background file="background.png"/>
    <options customize="never" require-scripts="false"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.talkies.app"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.talkies.app" visible="false">
        <pkg-ref id="com.talkies.app"/>
    </choice>
    <pkg-ref id="com.talkies.app" version="1.0.0">Talkies-component.pkg</pkg-ref>
</installer-gui-script>
```

---

## Automated Build Script

We provide `build-dmg.sh` script that automates the entire process:

```bash
cd /home/fource/talkies/packaging/macos
./build-dmg.sh
```

### What the Script Does

1. Builds release version of Talkies
2. Creates properly structured .app bundle
3. Generates Info.plist
4. Code signs the application (if certificate available)
5. Creates DMG with Applications symlink
6. Code signs the DMG
7. Optionally submits for notarization

### Script Configuration

Edit variables at the top of `build-dmg.sh`:

```bash
APP_NAME="Talkies"
VERSION="1.0.0"
BUNDLE_ID="com.talkies.app"
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
NOTARY_PROFILE="talkies-notary-profile"
```

### Running Without Code Signing

For testing without certificates:

```bash
SKIP_SIGNING=1 ./build-dmg.sh
```

---

## Troubleshooting

### DMG Won't Mount

```bash
# Verify DMG integrity
hdiutil verify "Talkies-1.0.0.dmg"

# Check for corruption
hdiutil imageinfo "Talkies-1.0.0.dmg"
```

### App Crashes on Launch

```bash
# Check crash logs
log show --predicate 'process == "Talkies"' --last 1h

# Verify entitlements
codesign -d --entitlements :- "Talkies.app"
```

### Gatekeeper Blocks App

```bash
# Check Gatekeeper status
spctl --status

# Manually approve (for testing only, not for distribution)
xattr -d com.apple.quarantine "Talkies.app"
```

### "App is damaged and can't be opened"

This usually means:
1. App was modified after signing
2. Signature is invalid
3. App Translocation is active (sign the DMG!)

Solution:
```bash
# Re-sign everything
codesign --force --deep --sign "..." "Talkies.app"
codesign --sign "..." "Talkies-1.0.0.dmg"
```

---

## References and Resources

### Official Apple Documentation
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [Developer ID Signing](https://developer.apple.com/developer-id/)

### Tools
- [create-dmg (Shell Script)](https://github.com/create-dmg/create-dmg)
- [create-dmg (Node.js)](https://github.com/sindresorhus/create-dmg)
- [DMG Canvas](https://www.araelium.com/dmgcanvas) (Commercial GUI tool)
- [DropDMG](https://c-command.com/dropdmg/) (Commercial GUI tool)

### Articles and Guides
- [Apple Code Signing Handbook](https://www.freecodecamp.org/news/apple-code-signing-handbook/)
- [Distribution using Code Signing & Notarizing](https://www.theslidefactory.com/post/code-signing-notarizing-your-macos-application-for-distribution)
- [Creating Developer ID Ready Packages](https://www.repeato.app/creating-developer-id-ready-macos-installer-packages/)

### Community Resources
- [Apple Developer Forums - Code Signing](https://developer.apple.com/forums/topics/code-signing-topic)
- [Stack Overflow - macOS Notarization](https://stackoverflow.com/questions/tagged/notarization)

---

## Version History

- **v1.0** (2025-12-16): Initial documentation
  - DMG creation with create-dmg
  - Code signing workflow
  - Notarization process
  - PKG installer alternative
  - Automated build script

---

## Contributing

Found an issue or have improvements? Submit a PR to the Talkies repository.

## License

This documentation is part of the Talkies project. See main repository for license details.
