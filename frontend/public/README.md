# Talkies Brand Assets

This directory contains the official Talkies brand assets.

## Files

### Logos

- **talkies-logo.svg** - Primary logo (512×512px) for website headers, app icons, marketing
- **favicon.svg** - Favicon (32×32px) optimized for browser tabs and bookmarks

### Social Media

- **og-image.svg** - Open Graph image (1200×630px) for social media sharing (Twitter, Facebook, LinkedIn)

## Usage Guidelines

See the complete brand kit documentation at `/BRAND_KIT.md` for:

- Color palette and gradients
- Typography guidelines
- Logo usage rules
- Design tokens
- Animation specifications
- Voice and tone guidelines

## Quick Reference

### Brand Colors

- **Purple**: `#a855f7` (Primary)
- **Pink**: `#ec4899` (Secondary)
- **Background**: `#0a0a0f` (Dark)

### Logo Clear Space

Maintain 20% of logo width as clear space on all sides.

### Minimum Size

- Full logo: 32px × 32px minimum
- Favicon: 32px × 32px (optimized)

## Integration

### Next.js Metadata

The logo and OG image are automatically included in the site metadata via `app/layout.tsx`:

- Favicon appears in browser tabs
- OG image appears when sharing on social media
- Twitter cards display the OG image

### Header Component

The logo is displayed in the site header at `app/components/sections/Header.tsx`

---

For questions or updates, see `/BRAND_KIT.md` or open an issue.
