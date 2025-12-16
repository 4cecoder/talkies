# macOS Release Checklist

Use this checklist when preparing a new Talkies release for macOS.

## Pre-Release Preparation

### Code Quality

- [ ] All tests pass: `cd /home/fource/talkies/mac && swift test`
- [ ] No compiler warnings in release build
- [ ] Code reviewed and approved
- [ ] Changelog updated with new features/fixes
- [ ] Version number updated in appropriate places

### Version Management

- [ ] Decide on version number (e.g., 1.0.0, 1.1.0, 2.0.0)
- [ ] Follow semantic versioning: MAJOR.MINOR.PATCH
  - MAJOR: Breaking changes
  - MINOR: New features (backward compatible)
  - PATCH: Bug fixes
- [ ] Update version in `build-dmg.sh` or set `VERSION` env var

### Assets Preparation

- [ ] Application icon ready (`mac/Resources/AppIcon.icns`)
- [ ] DMG background image prepared (optional, `packaging/macos/dmg-background.png`)
- [ ] Release notes drafted
- [ ] Marketing materials prepared (if needed)

## Apple Developer Setup

### Certificates (One-time Setup)

- [ ] Apple Developer Account active ($99/year)
- [ ] Developer ID Application certificate installed in Keychain
- [ ] Verify certificate: `security find-identity -v -p codesigning`
- [ ] Certificate expiry checked (valid for 5 years)

### Notarization Setup (One-time)

- [ ] App-specific password created at appleid.apple.com
- [ ] Notarization credentials stored:
  ```bash
  xcrun notarytool store-credentials "talkies-notary-profile" \
    --apple-id "your-email@apple.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
  ```
- [ ] Test credentials: `xcrun notarytool history --keychain-profile talkies-notary-profile`

## Build Process

### Development Build (Testing)

- [ ] Clean build environment
- [ ] Run unsigned build: `SKIP_SIGNING=1 ./build-dmg.sh`
- [ ] Verify DMG mounts correctly
- [ ] Test app installation from DMG
- [ ] Test app functionality:
  - [ ] Microphone access works
  - [ ] Recording and transcription work
  - [ ] Settings persist
  - [ ] Hotkeys function
  - [ ] LLM plugins work (if enabled)

### Production Build (Signed)

- [ ] Update signing identity in script if needed
- [ ] Run signed build: `./build-dmg.sh`
- [ ] Verify code signature:
  ```bash
  codesign --verify --deep --strict --verbose=2 build/Talkies.app
  codesign --verify --verbose=2 Talkies-X.X.X.dmg
  ```
- [ ] Check entitlements are correct:
  ```bash
  codesign -d --entitlements :- build/Talkies.app
  ```

### Notarization (Required for Public Release)

- [ ] Run notarization: `NOTARIZE=1 ./build-dmg.sh`
- [ ] Wait for notarization to complete (5-60 minutes)
- [ ] Verify notarization succeeded (script will report status)
- [ ] Check stapled ticket:
  ```bash
  xcrun stapler validate Talkies-X.X.X.dmg
  spctl -a -t open --context context:primary-signature -v Talkies-X.X.X.dmg
  ```
- [ ] If notarization fails, check logs and fix issues:
  ```bash
  xcrun notarytool log <submission-id> --keychain-profile talkies-notary-profile
  ```

## Quality Assurance

### Automated Testing

- [ ] DMG integrity check: `hdiutil verify Talkies-X.X.X.dmg`
- [ ] Signature verification passed
- [ ] Notarization verification passed
- [ ] Gatekeeper check passed

### Manual Testing - Clean System

Test on a **clean macOS system** (not your development machine):

- [ ] macOS version: Test on minimum supported version (macOS 15+)
- [ ] macOS version: Test on latest macOS version
- [ ] Architecture: Test on Apple Silicon (M1/M2/M3)
- [ ] Architecture: Test on Intel Mac (if supporting)

#### Installation Flow

- [ ] Download DMG from intended distribution source
- [ ] Double-click DMG - mounts without warnings
- [ ] Drag app to Applications folder
- [ ] Eject DMG
- [ ] Launch app from Applications - no Gatekeeper warning
- [ ] Grant microphone permissions when prompted
- [ ] Grant accessibility permissions when prompted

#### Functionality Testing

- [ ] App appears in menu bar
- [ ] Click menu bar icon - window appears
- [ ] Recording starts and stops correctly
- [ ] Transcription produces accurate results
- [ ] Text insertion works in various apps (TextEdit, browser, etc.)
- [ ] Settings can be opened and modified
- [ ] Settings persist after app restart
- [ ] Hotkey functionality works
- [ ] App updates settings without crashes
- [ ] No console errors or warnings

#### Edge Cases

- [ ] App survives system sleep/wake
- [ ] App handles no internet connection gracefully (LLM features)
- [ ] App handles microphone disconnect/reconnect
- [ ] Multiple recordings in succession work
- [ ] App can be quit and relaunched cleanly

## Distribution

### GitHub Release

- [ ] Create GitHub release: `gh release create vX.X.X`
- [ ] Upload DMG as release asset
- [ ] Set release title: "Talkies vX.X.X"
- [ ] Add release notes (features, fixes, breaking changes)
- [ ] Mark as pre-release if beta/RC
- [ ] Publish release

### Website Distribution (if applicable)

- [ ] Upload DMG to hosting (S3, CDN, etc.)
- [ ] Update download links on website
- [ ] Update version number on website
- [ ] Update changelog/release notes page

### Verification

- [ ] Download from public URL
- [ ] Verify file integrity (checksum)
- [ ] Test installation from downloaded file
- [ ] Confirm no Gatekeeper warnings for end users

## Post-Release

### Monitoring

- [ ] Monitor crash reports (if crash reporting is implemented)
- [ ] Watch for GitHub issues
- [ ] Check user feedback channels
- [ ] Monitor download statistics

### Documentation

- [ ] Update user documentation if needed
- [ ] Update README with new version
- [ ] Update any video tutorials if UI changed
- [ ] Announce release on social media/blog

### Automation Prep for Next Release

- [ ] Document any manual steps that could be automated
- [ ] Update build scripts if any issues were found
- [ ] Consider CI/CD integration (GitHub Actions)

## Emergency Rollback

If critical bug is discovered post-release:

- [ ] Remove download links immediately
- [ ] Post warning on website/GitHub
- [ ] Prepare hotfix release
- [ ] Follow this checklist for hotfix
- [ ] Communicate with users about issue and fix

## Notes Section

Use this space to track release-specific notes:

```
Release: v____
Date: ____
Build Time: ____
Notarization Time: ____
Issues Encountered: ____
Special Notes: ____
```

## Version History

Track completed releases:

| Version | Date | Notes |
|---------|------|-------|
| 1.0.0   | TBD  | Initial public release |
|         |      |                        |
|         |      |                        |

---

## Tips

- **Use a clean VM**: Test on a fresh macOS VM to simulate user experience
- **Keep credentials secure**: Never commit App-Specific Passwords to git
- **Automate what you can**: Consider GitHub Actions for build automation
- **Test early**: Start testing builds days before planned release
- **Communicate**: Keep users informed of release timeline and any issues

## Resources

- [Apple Developer Portal](https://developer.apple.com/account)
- [Notarization Status](https://developer.apple.com/account/resources/certificates/list)
- [Apple System Status](https://www.apple.com/support/systemstatus/) - Check if notarization is down
- [macOS Version History](https://en.wikipedia.org/wiki/MacOS_version_history)
