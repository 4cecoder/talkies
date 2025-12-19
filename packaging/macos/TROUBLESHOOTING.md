# macOS Packaging Troubleshooting Guide

This guide helps resolve common issues encountered when building and distributing macOS DMG installers.

## Build Issues

### "swift: command not found"

**Problem**: Swift compiler not installed

**Solution**:
```bash
xcode-select --install
# Or install full Xcode from Mac App Store
```

### "No such file or directory: .build/release/Talkies"

**Problem**: Build failed or binary not created

**Solutions**:
1. Check build logs: `cat packaging/macos/build/build.log`
2. Try building manually:
   ```bash
   cd /home/fource/talkies/mac
   swift build -c release --verbose
   ```
3. Clean and rebuild:
   ```bash
   swift package clean
   swift build -c release
   ```

### "Package.swift: error: manifest parse error"

**Problem**: Invalid Package.swift syntax

**Solution**:
1. Verify Package.swift syntax
2. Check Swift tools version is compatible
3. Update dependencies:
   ```bash
   swift package update
   swift package resolve
   ```

## Code Signing Issues

### "No identity found" or "identity specified not found"

**Problem**: Developer ID certificate not installed

**Solutions**:
1. Check available identities:
   ```bash
   security find-identity -v -p codesigning
   ```
2. Install Developer ID certificate from Apple Developer Portal
3. Import certificate into Keychain (double-click .cer file)
4. Verify certificate is trusted in Keychain Access
5. For testing, use: `SKIP_SIGNING=1 ./build-dmg.sh`

### "errSecInternalComponent" or signing fails silently

**Problem**: Keychain locked or certificate access denied

**Solutions**:
1. Unlock keychain:
   ```bash
   security unlock-keychain ~/Library/Keychains/login.keychain-db
   ```
2. Grant terminal access to certificate in Keychain Access
3. Try signing manually to see detailed error:
   ```bash
   codesign --sign "Developer ID Application: ..." build/Talkies.app
   ```

### "resource fork, Finder information, or similar detritus not allowed"

**Problem**: Extended attributes on files blocking signature

**Solution**:
```bash
xattr -cr build/Talkies.app
# Then re-run build script
```

### "bundle format unrecognized, invalid, or unsuitable"

**Problem**: Malformed app bundle structure

**Solutions**:
1. Verify bundle structure:
   ```bash
   ls -la build/Talkies.app/Contents/
   # Should have: MacOS/ Resources/ Info.plist
   ```
2. Validate Info.plist:
   ```bash
   plutil -lint build/Talkies.app/Contents/Info.plist
   ```
3. Check executable has correct permissions:
   ```bash
   ls -l build/Talkies.app/Contents/MacOS/Talkies
   # Should show: -rwxr-xr-x
   ```

### "unsealed contents present in the root directory of an embedded framework"

**Problem**: Framework contains unsigned or modified files

**Solution**:
```bash
# Sign deeply to include all nested code
codesign --deep --force --sign "Developer ID Application: ..." build/Talkies.app

# Or sign frameworks individually first
find build/Talkies.app -name "*.framework" -exec codesign --sign "..." {} \;
```

### "Hardened Runtime is required"

**Problem**: Missing `--options runtime` flag

**Solution**: The build script includes this automatically, but if signing manually:
```bash
codesign --options runtime --sign "..." build/Talkies.app
```

## DMG Creation Issues

### "create-dmg: command not found"

**Problem**: create-dmg tool not installed

**Solutions**:
1. Install via Homebrew: `brew install create-dmg`
2. Or script will fall back to `hdiutil` (works fine, less customization)

### "hdiutil: attach failed - Resource busy"

**Problem**: Previous DMG mount still active

**Solution**:
```bash
# List mounted volumes
hdiutil info

# Unmount specific volume
hdiutil detach /Volumes/Talkies -force

# Or unmount all DMGs
killall Finder
```

### "hdiutil: create failed - Invalid argument"

**Problem**: DMG size too small or invalid parameters

**Solutions**:
1. Increase DMG size in script (change `-size 200m` to larger)
2. Check disk space: `df -h`
3. Verify volume name doesn't contain special characters

### DMG mounts but shows no Applications symlink

**Problem**: Symlink creation failed

**Solution**:
```bash
# Manually add symlink when DMG is mounted
ln -s /Applications /Volumes/Talkies/Applications
# Then eject and re-create DMG
```

### Background image not showing in DMG

**Problem**: Image not found or wrong format

**Solutions**:
1. Verify image exists: `ls -l packaging/macos/dmg-background.png`
2. Check image format: `file packaging/macos/dmg-background.png`
   - Should be: PNG image data
3. Verify image dimensions (800x400 or 1600x800)
4. Re-create DMG with `--background` flag explicitly

## Notarization Issues

### "No profile found"

**Problem**: Notarization credentials not stored

**Solution**:
```bash
xcrun notarytool store-credentials "talkies-notary-profile" \
  --apple-id "your-email@apple.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"

# Verify it worked
xcrun notarytool history --keychain-profile talkies-notary-profile
```

### "Invalid credentials" or "authentication failed"

**Problem**: Wrong Apple ID, Team ID, or App-Specific Password

**Solutions**:
1. Verify Apple ID at appleid.apple.com
2. Find Team ID at developer.apple.com/account (Membership section)
3. Generate new App-Specific Password (old one might have expired)
4. Re-store credentials with correct values

### Notarization stuck "In Progress" for hours

**Problem**: Apple's notarization service may be slow or down

**Solutions**:
1. Check Apple System Status: https://www.apple.com/support/systemstatus/
   - Look for "Developer ID Notary Service"
2. Wait up to 2 hours (though usually < 1 hour)
3. If > 2 hours, try re-submitting:
   ```bash
   NOTARIZE=1 ./build-dmg.sh
   ```
4. Check submission status:
   ```bash
   xcrun notarytool history --keychain-profile talkies-notary-profile
   ```

### Notarization "Rejected" or "Invalid"

**Problem**: App doesn't meet notarization requirements

**Solution**: Check detailed logs:
```bash
# Get submission ID from notarization output or history
xcrun notarytool history --keychain-profile talkies-notary-profile

# View logs for specific submission
xcrun notarytool log SUBMISSION_ID --keychain-profile talkies-notary-profile > notarization.log

# Read the log file
cat notarization.log
```

**Common rejection reasons**:

1. **Missing Hardened Runtime**:
   ```bash
   codesign --options runtime --sign "..." build/Talkies.app
   ```

2. **Invalid Signature**:
   ```bash
   codesign --verify --deep --strict build/Talkies.app
   # If fails, re-sign with --force
   ```

3. **Missing Entitlements**:
   - Ensure microphone entitlement is present
   - Check `Talkies.entitlements` file exists and is used

4. **Unsigned Frameworks/Libraries**:
   ```bash
   # Sign all nested code
   codesign --deep --force --sign "..." build/Talkies.app
   ```

### "Stapler failed" or "No notarization ticket found"

**Problem**: Attempting to staple before notarization completes

**Solution**:
1. Wait for notarization to complete (status: "Accepted")
2. Verify acceptance:
   ```bash
   xcrun notarytool info SUBMISSION_ID --keychain-profile talkies-notary-profile
   ```
3. Then staple:
   ```bash
   xcrun stapler staple Talkies-X.X.X.dmg
   ```

## Gatekeeper Issues

### "damaged and can't be opened" when user downloads

**Problem**: App Translocation active or signature invalid

**Solutions**:
1. Ensure DMG itself is signed:
   ```bash
   codesign --verify Talkies-X.X.X.dmg
   ```
2. Sign the DMG:
   ```bash
   codesign --sign "Developer ID Application: ..." Talkies-X.X.X.dmg
   ```
3. Verify notarization:
   ```bash
   spctl -a -t open --context context:primary-signature -v Talkies-X.X.X.dmg
   ```

### "cannot be opened because the developer cannot be verified"

**Problem**: App not notarized or notarization ticket not stapled

**Solutions**:
1. Check if notarized:
   ```bash
   spctl -a -t exec -vv build/Talkies.app
   ```
2. Check if ticket is stapled:
   ```bash
   xcrun stapler validate Talkies-X.X.X.dmg
   ```
3. If not notarized, run: `NOTARIZE=1 ./build-dmg.sh`

### "App can't be opened" on user's Mac (macOS 10.15+)

**Problem**: Gatekeeper quarantine flag

**Solutions for users**:
```bash
# Right-click app > Open (instead of double-clicking)
# Or remove quarantine (if you trust the source):
xattr -d com.apple.quarantine /Applications/Talkies.app
```

**Solutions for developers**:
- Ensure app is properly notarized
- Test download from actual distribution URL
- Verify DMG signature and notarization

## Runtime Issues

### App crashes immediately on launch

**Problem**: Missing frameworks, wrong architecture, or entitlement issues

**Solutions**:
1. Check crash log:
   ```bash
   log show --predicate 'process == "Talkies"' --last 5m --info
   ```
2. Verify architecture:
   ```bash
   file build/Talkies.app/Contents/MacOS/Talkies
   # Should show: Mach-O 64-bit executable arm64 (or x86_64)
   ```
3. Check dylib dependencies:
   ```bash
   otool -L build/Talkies.app/Contents/MacOS/Talkies
   ```
4. Verify entitlements:
   ```bash
   codesign -d --entitlements :- build/Talkies.app
   ```

### "Talkies would like to access the microphone" not appearing

**Problem**: Microphone entitlement missing from Info.plist

**Solution**:
1. Verify Info.plist contains:
   ```bash
   /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" \
     build/Talkies.app/Contents/Info.plist
   ```
2. If missing, it's added automatically by build script
3. Reset permissions and relaunch:
   ```bash
   tccutil reset Microphone com.talkies.app
   ```

### Text insertion doesn't work

**Problem**: Accessibility permissions not granted

**Solutions**:
1. Check Accessibility permissions:
   - System Preferences > Security & Privacy > Privacy > Accessibility
   - Ensure Talkies is listed and checked
2. Reset and re-request:
   ```bash
   tccutil reset Accessibility com.talkies.app
   # Relaunch app to prompt again
   ```

## Build Script Issues

### "Permission denied" when running build-dmg.sh

**Problem**: Script not executable

**Solution**:
```bash
chmod +x packaging/macos/build-dmg.sh
./build-dmg.sh
```

### Script fails with "unbound variable"

**Problem**: Required environment variable not set

**Solution**: Script includes defaults, but verify:
```bash
# Set explicitly if needed
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export VERSION="1.0.0"
./build-dmg.sh
```

### "cd: no such file or directory" errors

**Problem**: Running script from wrong location

**Solution**:
```bash
cd /home/fource/talkies/packaging/macos
./build-dmg.sh
```

## Performance Issues

### Build takes very long

**Problem**: Debug symbols, large dependencies, or slow disk

**Solutions**:
1. Ensure using release build (not debug)
2. Clean build directory:
   ```bash
   rm -rf packaging/macos/build
   ```
3. Use SSD instead of HDD for build directory
4. Check Activity Monitor for other processes using resources

### Notarization takes > 1 hour

**Problem**: Large app size or Apple service delays

**Solutions**:
1. Check app size: `du -sh build/Talkies.app`
2. Strip unnecessary files to reduce size
3. Wait (Apple sometimes has delays)
4. Check Apple System Status page

## Testing Issues

### Can't test on macOS VM

**Problem**: Nested virtualization or old VM

**Solutions**:
1. Use UTM or Parallels (not VirtualBox)
2. Ensure VM has enough resources (8GB+ RAM)
3. Test on real hardware if possible

### "Unable to verify" error in VM

**Problem**: VM doesn't have internet or can't contact Apple servers

**Solutions**:
1. Ensure VM has internet access
2. Check firewall isn't blocking Apple's servers
3. Test on non-VM system

## Getting More Help

### Increase Verbosity

Run commands with verbose flags:
```bash
# Signing
codesign --verbose=4 ...

# Verification
codesign --verify --verbose=4 ...

# Notarization
xcrun notarytool submit --verbose ...

# Build
swift build -c release --verbose
```

### Check System Logs

```bash
# Recent logs
log show --predicate 'process == "Talkies"' --last 1h --info

# All logs for Talkies
log show --predicate 'process == "Talkies"' --style compact

# Code signing logs
log show --predicate 'subsystem == "com.apple.security"' --last 1h
```

### Useful Diagnostic Commands

```bash
# List all signing identities
security find-identity -v -p codesigning

# Check certificate validity
security find-certificate -c "Developer ID Application" -p

# Verify bundle structure
file build/Talkies.app/Contents/MacOS/Talkies
ls -la build/Talkies.app/Contents/

# Check entitlements
codesign -d --entitlements :- build/Talkies.app

# Verify signature details
codesign -dvvv build/Talkies.app

# Check notarization history
xcrun notarytool history --keychain-profile talkies-notary-profile

# Test Gatekeeper
spctl -a -t exec -vv build/Talkies.app
```

## Resources

- **Apple Developer Forums**: https://developer.apple.com/forums/tags/code-signing
- **Technical Note TN3125**: Inside Code Signing
- **Technical Note TN3127**: Code Signing Requirements
- **System Status**: https://www.apple.com/support/systemstatus/

## Reporting Issues

If you encounter issues not covered here:

1. Gather diagnostic information:
   ```bash
   ./build-dmg.sh > build.log 2>&1
   security find-identity -v -p codesigning > identities.txt
   codesign -dvvv build/Talkies.app > signature.txt 2>&1
   ```

2. Create GitHub issue with:
   - macOS version (`sw_vers`)
   - Xcode/Command Line Tools version (`xcode-select -p`)
   - Error messages from logs
   - Steps to reproduce
