# DMG Background Image Specification

This document describes how to create a custom background image for the Talkies DMG installer.

## Requirements

### Dimensions

- **Standard**: 800 x 400 pixels
- **Retina (Recommended)**: 1600 x 800 pixels @ 2x

Create at 2x resolution for sharp display on Retina displays. macOS will automatically scale down for non-Retina screens.

### File Format

- **Format**: PNG with alpha transparency
- **Color Space**: sRGB
- **Bit Depth**: 24-bit color + 8-bit alpha (32-bit total)
- **Filename**: `dmg-background.png` (place in this directory)

## Layout Guide

The DMG window shows:
1. **Talkies.app icon** - Positioned at approximately (200, 190)
2. **Applications folder symlink** - Positioned at approximately (600, 185)

### Design Recommendations

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│                         Talkies Logo                           │
│                                                                │
│                                                                │
│        ┌────────┐                         ┌────────┐          │
│        │        │     ────────────>        │        │          │
│        │ App    │      Drag to Install     │ Apps   │          │
│        │ Icon   │                          │ Folder │          │
│        └────────┘                         └────────┘          │
│         (200px)                            (600px)            │
│                                                                │
│                    Voice Transcription                         │
│                                                                │
└────────────────────────────────────────────────────────────────┘
    800px width (or 1600px @ 2x)
```

### Color Scheme

Use colors from the Talkies brand kit (see `/branding/` directory):

- **Background**: Gradient or solid color matching app theme
- **Accent**: Use brand primary color for arrows/highlights
- **Text**: High contrast for readability on both light/dark macOS themes

### Elements to Include

1. **Talkies Logo/Name**: Top center, clearly visible
2. **Directional Arrow**: Visual guide from app to Applications folder
3. **Brief Tagline**: e.g., "Voice Transcription" or "Transcribe with Ease"
4. **Background**: Subtle gradient or pattern, not too busy

### Elements to Avoid

- Don't obscure the icon positions (200, 190) and (600, 185)
- Avoid text that might conflict with Finder labels
- Don't use overly bright backgrounds that reduce icon visibility
- Avoid small text (won't be readable at actual size)

## Design Tools

### Figma Template

Dimensions: 1600 x 800 pixels @ 2x
Grid: 100px squares for icon alignment

### Sketch Template

Artboard: 800 x 400 points @ 2x (1600 x 800 pixels)

### Photoshop Template

Canvas: 1600 x 800 pixels
Resolution: 144 PPI (for @2x)

## Testing Your Design

1. Save as `dmg-background.png` in this directory
2. Build DMG: `./build-dmg.sh`
3. Mount DMG and verify:
   - Icons are not obscured by background elements
   - Text is readable
   - Arrow/guide is clear
   - Looks good on both light and dark macOS themes

## Examples

### Minimal Design

```
Background: White (light mode) or dark gray (dark mode)
Arrow: Simple blue arrow between icons
Logo: Top center, Talkies wordmark
Tagline: "Voice Transcription" below logo
```

### Modern Gradient

```
Background: Gradient from brand primary to secondary color
Arrow: Subtle white/light arrow with glow
Logo: Top center with shadow for depth
Tagline: Bottom center in light text
```

## Light/Dark Mode Considerations

Since macOS Finder doesn't adapt the DMG background to system theme, choose:

1. **Neutral Background**: Works on both light and dark Finder backgrounds
   - Light gray (#F5F5F5) or off-white
   - Avoid pure white (harsh) or pure black (too dark)

2. **Gradient**: Helps create depth without being theme-specific

3. **Test Both Modes**:
   - System Preferences > General > Appearance
   - Switch between Light and Dark mode
   - Verify background looks good in both

## File Location

Place your final background image at:
```
/home/fource/talkies/packaging/macos/dmg-background.png
```

The build script will automatically detect and use it.

## No Background Option

If you prefer no custom background (simple white), the script will work fine without `dmg-background.png`. The DMG will have a clean, standard appearance with just the icons and Applications symlink.

## Reference Examples

Check out DMGs from popular macOS apps for inspiration:
- Visual Studio Code
- Slack
- Discord
- Figma
- Rectangle

Download their DMGs and see how they design their installer windows.
