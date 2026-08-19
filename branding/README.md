# Talkies Branding Assets

> **Single source of truth for all Talkies brand assets across platforms**

This directory contains all official Talkies brand assets for use across macOS, Windows, and web platforms. All assets are designed to maintain consistent brand identity while being optimized for each platform.

## 📁 Directory Structure

```
branding/
├── README.md                        # This file
├── logos/                           # Logo variations
│   ├── talkies-logo.svg            # Primary logo (512×512) - purple/pink gradient
│   ├── talkies-logo-light.svg      # Logo for light backgrounds
│   ├── talkies-logo-monochrome-white.svg  # White version for dark backgrounds
│   └── talkies-logo-monochrome-black.svg  # Black version for light backgrounds
├── icons/                           # App icons (multiple sizes)
│   ├── favicon.svg                 # 32×32 favicon
│   ├── icon-16.svg                 # 16×16 icon
│   ├── icon-32.svg                 # 32×32 icon
│   ├── icon-64.svg                 # 64×64 icon
│   ├── icon-128.svg                # 128×128 icon
│   └── icon-256.svg                # 256×256 icon
├── social/                          # Social media assets
│   └── og-image.svg                # Open Graph image (1200×630)
├── colors/                          # Color palette definitions
│   ├── palette.json                # Universal color definitions
│   ├── palette.css                 # CSS custom properties (web)
│   ├── palette.swift               # Swift color extensions (macOS)
│   └── palette.xaml                # XAML resources (Windows)
└── guidelines/                      # Additional guidelines
    └── (reserved for future use)
```

## 🎨 Quick Start

### For Web/Frontend Developers
```bash
# Copy web assets
cp branding/icons/favicon.svg frontend/public/
cp branding/logos/talkies-logo.svg frontend/public/
cp branding/social/og-image.svg frontend/public/

# Import color palette
# Add to your CSS:
@import url('../../../branding/colors/palette.css');
```

### For macOS Developers
```swift
// Add to your Swift project
// Copy branding/colors/palette.swift to your project
import SwiftUI

// Use brand colors
.foregroundColor(.brandPurple)
.background(Color.gradientPrimary)
```

### For Windows Developers
```xml
<!-- Add to App.xaml -->
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.MergedDictionaries>
            <ResourceDictionary Source="pack://application:,,,/branding/colors/palette.xaml"/>
        </ResourceDictionary.MergedDictionaries>
    </ResourceDictionary>
</Application.Resources>

<!-- Use brand colors -->
<Button Background="{StaticResource GradientPrimary}"/>
```

## 🎯 Platform-Specific Guidelines

### macOS (`mac/`)

**App Icon**
- Use `branding/icons/icon-256.svg` as base
- Generate `.icns` file using `iconutil` or similar
- Place in `mac/Resources/Assets.xcassets/AppIcon.appiconset/`

**Colors**
- Import `branding/colors/palette.swift` into your project
- Use semantic color names (e.g., `.brandPurple`, `.textPrimary`)
- Leverage `Color.gradientPrimary` for consistent gradients

**Integration**
```bash
# Link or copy brand assets to macOS project
ln -s ../branding mac/Resources/Branding
```

### Windows (`windows/`)

**App Icon**
- Use `branding/icons/icon-256.svg` as base
- Convert to `.ico` format with multiple sizes (16, 32, 48, 256)
- Place in `windows/Talkies.Windows/Resources/`

**Colors**
- Merge `branding/colors/palette.xaml` into `App.xaml`
- Reference colors using `{StaticResource BrandPurple}`
- Use `{StaticResource GradientPrimary}` for consistent branding

**Integration**
```xml
<!-- In App.xaml -->
<ResourceDictionary.MergedDictionaries>
    <ResourceDictionary Source="../../branding/colors/palette.xaml"/>
</ResourceDictionary.MergedDictionaries>
```

### Frontend (`frontend/`)

**Favicon & Icons**
- Copy `branding/icons/favicon.svg` to `frontend/public/`
- Reference in `frontend/app/layout.tsx` metadata

**OG Image**
- Copy `branding/social/og-image.svg` to `frontend/public/`
- Configure in Next.js metadata for social sharing

**Colors**
- Colors already integrated in `frontend/tailwind.config.ts`
- Optionally import `branding/colors/palette.css` for CSS variables
- Use Tailwind classes: `bg-gradient-to-r from-purple-400 to-pink-400`

## 📐 Logo Usage Guidelines

### Primary Logo (`talkies-logo.svg`)
- **Use:** Dark backgrounds, website headers, app icons
- **Colors:** Purple (#a855f7) to Pink (#ec4899) gradient
- **Minimum size:** 32×32px
- **Clear space:** 20% of logo width on all sides

### Logo for Light Backgrounds (`talkies-logo-light.svg`)
- **Use:** Light/white backgrounds, print materials
- **Colors:** Darker purple/pink gradient for better contrast

### Monochrome Variants
- **White:** Use on dark backgrounds when color isn't appropriate
- **Black:** Use on light backgrounds when color isn't appropriate
- Maintain same spacing and sizing as primary logo

### Don'ts ❌
- Don't stretch or distort the logo
- Don't change gradient colors or direction
- Don't add effects (shadows, outlines, glows) unless specified
- Don't place on low-contrast backgrounds
- Don't rotate or skew
- Don't use outdated logo versions

## 🎨 Color Palette

### Primary Colors
| Color | Hex | Usage |
|-------|-----|-------|
| Purple | `#a855f7` | Primary brand color, CTAs, highlights |
| Pink | `#ec4899` | Secondary brand color, gradients, hover states |

### Supporting Colors
| Color | Hex | Usage |
|-------|-----|-------|
| Blue | `#3b82f6` | Information, links, active states |
| Cyan | `#06b6d4` | Success states, data visualization |
| Orange | `#f97316` | Warnings, notifications |

### Neutral Colors
| Color | Value | Usage |
|-------|-------|-------|
| Background | `#0a0a0f` | Primary background |
| Text Primary | `#ffffff` | Primary text |
| Text Secondary | `rgba(255,255,255,0.7)` | Secondary text |
| Border | `rgba(255,255,255,0.1)` | Default borders |

See `colors/palette.json` for complete color definitions including RGB, HSL, and platform-specific formats.

## 📱 Icon Sizes

All icons are provided in SVG format at multiple sizes:

| Size | Filename | Usage |
|------|----------|-------|
| 16×16 | `icon-16.svg` | Windows taskbar, browser tabs (small) |
| 32×32 | `icon-32.svg` | Favicon, small UI elements |
| 64×64 | `icon-64.svg` | macOS Dock (1x), Windows taskbar |
| 128×128 | `icon-128.svg` | macOS Dock (2x), large icons |
| 256×256 | `icon-256.svg` | App icon base, high-DPI displays |
| 512×512 | `talkies-logo.svg` | Marketing, high-resolution needs |

### Converting to Platform Formats

**macOS (.icns)**
```bash
# Create iconset directory
mkdir AppIcon.iconset

# Convert SVGs to PNGs at different sizes (requires inkscape or similar)
inkscape -w 16 -h 16 branding/icons/icon-16.svg -o AppIcon.iconset/icon_16x16.png
inkscape -w 32 -h 32 branding/icons/icon-32.svg -o AppIcon.iconset/icon_16x16@2x.png
# ... (continue for all sizes)

# Generate .icns
iconutil -c icns AppIcon.iconset
```

**Windows (.ico)**
```bash
# Use ImageMagick or similar
convert branding/icons/icon-{16,32,48,256}.svg app.ico
```

**Web (PNG fallback)**
```bash
# Generate PNG versions for browser compatibility
inkscape -w 32 -h 32 branding/icons/favicon.svg -o favicon-32x32.png
inkscape -w 180 -h 180 branding/icons/icon-256.svg -o apple-touch-icon.png
```

## 📄 Social Media Assets

### Open Graph Image (`og-image.svg`)
- **Size:** 1200×630px
- **Format:** SVG (works for most platforms, convert to PNG if needed)
- **Usage:** Twitter cards, Facebook sharing, LinkedIn, etc.
- **Features:** Dark background, centered logo, tagline

### Creating Platform-Specific Variants
```bash
# Twitter/X (1200×630)
inkscape -w 1200 -h 630 branding/social/og-image.svg -o og-twitter.png

# Facebook (1200×630)
# Same as Twitter

# LinkedIn (1200×627)
inkscape -w 1200 -h 627 branding/social/og-image.svg -o og-linkedin.png
```

## 🔄 Updating Assets

When updating brand assets:

1. **Update source files** in `/branding` first
2. **Propagate to platforms:**
   - Frontend: Copy to `frontend/public/`
   - macOS: Update assets in `mac/Resources/`
   - Windows: Update assets in `windows/Talkies.Windows/Resources/`
3. **Update version** in this README
4. **Document changes** in git commit message
5. **Test all platforms** to ensure consistency

## 📋 Checklist for New Platforms

Adding Talkies to a new platform? Use this checklist:

- [ ] Copy appropriate logo variant from `branding/logos/`
- [ ] Copy required icon sizes from `branding/icons/`
- [ ] Import color palette from `branding/colors/`
- [ ] Set up app icon using `icon-256.svg` as base
- [ ] Configure social sharing with `og-image.svg`
- [ ] Test logo visibility on both light and dark backgrounds
- [ ] Verify color contrast meets WCAG AA standards (4.5:1 minimum)
- [ ] Document platform-specific integration in this README

## 📚 Additional Resources

- **Complete Brand Kit:** See `/docs/BRAND_KIT.md` for full guidelines
- **Typography:** Geist Sans (primary), Geist Mono (code)
- **Design Tokens:** Border radius, shadows, animations in `/docs/BRAND_KIT.md`
- **Accessibility:** All colors meet WCAG AA standards on specified backgrounds

## 🤝 Contributing

When contributing brand assets:

1. Maintain SVG format for all vector assets
2. Follow existing naming conventions
3. Update this README with any new assets
4. Ensure all platforms can use the asset (or provide platform-specific variants)
5. Test on dark and light backgrounds
6. Verify accessibility (contrast ratios, color blindness)

## 📝 Version History

- **v1.0.0** (2025-12-15) - Initial brand kit with logos, icons, colors, and social assets

---

**Questions?** See `/docs/BRAND_KIT.md` for complete brand guidelines or open an issue.
