# Release Management and CI/CD Pipeline Research

## Executive Summary

This document provides comprehensive research on release management and CI/CD pipelines for desktop applications, specifically targeting multi-platform projects like Talkies (macOS, Windows, Linux). It covers GitHub Actions workflows, release channels, versioning strategies, code signing, release artifacts, and industry best practices.

---

## 1. GitHub Actions Release Workflows

### 1.1 Matrix Builds for Multi-Platform Releases

GitHub Actions matrix strategy enables parallel builds across multiple platforms, significantly reducing build times and ensuring consistency.

**Basic Matrix Configuration:**
```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: macos-latest
            platform: macOS
            arch: arm64
          - os: macos-13
            platform: macOS
            arch: x64
          - os: windows-latest
            platform: Windows
            arch: x64
          - os: ubuntu-latest
            platform: Linux
            arch: x64

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Build ${{ matrix.platform }} (${{ matrix.arch }})
        run: |
          # Platform-specific build commands

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: talkies-${{ matrix.platform }}-${{ matrix.arch }}
          path: dist/
          retention-days: 30
```

**Key Benefits:**
- Parallel execution reduces total build time
- Consistent build environment across platforms
- Easy to add new platform targets
- Built-in failure isolation with `fail-fast: false`

### 1.2 Tag-Based vs Branch-Based Releases

#### Tag-Based Releases (Recommended)

**Advantages:**
- Tags are immutable references to specific commits
- Clear semantic versioning markers (v1.2.3)
- Prevents accidental modifications to release code
- Industry standard for production releases
- Better integration with package managers and download systems

**Implementation:**
```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'  # Matches v1.2.3
      - 'v[0-9]+.[0-9]+.[0-9]+-beta.[0-9]+'  # Matches v1.2.3-beta.1
```

Tags are not meant to be updated and changed, and will always point to a specific version. They are commonly used to apply version numbers to specific releases, following semantic versioning format (Major.Minor.Patch).

#### Branch-Based Releases

**When to Use:**
- Long-term support (LTS) versions requiring ongoing patches
- Enterprise customers requiring backports
- Pre-release testing environments

**Example:**
```yaml
on:
  push:
    branches:
      - 'release/*'
      - 'hotfix/*'
```

A branch for a release is useful when you need to apply patches to older versions. However, releases should always result in a tag of the repository regardless of the source branch. It is safe to delete a release branch once release activities are complete since it can be easily re-created from a release tag.

**Best Practice:** Use tags for marking release points, and branches only when ongoing maintenance is required. High-throughput teams using continuous delivery can ignore release branches and use a roll-forward strategy for production fixes.

### 1.3 Artifact Management and Retention

#### GitHub Actions Artifact Retention

By default, GitHub Actions artifacts and log files are retained for **90 days** before automatic deletion. This can be customized:

**Repository-Level Configuration:**
- Minimum: 1 day
- Maximum: 400 days (private/internal repos)
- Default: 90 days

**Per-Artifact Configuration:**
```yaml
- name: Upload build artifacts
  uses: actions/upload-artifact@v4
  with:
    name: talkies-macos-universal
    path: build/Talkies.app
    retention-days: 7  # Short-lived build artifacts
```

**Workflow-Level Configuration:**
```yaml
- name: Upload release artifacts
  uses: actions/upload-artifact@v4
  with:
    name: release-${{ github.ref_name }}
    path: dist/
    retention-days: 365  # Long-term release artifacts
```

#### Storage Considerations

- Artifacts count against repository storage limits
- Default 90-day retention can be expensive for large teams
- Consider external storage (AWS S3, Azure Blob) for large artifacts
- Release assets uploaded to GitHub Releases have no retention limit

**Best Practice:** Use short retention (7-30 days) for CI artifacts, and upload final release assets to GitHub Releases for permanent storage.

### 1.4 Release Notes Generation

#### Automated Release Notes with Release Drafter

Release Drafter automatically drafts release notes as pull requests are merged, categorizing changes by labels.

**Configuration (.github/release-drafter.yml):**
```yaml
name-template: 'v$RESOLVED_VERSION'
tag-template: 'v$RESOLVED_VERSION'

categories:
  - title: '🚀 Features'
    labels:
      - 'feature'
      - 'enhancement'
  - title: '🐛 Bug Fixes'
    labels:
      - 'bug'
      - 'fix'
  - title: '📚 Documentation'
    labels:
      - 'documentation'
  - title: '🔧 Maintenance'
    labels:
      - 'chore'
      - 'dependencies'

version-resolver:
  major:
    labels:
      - 'major'
      - 'breaking'
  minor:
    labels:
      - 'minor'
      - 'feature'
  patch:
    labels:
      - 'patch'
      - 'bug'
      - 'fix'
  default: patch

template: |
  ## What's Changed

  $CHANGES

  ## Contributors

  $CONTRIBUTORS
```

**Workflow (.github/workflows/release-drafter.yml):**
```yaml
name: Release Drafter

on:
  push:
    branches:
      - master
  pull_request:
    types: [opened, reopened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  update_release_draft:
    runs-on: ubuntu-latest
    steps:
      - uses: release-drafter/release-drafter@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

With the version-resolver option, version number incrementing is automatically determined based on PR labels. Release Drafter can categorize pull requests using labels to organize changes into different sections.

#### GitHub Native Auto-Generated Release Notes

GitHub provides built-in automatically generated release notes that create an overview of merged pull requests, contributors, and a full changelog link.

**Enable via UI or API:**
```bash
gh release create v1.2.3 --generate-notes
```

**Customize with .github/release.yml:**
```yaml
changelog:
  exclude:
    labels:
      - ignore-for-release
      - dependencies
    authors:
      - dependabot
  categories:
    - title: Breaking Changes
      labels:
        - breaking-change
    - title: New Features
      labels:
        - enhancement
    - title: Bug Fixes
      labels:
        - bug
    - title: Other Changes
      labels:
        - "*"
```

### 1.5 Complete Multi-Platform Release Workflow Example

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build-matrix:
    strategy:
      fail-fast: false
      matrix:
        include:
          # macOS Universal Binary (Apple Silicon + Intel)
          - os: macos-latest
            platform: macOS
            arch: universal
            artifact: Talkies.dmg

          # Windows x64
          - os: windows-latest
            platform: Windows
            arch: x64
            artifact: TalkiesSetup.exe

          # Linux x64 (AppImage)
          - os: ubuntu-latest
            platform: Linux
            arch: x64
            artifact: Talkies.AppImage

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Extract version
        id: version
        shell: bash
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build ${{ matrix.platform }}
        run: |
          # Platform-specific build commands here
          echo "Building for ${{ matrix.platform }}"

      - name: Generate checksums
        shell: bash
        run: |
          cd dist
          sha256sum ${{ matrix.artifact }} > ${{ matrix.artifact }}.sha256

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.platform }}-${{ matrix.arch }}
          path: |
            dist/${{ matrix.artifact }}
            dist/${{ matrix.artifact }}.sha256
          retention-days: 7

  create-release:
    needs: build-matrix
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: release-assets/

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
          draft: false
          prerelease: ${{ contains(github.ref, 'beta') || contains(github.ref, 'alpha') }}
          files: release-assets/**/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 2. Release Channels

### 2.1 Overview

Release channels are a software distribution strategy that provides different levels of stability and testing. The three main channels are:

1. **Stable/Production** - Production-ready, thoroughly tested
2. **Beta/Preview** - Early preview, mostly stable, ready for daily use
3. **Nightly/Canary** - Experimental, latest features, may contain bugs

### 2.2 The "Train Model" Release Process

The Rust programming language exemplifies an effective release channel strategy:

> New nightly releases are created once a day. Every six weeks, the latest nightly release is promoted to 'Beta'. At that point, it will only receive patches to fix serious errors. Six weeks later, the beta is promoted to 'Stable', and becomes the next release.

This is called the "train model" because every six weeks, a release "leaves the station", but still has to take a journey through the beta channel before it arrives as a stable release.

### 2.3 Channel Characteristics

#### Stable Channel

**Purpose:** Production releases for all users

**Characteristics:**
- Thoroughly tested and QA validated
- High reliability and stability
- Receives critical security and bug fixes
- Updated on a regular cadence (e.g., every 2-3 weeks)

**Versioning:** Standard semantic versioning (v1.2.3)

**GitHub Implementation:**
```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'  # v1.2.3 only
```

**Distribution:**
- Official website downloads
- Package managers (Homebrew, winget, apt)
- Auto-update as default channel

#### Beta Channel

**Purpose:** Preview of upcoming stable releases

**Characteristics:**
- 4-6 week preview of stable features
- Ready for daily use by early adopters
- May contain minor bugs
- Receives bug fixes before stable promotion
- Helps discover issues before stable release

**Versioning:** Semantic versioning with beta suffix (v1.2.3-beta.1)

**GitHub Implementation:**
```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+-beta.[0-9]+'
```

**Distribution:**
- Separate download section on website
- Opt-in via settings or separate installer
- Auto-update to beta track (user choice)

#### Nightly/Canary Channel

**Purpose:** Cutting-edge development builds

**Characteristics:**
- Built daily from main branch
- Latest features and changes
- May be unstable or broken
- No guarantees of functionality
- For developers and advanced users only
- 9-12 week preview of stable features

**Versioning:** Date-based or commit-based (v1.3.0-nightly.20251216 or v1.3.0-nightly.abc1234)

**GitHub Implementation:**
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  push:
    branches:
      - master
      - main
```

**Distribution:**
- Separate nightly download page
- Explicit warnings about instability
- No auto-updates from stable/beta

### 2.4 Managing Multiple Channels in CI/CD

#### Channel Detection Strategy

```yaml
jobs:
  detect-channel:
    runs-on: ubuntu-latest
    outputs:
      channel: ${{ steps.channel.outputs.channel }}
      version: ${{ steps.channel.outputs.version }}

    steps:
      - id: channel
        run: |
          if [[ "$GITHUB_REF" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "channel=stable" >> $GITHUB_OUTPUT
            echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
          elif [[ "$GITHUB_REF" =~ ^refs/tags/v.*-beta ]]; then
            echo "channel=beta" >> $GITHUB_OUTPUT
            echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
          elif [[ "$GITHUB_REF" =~ ^refs/tags/v.*-alpha ]]; then
            echo "channel=alpha" >> $GITHUB_OUTPUT
            echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
          else
            echo "channel=nightly" >> $GITHUB_OUTPUT
            VERSION="1.3.0-nightly.$(date +%Y%m%d).${GITHUB_SHA:0:7}"
            echo "version=$VERSION" >> $GITHUB_OUTPUT
          fi
```

#### Channel-Specific Build Configuration

```yaml
jobs:
  build:
    needs: detect-channel
    runs-on: ${{ matrix.os }}

    steps:
      - name: Configure build
        run: |
          CHANNEL="${{ needs.detect-channel.outputs.channel }}"

          # Set channel-specific configurations
          case "$CHANNEL" in
            stable)
              echo "UPDATE_URL=https://updates.talkies.app/stable" >> $GITHUB_ENV
              echo "ENABLE_ANALYTICS=true" >> $GITHUB_ENV
              ;;
            beta)
              echo "UPDATE_URL=https://updates.talkies.app/beta" >> $GITHUB_ENV
              echo "ENABLE_ANALYTICS=true" >> $GITHUB_ENV
              ;;
            nightly)
              echo "UPDATE_URL=https://updates.talkies.app/nightly" >> $GITHUB_ENV
              echo "ENABLE_ANALYTICS=false" >> $GITHUB_ENV
              echo "ENABLE_DEBUG_LOGS=true" >> $GITHUB_ENV
              ;;
          esac
```

### 2.5 CI/CD Testing Strategy by Channel

Most users do not actively use beta releases, but teams should test against beta in their CI system to help discover possible regressions. A recommended CI configuration tests all three channels with `allow_failures` for nightly:

```yaml
jobs:
  test:
    strategy:
      matrix:
        channel: [stable, beta, nightly]

    continue-on-error: ${{ matrix.channel == 'nightly' }}

    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: npm test
```

### 2.6 Real-World Examples

**Google Chrome:**
- Stable: Updated every 2-3 weeks (minor), 4 weeks (major)
- Beta: 4-6 week preview
- Dev: 9-12 week preview
- Canary: Daily builds

**Brave Browser:**
- Brave Release: Production-ready, stable
- Brave Beta: Early preview, showcases newest advances
- Brave Nightly: Daily builds, experimental

**Rust Language:**
- Stable: Every 6 weeks from promoted beta
- Beta: 6-week testing period
- Nightly: Daily builds from master

---

## 3. Versioning Strategies

### 3.1 Semantic Versioning (SemVer)

Semantic Versioning follows a structured format: **MAJOR.MINOR.PATCH** (e.g., 1.4.2)

#### Core Principles

- **MAJOR** version: Incompatible API changes or breaking changes
- **MINOR** version: New functionality, backward-compatible
- **PATCH** version: Backward-compatible bug fixes

#### Pre-release and Build Metadata

- Pre-release: `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.1`
- Build metadata: `1.0.0+20251216`, `1.0.0+sha.abc1234`

#### Advantages for Desktop Applications

- **Dependency management:** Guarantees backward compatibility, allows developers to manage dependencies effectively
- **Clear communication:** Users immediately understand the impact of updates
- **Automated updates:** Auto-updaters can safely apply MINOR and PATCH updates
- **Ecosystem compatibility:** Package managers expect SemVer

#### When to Use SemVer

SemVer is the gold standard for libraries and packages, ensuring compatibility and stability for dependent projects. It's ideal for:
- Applications with plugins or extensions
- Developer tools and SDKs
- Applications with public APIs
- Cross-platform applications with shared components

### 3.2 Calendar Versioning (CalVer)

CalVer is a versioning convention based on your project's release calendar, instead of arbitrary numbers. Unlike SemVer, which emphasizes types of changes, CalVer shifts focus to when a release was made.

#### Common Formats

- **Ubuntu:** `YY.0M` (e.g., 24.04, 24.10)
- **Windows 10:** `YYMM` (e.g., 1909, 2004)
- **Electron:** `YY.0M.MICRO` (e.g., 25.01.0)

#### Advantages for Desktop Applications

- **Release tracking:** Makes it easy to see when a version was released
- **LTS planning:** Helps teams plan long-term support based on time
- **User clarity:** Users immediately know if their software is outdated
- **Marketing alignment:** Aligns with release schedules rather than API stability

#### When to Use CalVer

CalVer is better for applications and internal software, making releases predictable and easier to manage. It's ideal for:
- Consumer-facing desktop applications
- Applications with time-based release schedules
- Tax software, productivity apps with annual cycles
- Applications where "latest" is always better

#### Examples

- **Ubuntu:** Uses YY.MM format (4.10 was October 2004, 24.04 is April 2024)
- **Microsoft Windows 10:** Versions named after year/month (1909, 2004, 2009)

### 3.3 Hybrid Approaches

Some projects use both strategies:
- **SemVer for libraries/SDKs** - Ensures backward compatibility
- **CalVer for applications** - Communicates release timing

**Example:**
```
talkies-core: 2.3.1 (SemVer - library)
Talkies App: 24.12.0 (CalVer - desktop app)
```

### 3.4 Single Source of Truth for Version

A key benefit of monorepos is having a "single source of truth: one version of every dependency means there are no versioning conflicts and no dependency hell."

#### Strategy for Multi-Platform Projects

**Option 1: Monorepo with Shared Version File**

```
talkies/
├── VERSION                  # 1.2.3
├── mac/
│   └── Sources/Talkies/Info.plist
├── windows/
│   └── Talkies.Windows/Talkies.csproj
└── linux/
    └── crates/talkies-tauri/Cargo.toml
```

**VERSION file:**
```
1.2.3
```

**GitHub Actions version sync:**
```yaml
- name: Read version
  id: version
  run: echo "VERSION=$(cat VERSION)" >> $GITHUB_OUTPUT

- name: Update macOS version
  run: |
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${{ steps.version.outputs.VERSION }}" \
      mac/Sources/Talkies/Info.plist

- name: Update Windows version
  run: |
    sed -i "s/<Version>.*<\/Version>/<Version>${{ steps.version.outputs.VERSION }}<\/Version>/" \
      windows/Talkies.Windows/Talkies.csproj

- name: Update Linux version
  run: |
    sed -i 's/^version = ".*"/version = "${{ steps.version.outputs.VERSION }}"/' \
      linux/crates/talkies-tauri/Cargo.toml
```

**Option 2: Git Tags as Source of Truth**

Use git tags directly:
```yaml
- name: Extract version from tag
  id: version
  run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

- name: Inject version into builds
  run: |
    # macOS
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist

    # Windows
    dotnet build -p:Version=$VERSION

    # Linux
    cargo build --release
    sed -i "s/version = .*/version = \"$VERSION\"/" Cargo.toml
```

**Option 3: Platform-Specific Files with Build-Time Sync**

Keep versions in native format but synchronize during CI:
```yaml
- name: Extract versions and validate
  run: |
    MAC_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" mac/Info.plist)
    WIN_VER=$(grep -oPm1 "(?<=<Version>)[^<]+" windows/Talkies.csproj)
    LIN_VER=$(grep -m1 version linux/Cargo.toml | sed 's/.*"\(.*\)".*/\1/')

    if [[ "$MAC_VER" != "$WIN_VER" ]] || [[ "$WIN_VER" != "$LIN_VER" ]]; then
      echo "Version mismatch detected!"
      echo "macOS: $MAC_VER, Windows: $WIN_VER, Linux: $LIN_VER"
      exit 1
    fi
```

### 3.5 Automated Version Bumping

#### Using semantic-release

semantic-release automatically determines the next version number based on commit messages, generates changelogs, and publishes releases.

**Setup (.releaserc.json):**
```json
{
  "branches": ["master"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    "@semantic-release/github",
    [
      "@semantic-release/git",
      {
        "assets": ["CHANGELOG.md", "VERSION"],
        "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
      }
    ]
  ]
}
```

**Conventional Commits:**
- `feat:` → MINOR bump (new feature)
- `fix:` → PATCH bump (bug fix)
- `BREAKING CHANGE:` or `!` suffix → MAJOR bump

**Example commits:**
```
feat: add dark mode support
fix: resolve crash on startup
feat!: remove legacy API
```

#### Using PaulHatch/semantic-version Action

This action produces semantic versions from git history without requiring manual version assignment:

```yaml
- uses: paulhatch/semantic-version@v5.3.0
  id: version
  with:
    tag_prefix: "v"
    major_pattern: "(MAJOR)"
    minor_pattern: "feat:"
    format: "${major}.${minor}.${patch}"
```

#### Using PR Labels for Version Bumps

The jefflinse/pr-semver-bump action bumps version when PRs are merged based on labels:

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  tag:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: jefflinse/pr-semver-bump@v1
        with:
          mode: auto
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          major-label: breaking
          minor-label: feature
          patch-label: fix
```

This shifts version bumping responsibility to the PR level, allowing developers to specify the next release version using labels rather than commit message parsing.

### 3.6 Recommendations for Talkies

**Recommended Strategy:**
- **Application:** CalVer with YY.0M.MICRO format (e.g., 25.01.0)
- **Shared Libraries:** SemVer for any reusable components
- **Single Source:** VERSION file in repository root
- **Automation:** semantic-release or git tag-based

**Rationale:**
- Desktop app users care more about recency than API compatibility
- Clear indication of how old their installation is
- Aligns with regular release schedule
- Marketing-friendly version numbers

---

## 4. Code Signing in CI/CD

### 4.1 macOS Code Signing and Notarization

macOS requires all applications to be code signed and notarized for distribution. Notarized applications provide extra assurance for users, indicating that the app has been scanned for security issues by Apple. macOS Catalina and later require notarization for all applications to run by default.

#### Prerequisites

- **Apple Developer Program membership:** $99/year
- **Developer ID Application certificate:** For signing app bundles and executables
- **Developer ID Installer certificate:** For signing .pkg installers
- **App-specific password:** Generated at appleid.apple.com

**Important:** Sign "inside out" - sign all binaries, libraries, and scripts inside your package before signing the package itself. Apple's notarization process will refuse packages where internal files are unsigned.

#### Exporting Certificates for CI

```bash
# Export certificate and private key
security find-identity -v -p codesigning

# Export to p12 file
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities -f pkcs12 -o certificate.p12 -P PASSWORD

# Base64 encode for GitHub Secrets
base64 -i certificate.p12 | pbcopy
```

#### GitHub Secrets Configuration

Required secrets:
- `MACOS_CERTIFICATE`: Base64-encoded .p12 certificate
- `MACOS_CERTIFICATE_PASSWORD`: Certificate password
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password
- `APPLE_TEAM_ID`: 10-character Team ID

#### Complete GitHub Actions Workflow

```yaml
name: macOS Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-macos:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Import signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.MACOS_CERTIFICATE }}
          CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
        run: |
          # Create keychain
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Import certificate
          echo -n "$CERTIFICATE_BASE64" | base64 --decode -o certificate.p12
          security import certificate.p12 -k "$KEYCHAIN_PATH" \
            -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: \
            -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Add to search list
          security list-keychain -d user -s "$KEYCHAIN_PATH"

      - name: Build application
        run: |
          cd mac
          swift build -c release --arch arm64 --arch x86_64

      - name: Code sign application
        run: |
          codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
            --options runtime --timestamp \
            mac/.build/release/Talkies.app

          # Verify signature
          codesign --verify --deep --strict --verbose=2 mac/.build/release/Talkies.app

      - name: Create DMG
        run: |
          # Use create-dmg or custom script
          npm install -g create-dmg
          create-dmg 'mac/.build/release/Talkies.app' --overwrite
          mv "Talkies *.dmg" Talkies.dmg

      - name: Sign DMG
        run: |
          codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" \
            --timestamp Talkies.dmg

      - name: Notarize application
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          # Submit for notarization
          xcrun notarytool submit Talkies.dmg \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

          # Staple notarization ticket
          xcrun stapler staple Talkies.dmg

          # Verify
          xcrun stapler validate Talkies.dmg

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: Talkies-macOS
          path: Talkies.dmg
```

#### Using Third-Party Actions

**indygreg/apple-code-sign-action** (Cross-platform):
```yaml
- uses: indygreg/apple-code-sign-action@v1
  with:
    input_path: Talkies.app
    p12_file: ${{ secrets.MACOS_CERTIFICATE }}
    p12_password: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
    apple_id: ${{ secrets.APPLE_ID }}
    apple_id_password: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
    apple_team_id: ${{ secrets.APPLE_TEAM_ID }}
```

This action can run from Linux, Windows, and macOS runners using the open-source rcodesign tool.

#### Timing Expectations

- **First-time notarization:** 8-12 hours
- **Subsequent notarizations:** 10-15 minutes
- Plan CI/CD workflows accordingly

### 4.2 Windows Code Signing

Windows Authenticode signing ensures users can verify your application's authenticity and that it hasn't been tampered with.

#### Certificate Options

1. **Standard Code Signing Certificate** - From DigiCert, Sectigo, etc.
2. **Extended Validation (EV) Certificate** - Immediate SmartScreen reputation (recommended)
3. **Azure Key Vault** - Cloud-based HSM storage (CI/CD friendly)

#### Azure SignTool Approach (Recommended for CI/CD)

Azure SignTool allows signing with certificates stored in Azure Key Vault, eliminating the need to handle certificate files in CI/CD.

**Prerequisites:**
- Azure Key Vault with code signing certificate
- Azure AD Service Principal with Key Vault permissions
- Azure CLI or SignTool installed

**GitHub Secrets:**
- `AZURE_KEY_VAULT_URI`: https://your-vault.vault.azure.net/
- `AZURE_CLIENT_ID`: Service Principal Application ID
- `AZURE_CLIENT_SECRET`: Service Principal Secret
- `AZURE_TENANT_ID`: Azure AD Tenant ID
- `AZURE_CERT_NAME`: Certificate name in Key Vault

**Workflow:**
```yaml
name: Windows Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-windows:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build application
        run: |
          cd windows/Talkies.Windows
          dotnet build -c Release
          dotnet publish -c Release -r win-x64 --self-contained

      - name: Install AzureSignTool
        run: dotnet tool install --global AzureSignTool

      - name: Sign executable
        env:
          VAULT_URI: ${{ secrets.AZURE_KEY_VAULT_URI }}
          CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          CERT_NAME: ${{ secrets.AZURE_CERT_NAME }}
        run: |
          AzureSignTool sign `
            -kvu "$env:VAULT_URI" `
            -kvi "$env:CLIENT_ID" `
            -kvs "$env:CLIENT_SECRET" `
            -kvt "$env:TENANT_ID" `
            -kvc "$env:CERT_NAME" `
            -tr http://timestamp.digicert.com `
            -td sha256 `
            windows/Talkies.Windows/bin/Release/net8.0-windows/win-x64/publish/Talkies.exe

      - name: Verify signature
        run: |
          Get-AuthenticodeSignature windows/Talkies.Windows/bin/Release/net8.0-windows/win-x64/publish/Talkies.exe

      - name: Create installer
        run: |
          # Use NSIS, WiX, or Advanced Installer
          # Sign the installer after creation

      - name: Sign installer
        env:
          VAULT_URI: ${{ secrets.AZURE_KEY_VAULT_URI }}
          CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          CERT_NAME: ${{ secrets.AZURE_CERT_NAME }}
        run: |
          AzureSignTool sign `
            -kvu "$env:VAULT_URI" `
            -kvi "$env:CLIENT_ID" `
            -kvs "$env:CLIENT_SECRET" `
            -kvt "$env:TENANT_ID" `
            -kvc "$env:CERT_NAME" `
            -tr http://timestamp.digicert.com `
            -td sha256 `
            TalkiesSetup.exe

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: Talkies-Windows
          path: TalkiesSetup.exe
```

#### Traditional SignTool Approach

If using a .pfx certificate file:

```yaml
- name: Decode certificate
  run: |
    $bytes = [Convert]::FromBase64String("${{ secrets.WINDOWS_CERTIFICATE }}")
    [IO.File]::WriteAllBytes("cert.pfx", $bytes)

- name: Sign with SignTool
  run: |
    & "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign `
      /f cert.pfx `
      /p "${{ secrets.CERTIFICATE_PASSWORD }}" `
      /tr http://timestamp.digicert.com `
      /td sha256 `
      /fd sha256 `
      Talkies.exe

- name: Clean up certificate
  if: always()
  run: Remove-Item cert.pfx -ErrorAction SilentlyContinue
```

#### Timestamp Servers

Always use timestamping to keep signatures valid after certificate expiration:

- DigiCert: `http://timestamp.digicert.com`
- Sectigo: `http://timestamp.sectigo.com`
- GlobalSign: `http://timestamp.globalsign.com`

#### SmartScreen Reputation

- **EV Certificates:** Immediate SmartScreen reputation
- **OV Certificates:** Requires building reputation over time
- Consistent signing identity helps build trust

### 4.3 Linux Code Signing

Linux doesn't have a centralized code signing infrastructure like macOS/Windows, but signing is still valuable for package repositories and user trust.

#### AppImage Signing

```bash
# Generate GPG key if needed
gpg --full-generate-key

# Sign AppImage
gpg --detach-sign --armor Talkies.AppImage

# Verify
gpg --verify Talkies.AppImage.asc Talkies.AppImage
```

#### Debian Package Signing

```bash
# Sign .deb package
dpkg-sig --sign builder talkies_1.2.3_amd64.deb

# Verify
dpkg-sig --verify talkies_1.2.3_amd64.deb
```

#### GitHub Actions GPG Signing

```yaml
- name: Import GPG key
  env:
    GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
    GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
  run: |
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 --sign Talkies.AppImage
```

### 4.4 Secure Secret Management Best Practices

1. **Use GitHub Secrets:** Never commit certificates or keys to repository
2. **Limit secret scope:** Organization-level for shared, repository-level for specific
3. **Rotate credentials regularly:** Especially API keys and passwords
4. **Use short-lived credentials:** Azure Managed Identities, OIDC tokens
5. **Audit secret access:** Monitor who accesses secrets in Actions logs
6. **Delete secrets when unused:** Remove deprecated certificates
7. **Use environment protection:** Require approvals for production deployments

**GitHub Actions OIDC (No long-lived secrets):**
```yaml
permissions:
  id-token: write

- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## 5. Release Artifacts

### 5.1 macOS Release Artifacts

#### .app Bundle

The basic application bundle, typically distributed inside .dmg or .pkg.

**Structure:**
```
Talkies.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── Talkies (executable)
│   ├── Resources/
│   │   └── AppIcon.icns
│   └── _CodeSignature/
```

**Not recommended for direct distribution** (users prefer .dmg or .pkg)

#### .dmg (Disk Image)

Most popular macOS distribution format.

**Advantages:**
- User-friendly drag-to-Applications experience
- Can include custom background and layout
- Single file distribution
- Easily code signed and notarized

**Creating with create-dmg:**
```bash
npm install -g create-dmg

create-dmg Talkies.app \
  --dmg-title="Talkies" \
  --window-size=600 400 \
  --icon-size=100 \
  --icon="Talkies.app" 175 120 \
  --app-drop-link 425 120 \
  --background="background.png" \
  --overwrite
```

**GitHub Action:**
```yaml
- uses: create-dmg/create-dmg@v1
  with:
    name: Talkies
    srcfolder: Talkies.app
    icon: AppIcon.icns
    background: dmg-background.png
    window_size:
      width: 600
      height: 400
```

#### .pkg (macOS Installer Package)

Traditional macOS installer format, useful for:
- Pre-install/post-install scripts
- Installing to system locations
- Enterprise deployment via MDM
- Multiple component installation

**Creating with pkgbuild:**
```bash
# Simple app package
pkgbuild --root Talkies.app \
  --identifier com.talkies.app \
  --version 1.2.3 \
  --install-location /Applications/Talkies.app \
  --scripts scripts/ \
  Talkies.pkg

# Sign the package
productsign --sign "Developer ID Installer: Your Name (TEAM_ID)" \
  Talkies.pkg Talkies-signed.pkg
```

**Using munkipkg GitHub Action:**
```yaml
- uses: joncrain/munkipkg-action@v1
  with:
    pkg_name: Talkies
    pkg_identifier: com.talkies.app
    pkg_version: 1.2.3
```

**Recommendation:** Provide both .dmg (for end users) and .pkg (for enterprise)

### 5.2 Windows Release Artifacts

#### Portable .exe

Standalone executable with all dependencies included.

**Advantages:**
- No installation required
- Run from USB drives
- No admin rights needed
- Quick testing

**Creating with .NET:**
```bash
dotnet publish -c Release -r win-x64 --self-contained \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true
```

#### .msi (Windows Installer)

Traditional Windows installer format using WiX Toolset.

**Advantages:**
- Standard Windows installation
- Add/Remove Programs integration
- Supports upgrades/downgrades
- Group Policy deployment
- Auto-update support (with Squirrel.Windows)

**Creating with WiX:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="Talkies" Language="1033" Version="1.2.3"
           Manufacturer="Talkies Inc." UpgradeCode="YOUR-GUID">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />

    <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Feature Id="ProductFeature" Title="Talkies" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
  </Product>
</Wix>
```

**Build:**
```bash
wix build -ext WixToolset.UI.wixext Product.wxs -o TalkiesSetup.msi
```

**electron-wix-msi for Electron apps:**
```javascript
const { MSICreator } = require('electron-wix-msi');

const msiCreator = new MSICreator({
  appDirectory: 'dist/Talkies-win32-x64',
  outputDirectory: 'dist/installers',
  exe: 'Talkies.exe',
  name: 'Talkies',
  manufacturer: 'Talkies Inc.',
  version: '1.2.3',
  upgradeCode: 'YOUR-GUID'
});

await msiCreator.create();
await msiCreator.compile();
```

#### .msix (Modern Windows Package)

Modern packaging format for Windows 10/11.

**Advantages:**
- Microsoft Store distribution
- Automatic updates via Store
- Sandboxed execution
- Package extensions support
- Modern installation experience

**Limitations:**
- Requires package identity (not available for standard Tauri builds)
- More restrictive than traditional installers
- Requires Windows 10+

**Tauri MSIX Support:**
Currently, Tauri builds to .msi which cannot have package identity. Building to .msix would enable Windows features like package extensions, but this is not yet supported (see tauri-apps/tauri#4818).

**electron-windows-msix:**
```javascript
const { convertToWindowsStore } = require('electron-windows-msix');

convertToWindowsStore({
  containerVirtualization: true,
  inputDirectory: 'dist/Talkies-win32-x64',
  outputDirectory: 'dist/msix',
  packageName: 'TalkiesApp',
  packageDisplayName: 'Talkies',
  publisherDisplayName: 'Talkies Inc.',
  publisher: 'CN=...',
  version: '1.2.3.0',
  makeAppx: true
});
```

#### Setup.exe (NSIS Installer)

Lightweight installer using Nullsoft Scriptable Install System.

**Advantages:**
- Small installer size
- Fast installation
- Custom UI support
- Widely compatible
- Good for Tauri apps

**Tauri Configuration:**
```json
{
  "tauri": {
    "bundle": {
      "windows": {
        "targets": ["nsis"],
        "nsis": {
          "installMode": "perUser",
          "oneClick": false,
          "allowDowngrades": true,
          "displayLanguageSelector": false
        }
      }
    }
  }
}
```

**Recommendation:** Provide .exe (portable), .msi (enterprise), and .exe installer (NSIS for end users)

### 5.3 Linux Release Artifacts

#### AppImage

Self-contained executable that runs on most Linux distributions.

**Advantages:**
- No installation required
- Works across distros
- No root needed
- Portable

**Creating:**
```bash
# Using appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# Create AppDir structure
mkdir -p Talkies.AppDir/usr/bin
cp target/release/talkies Talkies.AppDir/usr/bin/
cp talkies.desktop Talkies.AppDir/
cp icon.png Talkies.AppDir/

# Generate AppImage
./appimagetool-x86_64.AppImage Talkies.AppDir Talkies.AppImage
```

#### .deb (Debian/Ubuntu Package)

**Creating:**
```bash
# Using cargo-deb
cargo install cargo-deb
cd linux
cargo deb

# Output: target/debian/talkies_1.2.3_amd64.deb
```

**Cargo.toml configuration:**
```toml
[package.metadata.deb]
maintainer = "Your Name <you@example.com>"
copyright = "2025, Your Name"
license-file = ["LICENSE", "4"]
extended-description = """
Talkies voice transcription application
"""
depends = "$auto"
section = "utils"
priority = "optional"
assets = [
    ["target/release/talkies", "usr/bin/", "755"],
    ["README.md", "usr/share/doc/talkies/README", "644"],
]
```

#### .rpm (Red Hat/Fedora Package)

**Creating:**
```bash
# Using cargo-generate-rpm
cargo install cargo-generate-rpm
cd linux
cargo build --release
cargo generate-rpm

# Output: target/generate-rpm/talkies-1.2.3-1.x86_64.rpm
```

#### Flatpak

Sandboxed distribution format.

**Manifest (com.talkies.Talkies.yml):**
```yaml
app-id: com.talkies.Talkies
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: talkies

finish-args:
  - --socket=pulseaudio
  - --socket=wayland
  - --socket=x11
  - --device=dri
  - --share=ipc

modules:
  - name: talkies
    buildsystem: simple
    build-commands:
      - cargo build --release
      - install -Dm755 target/release/talkies /app/bin/talkies
    sources:
      - type: dir
        path: .
```

**Recommendation:** Provide AppImage (universal), .deb (Debian/Ubuntu), and .rpm (Fedora/RHEL)

### 5.4 Checksums and Verification

#### Generating Checksums

**GitHub Actions workflow:**
```yaml
- name: Generate checksums
  run: |
    cd dist

    # SHA256 checksums
    sha256sum *.{dmg,exe,AppImage,deb,rpm} > SHA256SUMS

    # Individual checksum files
    for file in *.{dmg,exe,AppImage,deb,rpm}; do
      sha256sum "$file" > "$file.sha256"
    done

- name: Sign checksums (GPG)
  env:
    GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
    GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
  run: |
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
      --detach-sign --armor dist/SHA256SUMS
```

#### Publishing Verification Instructions

Include in release notes and documentation:

**macOS/Linux:**
```bash
# Verify checksum
sha256sum -c Talkies.dmg.sha256

# Or from SHA256SUMS file
sha256sum -c SHA256SUMS --ignore-missing

# Verify GPG signature
gpg --verify SHA256SUMS.asc SHA256SUMS
```

**Windows (PowerShell):**
```powershell
# Get file hash
$hash = (Get-FileHash -Algorithm SHA256 TalkiesSetup.exe).Hash

# Compare with published checksum
$expected = Get-Content TalkiesSetup.exe.sha256
if ($hash -eq $expected.Split()[0]) {
    Write-Host "Checksum verified!" -ForegroundColor Green
} else {
    Write-Host "Checksum mismatch!" -ForegroundColor Red
}
```

#### Checksum Best Practices

1. **Generate for all artifacts:** Every downloadable file should have a checksum
2. **Use SHA256 or better:** SHA1 and MD5 are cryptographically broken
3. **Sign the checksums file:** Prevents attackers from modifying both file and checksum
4. **Publish through multiple channels:** Website, GitHub Releases, social media
5. **Automate in CI/CD:** Never manually generate checksums
6. **Document verification:** Provide clear instructions for users

---

## 6. Best Practices

### 6.1 Release Drafter for PR-Based Changelogs

Release Drafter automatically creates and updates draft releases as PRs are merged, maintaining an up-to-date changelog without manual effort.

#### Setup and Configuration

**Install the GitHub App:**
- Visit https://github.com/apps/release-drafter
- Install on your repository

**Create .github/release-drafter.yml:**
```yaml
name-template: 'v$RESOLVED_VERSION'
tag-template: 'v$RESOLVED_VERSION'

categories:
  - title: '🚨 Breaking Changes'
    labels:
      - 'breaking'
      - 'breaking-change'
  - title: '🚀 Features'
    labels:
      - 'feature'
      - 'enhancement'
  - title: '🐛 Bug Fixes'
    labels:
      - 'bug'
      - 'fix'
      - 'bugfix'
  - title: '🔒 Security'
    labels:
      - 'security'
  - title: '📚 Documentation'
    labels:
      - 'documentation'
      - 'docs'
  - title: '🧰 Maintenance'
    labels:
      - 'chore'
      - 'dependencies'
      - 'refactor'
  - title: '⚡ Performance'
    labels:
      - 'performance'
      - 'perf'

exclude-labels:
  - 'skip-changelog'
  - 'wontfix'
  - 'duplicate'
  - 'invalid'

version-resolver:
  major:
    labels:
      - 'major'
      - 'breaking'
      - 'breaking-change'
  minor:
    labels:
      - 'minor'
      - 'feature'
      - 'enhancement'
  patch:
    labels:
      - 'patch'
      - 'bug'
      - 'fix'
      - 'bugfix'
      - 'security'
  default: patch

change-template: '- $TITLE @$AUTHOR (#$NUMBER)'
change-title-escapes: '\<*_&'

template: |
  ## What's Changed

  $CHANGES

  ## New Contributors

  $CONTRIBUTORS

  **Full Changelog**: https://github.com/$OWNER/$REPOSITORY/compare/$PREVIOUS_TAG...v$RESOLVED_VERSION

autolabeler:
  - label: 'documentation'
    files:
      - '*.md'
      - 'docs/**/*'
  - label: 'bug'
    branch:
      - '/fix\/.+/'
    title:
      - '/fix/i'
  - label: 'feature'
    branch:
      - '/feature\/.+/'
    title:
      - '/feat/i'
```

**Create .github/workflows/release-drafter.yml:**
```yaml
name: Release Drafter

on:
  push:
    branches:
      - master
      - main
  pull_request_target:
    types: [opened, reopened, synchronize]

permissions:
  contents: write
  pull-requests: write

jobs:
  update_release_draft:
    runs-on: ubuntu-latest
    steps:
      - uses: release-drafter/release-drafter@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### PR Label Strategy

**Required workflow for developers:**
1. Create PR with descriptive title
2. Apply appropriate label: `feature`, `bug`, `breaking`, etc.
3. Merge PR
4. Release Drafter automatically updates draft release

**Enforce labels with workflow:**
```yaml
name: PR Labels Check

on:
  pull_request:
    types: [opened, reopened, labeled, unlabeled]

jobs:
  check-labels:
    runs-on: ubuntu-latest
    steps:
      - name: Check for required labels
        run: |
          LABELS=$(jq -r '.pull_request.labels[].name' "$GITHUB_EVENT_PATH")
          REQUIRED="feature|bug|fix|enhancement|chore|documentation"

          if ! echo "$LABELS" | grep -qE "$REQUIRED"; then
            echo "PR must have at least one of: feature, bug, fix, enhancement, chore, documentation"
            exit 1
          fi
```

#### Publishing the Release

When ready to release:
1. Review the draft release on GitHub
2. Edit if needed
3. Click "Publish release"
4. GitHub Actions workflows trigger on tag creation

### 6.2 Staged Rollouts

Staged rollouts (also called canary deployments or phased rollouts) minimize risk by gradually exposing new versions to increasing percentages of users.

#### The Staged Rollout Process

A typical progression: **5% → 25% → 50% → 100%**

**Phase 1: Canary (5-10%)**
- Duration: 24-48 hours
- Audience: Internal users, beta testers, or random sample
- Monitoring: Intensive - all metrics, crash reports, performance
- Rollback threshold: Any critical issue

**Phase 2: Early Rollout (25%)**
- Duration: 3-5 days
- Audience: Broader user sample
- Monitoring: Key metrics, error rates, performance
- Rollback threshold: Significant degradation

**Phase 3: Majority Rollout (50%)**
- Duration: 5-7 days
- Audience: Half of user base
- Monitoring: Aggregate metrics, trends
- Rollback threshold: Major issues affecting many users

**Phase 4: Full Rollout (100%)**
- Audience: All users
- Monitoring: Ongoing standard monitoring

#### Implementation with Feature Flags

**Using ConfigCat, LaunchDarkly, or custom solution:**

```typescript
// Client code
const featureFlags = await configCat.getValue('release-version', '1.0.0');

if (featureFlags === '1.1.0') {
  // Use new version code
} else {
  // Use stable version code
}
```

**Rollout configuration:**
```json
{
  "key": "release-version",
  "rolloutRules": [
    {
      "percentage": 5,
      "value": "1.1.0",
      "audienceConditions": ["beta_tester"]
    },
    {
      "percentage": 95,
      "value": "1.0.0"
    }
  ]
}
```

#### Ring Deployment Strategy

Ring deployment defines multiple user segments with different risk profiles:

**Ring 0: Internal/Canary (0.1-1%)**
- Internal employees
- Immediate deployment
- High tolerance for issues

**Ring 1: Early Adopters (5-10%)**
- Beta program participants
- Power users who opted in
- 24-48 hour soak time

**Ring 2: General Users (50%)**
- Broad user base
- 3-5 day soak time
- Monitored metrics stable

**Ring 3: Conservative Users (100%)**
- Users who prefer stability
- 7-14 day soak time
- Only after proven stability

#### Auto-Update Configuration

**Electron with electron-updater:**
```typescript
import { autoUpdater } from 'electron-updater';

// Configure staged rollout
autoUpdater.allowPrerelease = false;
autoUpdater.channel = 'stable';

// Custom download percentage
const userId = getUserId();
const rolloutPercentage = 25; // 25% rollout

const shouldUpdate = hashUserIdToPercentage(userId) <= rolloutPercentage;

if (shouldUpdate) {
  autoUpdater.checkForUpdatesAndNotify();
}

function hashUserIdToPercentage(userId: string): number {
  const hash = crypto.createHash('sha256').update(userId).digest('hex');
  return parseInt(hash.substring(0, 8), 16) % 100;
}
```

**Tauri with tauri-plugin-updater:**
```rust
use tauri::updater::{UpdaterBuilder, UpdateResponse};

// Check if user in rollout percentage
let user_id = get_user_id();
let rollout_percentage = 50;
let user_hash = hash_to_percentage(&user_id);

if user_hash <= rollout_percentage {
    let update = app.updater()
        .check()
        .await?;

    if let UpdateResponse::Update(update) = update {
        update.download_and_install().await?;
    }
}
```

#### Monitoring During Rollout

**Key Metrics to Track:**
- Crash rate (should not increase)
- Error rate (API, network, application errors)
- Performance metrics (startup time, memory usage)
- User engagement (session duration, feature usage)
- Rollback rate (users downgrading)

**Automated Rollback Triggers:**
```yaml
# Pseudo-configuration
rollout:
  version: 1.1.0
  stages:
    - percentage: 5
      duration: 48h

  rollbackTriggers:
    - metric: crash_rate
      threshold: 5%
      comparison: increase
    - metric: error_rate
      threshold: 10%
      comparison: increase
    - metric: startup_time_p95
      threshold: 20%
      comparison: increase
```

### 6.3 Rollback Strategies

#### Desktop Application Rollback Challenges

Unlike web applications, desktop app rollbacks are complex:
- Users have locally installed versions
- Cannot force immediate downgrade
- Requires user action or auto-update mechanism

#### Strategy 1: Halt Update Distribution (Immediate)

**Action:** Stop serving the problematic version via update channels

**GitHub Release approach:**
```bash
# Delete the bad release
gh release delete v1.2.3 --yes

# Recreate with previous version
gh release create v1.2.3 --notes "Reverted to stable version" \
  --title "v1.2.3 (Reverted)" \
  path/to/v1.2.2/artifacts/*
```

**Auto-update server approach:**
Update server configuration to serve previous version:
```json
{
  "version": "1.2.2",
  "url": "https://releases.talkies.app/v1.2.2/Talkies-Setup.exe",
  "releaseNotes": "Rollback to stable version due to issues in 1.2.3"
}
```

#### Strategy 2: Push Downgrade Update (Active)

**Electron with electron-updater:**
```typescript
// In problematic v1.2.3, detect issue and force downgrade
if (criticalIssueDetected()) {
  autoUpdater.channel = 'rollback';
  autoUpdater.checkForUpdates(); // Serves v1.2.2
}
```

**Update manifest:**
```json
{
  "version": "1.2.2",
  "forceDowngrade": true,
  "reason": "Critical bug in v1.2.3 affecting data integrity",
  "url": "..."
}
```

#### Strategy 3: Kill Switch / Feature Disable

**Disable problematic feature remotely:**
```typescript
// Client checks remote config on startup
const remoteConfig = await fetch('https://api.talkies.app/config');
const featureFlags = await remoteConfig.json();

if (featureFlags.disableNewFeature) {
  // Revert to old behavior without full rollback
  useOldImplementation();
}
```

#### Strategy 4: Communicate and Wait (Passive)

**When rollback isn't urgent:**
1. Post announcement on website/social media
2. Update GitHub Release notes with warning
3. Release hotfix version (v1.2.4) quickly
4. Wait for users to update naturally

#### Rollback Communication Template

**GitHub Release Notes:**
```markdown
# ⚠️ Version 1.2.3 Rolled Back

We've identified a critical issue in version 1.2.3 that affects [description].

## Action Required

If you've updated to v1.2.3, please:
1. Download v1.2.2 from [link]
2. Uninstall v1.2.3
3. Install v1.2.2

Auto-update users will automatically receive v1.2.2.

## What happened

[Brief technical explanation]

## Resolution

We're working on v1.2.4 which will include:
- Fix for [issue]
- Additional testing procedures

Expected release: [date]

## Apologies

We apologize for the inconvenience. We're reviewing our release process to prevent similar issues.
```

#### Preventing the Need for Rollbacks

1. **Comprehensive testing:**
   - Unit tests
   - Integration tests
   - E2E tests on all platforms
   - Manual QA on real devices

2. **Beta testing period:**
   - Minimum 1-2 weeks in beta channel
   - Active beta user community
   - Telemetry and crash reporting from beta

3. **Staged rollouts:**
   - Catch issues before 100% deployment
   - Easier to halt at 10% than rollback 100%

4. **Feature flags:**
   - New features behind flags
   - Can disable remotely if issues arise
   - Gradual enablement

5. **Automated monitoring:**
   - Crash rate alerts
   - Performance regression detection
   - Error rate monitoring
   - Automated rollback triggers

### 6.4 Additional Best Practices

#### Changelog Maintenance

**Keep a CHANGELOG.md in repository:**
```markdown
# Changelog

All notable changes to Talkies will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Dark mode support for macOS

### Fixed
- Crash on startup with certain audio devices

## [1.2.3] - 2025-01-15

### Added
- GPU-accelerated transcription on Windows
- Support for 40+ languages

### Changed
- Improved audio quality detection
- Updated UI with glassmorphic design

### Fixed
- Memory leak in audio recorder
- Text insertion on Wayland

### Security
- Updated dependencies with security vulnerabilities

[Unreleased]: https://github.com/talkies/talkies/compare/v1.2.3...HEAD
[1.2.3]: https://github.com/talkies/talkies/compare/v1.2.2...v1.2.3
```

#### Continuous Integration Checks

**Pre-release validation workflow:**
```yaml
name: Release Checks

on:
  push:
    tags:
      - 'v*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check version consistency
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}

          # Extract versions from each platform
          MAC_VERSION=$(grep -m1 CFBundleShortVersionString mac/Info.plist | sed 's/.*<string>\(.*\)<\/string>/\1/')
          WIN_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" windows/Talkies.csproj)
          LIN_VERSION=$(grep -m1 '^version' linux/Cargo.toml | sed 's/.*"\(.*\)".*/\1/')

          # Validate all match
          if [[ "$TAG_VERSION" != "$MAC_VERSION" ]] || \
             [[ "$TAG_VERSION" != "$WIN_VERSION" ]] || \
             [[ "$TAG_VERSION" != "$LIN_VERSION" ]]; then
            echo "Version mismatch detected!"
            echo "Tag: $TAG_VERSION"
            echo "macOS: $MAC_VERSION"
            echo "Windows: $WIN_VERSION"
            echo "Linux: $LIN_VERSION"
            exit 1
          fi

      - name: Check CHANGELOG updated
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          if ! grep -q "## \[$TAG_VERSION\]" CHANGELOG.md; then
            echo "CHANGELOG.md not updated for version $TAG_VERSION"
            exit 1
          fi

      - name: Run tests
        run: |
          # Platform-specific test commands
          cd mac && swift test
          cd ../windows && dotnet test
          cd ../linux && cargo test
```

#### Release Checklist Template

**Create .github/RELEASE_CHECKLIST.md:**
```markdown
# Release Checklist

## Pre-Release (T-7 days)

- [ ] Create release branch `release/vX.Y.Z`
- [ ] Update version numbers in all platform files
- [ ] Update CHANGELOG.md with all changes
- [ ] Update documentation for new features
- [ ] Freeze feature development
- [ ] Begin QA testing on all platforms

## Beta Release (T-5 days)

- [ ] Tag beta version `vX.Y.Z-beta.1`
- [ ] Build and sign all platform artifacts
- [ ] Upload to beta distribution channels
- [ ] Notify beta testers
- [ ] Monitor crash reports and feedback

## Release Candidate (T-2 days)

- [ ] Tag release candidate `vX.Y.Z-rc.1`
- [ ] Full regression testing
- [ ] Performance testing
- [ ] Security audit
- [ ] Update screenshots and marketing materials

## Release Day

- [ ] Tag stable release `vX.Y.Z`
- [ ] Build and sign all artifacts
- [ ] Generate checksums and signatures
- [ ] Create GitHub Release with notes
- [ ] Upload artifacts to all distribution channels
- [ ] Update website download links
- [ ] Post announcement on social media
- [ ] Send email to mailing list
- [ ] Update documentation site
- [ ] Monitor crash reports and user feedback

## Post-Release (T+1 week)

- [ ] Analyze adoption metrics
- [ ] Review crash reports
- [ ] Plan hotfix if needed
- [ ] Retrospective meeting
- [ ] Update release process based on learnings
```

#### Documentation

**Maintain comprehensive release documentation:**
- Release process runbook
- Emergency rollback procedures
- Code signing certificate renewal process
- Access control and permissions documentation
- Incident response playbook

---

## 7. Recommended Implementation for Talkies

### 7.1 Proposed Release Strategy

**Versioning:** Calendar Versioning (YY.0M.MICRO)
- Example: 25.01.0 (January 2025, first release)
- Rationale: User-facing app where recency matters more than API compatibility

**Channels:**
- **Stable:** Production releases, tested thoroughly
- **Beta:** 2-week preview, opt-in
- **Nightly:** Daily builds from master (optional, for power users)

**Release Cadence:**
- Stable: Monthly (first week of month)
- Beta: 2 weeks before stable
- Nightly: Daily automated builds

### 7.2 GitHub Actions Workflow Structure

```
.github/
├── workflows/
│   ├── ci.yml                    # Run on every PR/push
│   ├── release-drafter.yml       # Auto-generate release notes
│   ├── nightly.yml               # Daily nightly builds
│   ├── beta-release.yml          # Tag-triggered beta release
│   └── stable-release.yml        # Tag-triggered stable release
└── release-drafter.yml           # Release Drafter config
```

### 7.3 Version Management

**Single source of truth: VERSION file in root**

```
talkies/
├── VERSION                       # 25.01.0
├── .github/
├── mac/
├── windows/
└── linux/
```

**Pre-commit hook to sync versions:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

VERSION=$(cat VERSION)

# Update macOS
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" mac/Info.plist

# Update Windows
sed -i "s/<Version>.*<\/Version>/<Version>$VERSION<\/Version>/" windows/Talkies.csproj

# Update Linux
sed -i "s/^version = .*/version = \"$VERSION\"/" linux/Cargo.toml

git add mac/Info.plist windows/Talkies.csproj linux/Cargo.toml
```

### 7.4 Artifact Distribution Plan

| Platform | Stable | Beta | Nightly |
|----------|--------|------|---------|
| **macOS** | .dmg (universal) | .dmg | .dmg |
| **Windows** | .exe (setup), .msi | .exe (setup) | .exe (portable) |
| **Linux** | .AppImage, .deb, .rpm | .AppImage | .AppImage |

**Storage:**
- GitHub Releases (stable, beta)
- Separate S3 bucket or CDN for nightly builds
- Homebrew cask (macOS stable)
- winget repository (Windows stable)

### 7.5 Staged Rollout Plan

**Week 1: Beta Release**
- Tag: `v25.01.0-beta.1`
- Audience: Beta testers (opt-in)
- Distribution: GitHub Releases (pre-release), beta download page

**Week 3: Stable Release - Phase 1 (10%)**
- Tag: `v25.01.0`
- Audience: Random 10% of auto-update users
- Duration: 48 hours
- Monitoring: Crash rate, error rate, performance

**Week 3: Stable Release - Phase 2 (50%)**
- Audience: Random 50% of auto-update users
- Duration: 72 hours

**Week 3-4: Stable Release - Phase 3 (100%)**
- Audience: All users
- Update website, announce publicly

### 7.6 Required GitHub Secrets

```
# macOS
MACOS_CERTIFICATE              # Base64-encoded .p12
MACOS_CERTIFICATE_PASSWORD     # Certificate password
APPLE_ID                       # Apple ID email
APPLE_APP_SPECIFIC_PASSWORD    # App-specific password
APPLE_TEAM_ID                  # 10-character team ID

# Windows
AZURE_KEY_VAULT_URI            # Key Vault URL
AZURE_CLIENT_ID                # Service Principal ID
AZURE_CLIENT_SECRET            # Service Principal secret
AZURE_TENANT_ID                # Azure AD tenant ID
AZURE_CERT_NAME                # Certificate name

# Linux (optional, for GPG signing)
GPG_PRIVATE_KEY                # GPG private key
GPG_PASSPHRASE                 # GPG key passphrase

# General
GITHUB_TOKEN                   # Auto-provided
```

---

## 8. Conclusion

Modern release management for desktop applications requires careful orchestration of build automation, versioning, code signing, distribution, and monitoring. Key takeaways:

1. **Automate everything:** Manual processes introduce errors and delays
2. **Sign and notarize:** Required for modern OS trust and distribution
3. **Use staged rollouts:** Catch issues before they affect all users
4. **Maintain changelogs:** Automated with Release Drafter and PR labels
5. **Monitor intensively:** Especially during rollouts
6. **Plan for rollbacks:** Have procedures ready before you need them
7. **Test across platforms:** Matrix builds catch platform-specific issues
8. **Version consistently:** Single source of truth prevents mismatches
9. **Communicate clearly:** Users deserve transparency about updates
10. **Iterate and improve:** Retrospectives after each release

By implementing these practices, Talkies can achieve reliable, professional releases across macOS, Windows, and Linux with minimal manual intervention.

---

## 9. Sources and References

### GitHub Actions and Automation
- [Automating Semantic Versioning with GitHub Actions](https://medium.com/@swastikaaryal/automating-semantic-versioning-with-github-actions-33e9fa23d912)
- [Git Automatic Semantic Versioning GitHub Action](https://github.com/marketplace/actions/git-automatic-semantic-versioning)
- [semantic-release/semantic-release](https://github.com/semantic-release/semantic-release)
- [PaulHatch/semantic-version](https://github.com/PaulHatch/semantic-version)
- [jefflinse/pr-semver-bump](https://github.com/jefflinse/pr-semver-bump)
- [Automate Version Bumping With Commitizen](https://splitreq.com/blog/automate-version-bumping-with-commitizen)
- [GitHub Actions: Change artifact/log retention days](https://github.blog/changelog/2020-10-08-github-actions-ability-to-change-retention-days-for-artifacts-and-logs/)
- [GitHub Docs: Configuring retention period for artifacts and logs](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization)

### Release Channels and Strategies
- [Release Channels - The Rust Programming Language](https://doc.rust-lang.org/1.28.0/book/first-edition/release-channels.html)
- [What is the difference between Nightly, Beta and Release builds? - Brave](https://support.brave.app/hc/en-us/articles/360017916752-What-is-the-difference-between-Nightly-Beta-and-Release-builds)
- [Chrome browser release channels](https://support.google.com/chrome/a/answer/9027636?hl=en)
- [Release Channels: Beta, Stable, and LTS](https://medium.com/beyond-the-brackets/release-channels-beta-stable-and-long-term-support-lts-dc971742b122)

### Versioning
- [SemVer vs. CalVer: Choosing the Best Versioning Strategy](https://sensiolabs.com/blog/2025/semantic-vs-calendar-versioning)
- [Calendar Versioning - CalVer](https://calver.org/)
- [When to use SemVer or CalVer: project type considerations](https://frontside.com/blog/2022-02-09-semver-or-calver-by-project-type/)
- [Sometimes I regret using CalVer](https://jacobtomlinson.dev/posts/2023/sometimes-i-regret-using-calver/)
- [A Guide to Monorepos for Front-end Code](https://www.toptal.com/front-end/guide-to-monorepos)
- [What is monorepo?](https://semaphore.io/blog/what-is-monorepo)

### macOS Code Signing
- [Automatic Code-signing and Notarization for macOS apps using GitHub Actions](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/)
- [indygreg/apple-code-sign-action](https://github.com/indygreg/apple-code-sign-action)
- [omkarcloud/macos-code-signing-example](https://github.com/omkarcloud/macos-code-signing-example)
- [How to automatically sign macOS apps using GitHub Actions](https://localazy.com/blog/how-to-automatically-sign-macos-apps-using-github-actions)
- [Signing and Notarizing with GitHub Actions](https://gregoryszorc.com/docs/apple-codesign/stable/apple_codesign_github_actions.html)

### Release Artifacts
- [create-dmg/create-dmg](https://github.com/create-dmg/create-dmg)
- [Create macOS dmg GitHub Action](https://github.com/marketplace/actions/create-macos-dmg)
- [munkipkg-action](https://github.com/joncrain/munkipkg-action)
- [Distributing Mac Apps With GitHub Actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/)
- [Windows Installer - Tauri](https://v2.tauri.app/distribute/windows-installer/)
- [electron-userland/electron-wix-msi](https://github.com/electron-userland/electron-wix-msi)
- [electron-userland/electron-windows-msix](https://github.com/bitdisaster/electron-windows-msix)

### Release Drafter
- [release-drafter/release-drafter](https://github.com/release-drafter/release-drafter)
- [GitHub Actions example for automatic release drafts and changelog.md creation](https://johanneskonings.dev/blog/2021-02-28-github-automatic-releases-and-changelog/)
- [GitHub Docs: Automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)

### Staged Rollouts and Deployment
- [Canary Deployments: Pros, Cons, And Best Practices](https://octopus.com/devops/software-deployments/canary-deployment/)
- [6 Deployment Strategies for Smooth Software Updates](https://reliasoftware.com/blog/deployment-strategy)
- [What is Canary Testing? Best Practices Guide](https://www.mida.so/blog/canary-testing)
- [Using ConfigCat for Staged Rollouts and Canary Releases](https://configcat.com/blog/2024/01/16/using-configcat-for-staged-rollouts-and-canary-releases/)
- [Canary vs. blue/green vs. rolling deployment](https://www.getunleash.io/blog/comparing-deployment-strategies-canary-blue-green-and-rolling)

### Git Strategy
- [Git tags vs branches: Differences and when to use them](https://circleci.com/blog/git-tags-vs-branches/)
- [What are Release Tags in Git, and How Do You Use Them?](https://www.howtogeek.com/devops/what-are-release-tags-in-git-and-how-do-you-use-them/)
- [Git Tags and Releases Best Practices](https://devtoolhub.com/git-tags-releases-best-practices/)
- [Branch for release - Trunk Based Development](https://trunkbaseddevelopment.com/branch-for-release/)
