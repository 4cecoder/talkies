# Talkies Brand Kit

> Official brand guidelines for Talkies - Voice-Powered Writing Assistant

## Brand Overview

Talkies is a privacy-first, voice-powered writing assistant that helps users write 3x faster. Our brand communicates speed, clarity, and modern technology while maintaining an approachable, professional tone.

## Logo

### Primary Logo
- **File**: `frontend/public/talkies-logo.svg`
- **Usage**: Website headers, app icons, marketing materials
- **Minimum size**: 32px × 32px
- **Clear space**: Maintain 20% of logo width as clear space on all sides

### Favicon
- **File**: `frontend/public/favicon.svg`
- **Usage**: Browser tabs, bookmarks, PWA icons
- **Size**: 32px × 32px optimized

### Logo Variations

**Full Color** (Primary)
- Use on dark backgrounds (#0a0a0f or darker)
- Default gradient: Purple (#a855f7) to Pink (#ec4899)

**Monochrome**
- Use white (#ffffff) on dark backgrounds
- Use dark (#0a0a0f) on light backgrounds
- Maintain 4.5:1 contrast ratio for accessibility

### Logo Don'ts
- ❌ Don't stretch or distort the logo
- ❌ Don't change the gradient colors
- ❌ Don't add drop shadows or effects
- ❌ Don't place on low-contrast backgrounds
- ❌ Don't rotate or skew the logo

## Color Palette

### Primary Colors

**Purple** - Primary Brand Color
- Hex: `#a855f7`
- RGB: `168, 85, 247`
- HSL: `277, 91%, 65%`
- Usage: Primary CTAs, highlights, brand accents

**Pink** - Secondary Brand Color
- Hex: `#ec4899`
- RGB: `236, 72, 153`
- HSL: `330, 81%, 60%`
- Usage: Gradients, secondary CTAs, hover states

### Supporting Colors

**Blue**
- Hex: `#3b82f6`
- Usage: Information, links, active states

**Cyan**
- Hex: `#06b6d4`
- Usage: Success states, data visualization

**Orange**
- Hex: `#f97316`
- Usage: Warnings, notifications, energy accents

### Neutral Colors

**Background**
- Primary: `#0a0a0f` (Dark navy/black)
- Card: `rgba(255, 255, 255, 0.05)`
- Card Hover: `rgba(255, 255, 255, 0.08)`
- Input: `rgba(255, 255, 255, 0.05)`

**Text**
- Primary: `#ffffff` (100% opacity)
- Secondary: `rgba(255, 255, 255, 0.7)` (70% opacity)
- Tertiary: `rgba(255, 255, 255, 0.5)` (50% opacity)
- Muted: `rgba(255, 255, 255, 0.4)` (40% opacity)

**Borders**
- Default: `rgba(255, 255, 255, 0.1)`
- Hover: `rgba(255, 255, 255, 0.2)`
- Focus: `rgba(168, 85, 247, 0.5)` (Purple with 50% opacity)

### Gradients

**Primary Gradient** (Purple to Pink)
```css
background: linear-gradient(135deg, #a855f7 0%, #ec4899 100%);
```

**Glow Effect**
```css
box-shadow: 0 0 40px rgba(168, 85, 247, 0.3);
background: linear-gradient(135deg,
  rgba(168, 85, 247, 0.3) 0%,
  rgba(236, 72, 153, 0.3) 100%
);
filter: blur(20px);
```

## Typography

### Primary Font: Geist Sans
- **Usage**: Headings, body text, UI elements
- **Weights**: 400 (Regular), 500 (Medium), 600 (Semibold), 700 (Bold)
- **Source**: `next/font/google`

### Monospace Font: Geist Mono
- **Usage**: Code snippets, technical content
- **Weights**: 400 (Regular), 500 (Medium)
- **Source**: `next/font/google`

### Type Scale

```
Hero Headline:    4.5rem (72px) / Bold
H1:               3rem (48px) / Bold
H2:               2.25rem (36px) / Semibold
H3:               1.875rem (30px) / Semibold
H4:               1.5rem (24px) / Medium
Body Large:       1.125rem (18px) / Regular
Body:             1rem (16px) / Regular
Body Small:       0.875rem (14px) / Regular
Caption:          0.75rem (12px) / Regular
```

### Line Heights
- Headings: 1.2
- Body text: 1.6
- UI elements: 1.5

## Design Tokens

### Border Radius
- Cards: `1.5rem` (24px)
- Buttons: `0.75rem` (12px)
- Inputs: `0.75rem` (12px)

### Shadows
- **Glow**: `0 0 40px rgba(168, 85, 247, 0.3)`
- **Glow Small**: `0 0 20px rgba(168, 85, 247, 0.2)`
- **Card**: `0 8px 32px rgba(0, 0, 0, 0.12)`
- **Card Hover**: `0 12px 48px rgba(0, 0, 0, 0.2)`

### Animations

**Gradient Shift** (8s)
```css
@keyframes gradient-shift {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}
```

**Glow Pulse** (3s)
```css
@keyframes glow-pulse {
  0%, 100% { opacity: 0.5; transform: scale(1); }
  50% { opacity: 0.8; transform: scale(1.05); }
}
```

**Fade In** (0.3s)
```css
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}
```

**Slide Up** (0.3s)
```css
@keyframes slide-up {
  from { transform: translateY(10px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
```

### Timing Functions
- **Smooth**: `cubic-bezier(0.4, 0, 0.2, 1)`
- **Bounce Soft**: `cubic-bezier(0.34, 1.56, 0.64, 1)`

## Voice & Tone

### Brand Voice
- **Clear**: Simple, jargon-free language
- **Confident**: Assertive without being aggressive
- **Helpful**: Always focused on user benefit
- **Modern**: Tech-savvy but approachable

### Tone Guidelines

**Marketing/Landing Pages**
- Energetic and inspiring
- Focus on speed and productivity benefits
- Use action-oriented language
- Example: "Write 3x faster with Talkies"

**Documentation**
- Clear and instructional
- Technical but accessible
- Step-by-step guidance
- Example: "Press the hotkey to start recording"

**Error Messages**
- Helpful and solution-oriented
- No technical jargon unless necessary
- Provide clear next steps
- Example: "Unable to access microphone. Please check your system settings."

## Social Media

### Twitter/X Card
- **Image size**: 1200 × 630px
- **Format**: PNG or JPG
- **Style**: Dark background with logo and tagline
- **Text**: Large, readable at small sizes

### OG Image Guidelines
- Use primary gradient background
- Center logo prominently
- Include tagline: "Voice-Powered Writing Assistant"
- Maintain 40px padding on all sides

## Accessibility

### Contrast Ratios
- **AA Standard**: Minimum 4.5:1 for normal text
- **AAA Standard**: Minimum 7:1 for important text
- All primary colors meet AA standards on dark backgrounds

### Color Blindness
- Don't rely solely on color to convey information
- Use icons, labels, and patterns alongside color
- Test designs with color blindness simulators

### Reduced Motion
- Respect `prefers-reduced-motion` media query
- Provide static alternatives to animated elements
- Essential animations should be subtle

## Usage Examples

### Button Styles

**Primary CTA**
```css
background: linear-gradient(135deg, #a855f7, #ec4899);
color: #ffffff;
border-radius: 0.75rem;
padding: 0.75rem 1.5rem;
```

**Secondary Button**
```css
background: rgba(255, 255, 255, 0.05);
border: 1px solid rgba(255, 255, 255, 0.1);
color: #ffffff;
border-radius: 0.75rem;
padding: 0.75rem 1.5rem;
```

### Card Design
```css
background: rgba(255, 255, 255, 0.05);
border: 1px solid rgba(255, 255, 255, 0.1);
border-radius: 1.5rem;
backdrop-filter: blur(24px);
box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
```

## File Structure

All brand assets are centralized in the `/branding` directory for use across all platforms:

```
talkies/
├── BRAND_KIT.md                        # This file - complete brand guidelines
├── branding/                            # Centralized brand assets (single source of truth)
│   ├── README.md                       # Platform integration guide
│   ├── logos/                          # Logo variations
│   │   ├── talkies-logo.svg           # Primary logo (512×512)
│   │   ├── talkies-logo-light.svg     # For light backgrounds
│   │   ├── talkies-logo-monochrome-white.svg
│   │   └── talkies-logo-monochrome-black.svg
│   ├── icons/                          # App icons (multiple sizes)
│   │   ├── favicon.svg                # 32×32 favicon
│   │   ├── icon-16.svg
│   │   ├── icon-32.svg
│   │   ├── icon-64.svg
│   │   ├── icon-128.svg
│   │   └── icon-256.svg
│   ├── social/                         # Social media assets
│   │   └── og-image.svg               # Open Graph image (1200×630)
│   ├── colors/                         # Color palettes
│   │   ├── palette.json               # Universal definitions
│   │   ├── palette.css                # CSS custom properties (web)
│   │   ├── palette.swift              # Swift extensions (macOS)
│   │   └── palette.xaml               # XAML resources (Windows)
│   └── guidelines/                     # Reserved for additional guidelines
├── frontend/
│   └── public/                         # Frontend copies of assets
│       ├── talkies-logo.svg
│       ├── favicon.svg
│       └── og-image.svg
├── mac/                                # macOS app (use branding/ assets)
└── windows/                            # Windows app (use branding/ assets)
```

**Note:** The `/branding` directory is the **single source of truth** for all brand assets. Platform-specific directories (frontend/public/, mac/Resources/, windows/Resources/) should copy or reference assets from `/branding`.

## Updates & Maintenance

This brand kit is maintained by the Talkies team. For questions or suggestions:
- Open an issue on GitHub
- Contact the design team
- See `/branding/README.md` for platform integration guides

**Asset Location:** All brand assets are in `/branding` directory
**Platform Integration:** See `/branding/README.md` for macOS, Windows, and web integration

---

**Version**: 2.0.0
**Last Updated**: December 2025
**Maintained By**: Talkies Team
**Changelog:**
- v2.0.0 (2025-12-15): Added centralized `/branding` folder with platform-specific color palettes
- v1.0.0 (2025-12-15): Initial brand kit creation
