# Quick Start Guide - macOS DMG Build

This guide gets you building DMGs for Talkies in 5 minutes.

## Prerequisites

```bash
# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Install create-dmg (optional but recommended)
brew install create-dmg
```

## Build Unsigned DMG (For Testing)

Perfect for local testing without needing Apple Developer certificates:

```bash
cd /home/fource/talkies/packaging/macos
SKIP_SIGNING=1 ./build-dmg.sh
```

Output: `Talkies-1.0.0.dmg` (unsigned)

## Build Signed DMG (For Distribution)

### 1. Get Apple Developer Certificates

1. Sign up for Apple Developer Program ($99/year) at https://developer.apple.com
2. In Keychain Access: **Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority**
3. In [Apple Developer Portal](https://developer.apple.com/account):
   - Go to **Certificates, Identifiers & Profiles**
   - Click **+** to create new certificate
   - Select **Developer ID Application**
   - Upload the CSR file
   - Download and double-click to install in Keychain

### 2. Update Script Configuration

Edit `build-dmg.sh` and update:

```bash
SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAM_ID)"
```

Find your exact identity name with:

```bash
security find-identity -v -p codesigning
```

### 3. Build Signed DMG

```bash
./build-dmg.sh
```

## Build + Notarize (For Public Distribution)

Notarization is **required** for macOS Catalina and later to avoid Gatekeeper warnings.

### 1. Create App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Under **Security > App-Specific Passwords**, click **+**
4. Name it "Talkies Notarization"
5. Save the password (looks like: `xxxx-xxxx-xxxx-xxxx`)

### 2. Store Credentials

```bash
xcrun notarytool store-credentials "talkies-notary-profile" \
  --apple-id "your-email@apple.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Find your Team ID at: https://developer.apple.com/account (under Membership Details)

### 3. Build with Notarization

```bash
NOTARIZE=1 ./build-dmg.sh
```

This will:
1. Build the app
2. Create and sign DMG
3. Submit to Apple for notarization (5-60 minutes)
4. Staple the notarization ticket to DMG

## Customization

### Change Version

```bash
VERSION=2.0.0 ./build-dmg.sh
```

### Add Custom Background Image

1. Create `dmg-background.png` (800x400 or 1600x800 for Retina) in this directory
2. The script will automatically use it

### Add Application Icon

1. Place `AppIcon.icns` in `mac/Resources/`
2. The script will automatically include it

## Testing Your DMG

1. **Mount the DMG**: Double-click `Talkies-1.0.0.dmg`
2. **Drag to Applications**: Drag Talkies.app to Applications folder
3. **Launch**: Open from Applications or Spotlight
4. **Test on Clean System**: Use a fresh macOS VM or another Mac

## Verify Signing and Notarization

```bash
# Check app signature
codesign --verify --deep --strict --verbose=2 Talkies.app

# Check DMG signature
codesign --verify --verbose=2 Talkies-1.0.0.dmg

# Check notarization
spctl -a -t open --context context:primary-signature -v Talkies-1.0.0.dmg
```

Expected output for notarized DMG:
```
Talkies-1.0.0.dmg: accepted
source=Notarized Developer ID
```

## Common Issues

### "No identity found"

You don't have Developer ID certificate installed. Either:
- Install certificate (see step 1 above)
- Use `SKIP_SIGNING=1` for testing

### "create-dmg: command not found"

Install with: `brew install create-dmg`

Or the script will fall back to `hdiutil` (works fine, just less pretty)

### "Notarization failed"

Check logs:
```bash
xcrun notarytool log <submission-id> --keychain-profile talkies-notary-profile
```

Common causes:
- Missing entitlements
- Invalid signature
- Unsigned dependencies

## Distribution

Once you have a signed and notarized DMG:

1. **Upload to GitHub Releases**:
   ```bash
   gh release create v1.0.0 Talkies-1.0.0.dmg --title "Talkies v1.0.0"
   ```

2. **Upload to website**: Host on your own server

3. **Test download**: Download from distribution point and verify it runs without warnings

## Build Workflow Summary

```
┌─────────────────────────────────────────────────────┐
│  Development Cycle                                  │
├─────────────────────────────────────────────────────┤
│  1. Code changes in /mac                           │
│  2. Test: SKIP_SIGNING=1 ./build-dmg.sh            │
│  3. Verify app works locally                        │
├─────────────────────────────────────────────────────┤
│  Pre-Release                                        │
├─────────────────────────────────────────────────────┤
│  4. Update VERSION in build-dmg.sh or env          │
│  5. Build signed: ./build-dmg.sh                   │
│  6. Test on clean macOS system                      │
├─────────────────────────────────────────────────────┤
│  Release                                            │
├─────────────────────────────────────────────────────┤
│  7. Notarize: NOTARIZE=1 ./build-dmg.sh            │
│  8. Verify notarization                             │
│  9. Distribute via GitHub/website                   │
│  10. Announce to users                              │
└─────────────────────────────────────────────────────┘
```

## Getting Help

- **Full Documentation**: See `README.md` in this directory
- **Apple Documentation**: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- **create-dmg**: https://github.com/create-dmg/create-dmg

## Next Steps

1. Read the full `README.md` for comprehensive details
2. Set up continuous integration (GitHub Actions) for automated builds
3. Consider creating `.pkg` installer for enterprise users
