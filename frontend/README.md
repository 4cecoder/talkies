# Talkies Frontend

The project website for Talkies — a free, open-source, on-device voice transcription app. This
Next.js site is the homepage, a live in-browser transcription demo, and a platform-picker FAQ to
help visitors figure out which build (macOS / Windows / Linux / mobile) they want and how to get
it running. There's no billing, no checkout, and no pricing tiers here — the app is free.

## Features

### Design & UI/UX
- **Animated Gradient Backgrounds**: Floating orbs with smooth pulsing animations
- **Glassmorphism Effects**: Frosted glass panels with backdrop blur throughout
- **Premium Gradient Buttons**: Animated flowing gradients with hover glow effects
- **Responsive Design**: Mobile-first approach, fully responsive across all devices
- **Micro-interactions**: Smooth hover states, scale animations, and transitions

### Content
- **Platform Picker**: Direct links to GitHub Releases for macOS, Windows, Linux, and mobile,
  each labeled with its current readiness (ready / available / in progress)
- **Live Browser Demo**: A real transcription demo running client-side in the browser — no
  signup, no cloud, nothing uploaded
- **FAQ**: Onboarding-focused questions (which platform to pick, whether it's free, whether data
  ever leaves your device, how to build from source, where to file bugs/contribute, and license
  status)

### Sections
1. **Hero**: What the app does, plus the platform picker (macOS, Windows, Linux, mobile)
2. **Live Demo**: In-browser transcription demo
3. **Features**: 3-card grid with gradient hover effects
4. **Final CTA**: Link to the GitHub repo and back to the platform picker
5. **FAQ**: Accordion-style onboarding questions
6. **Footer**: Privacy/Terms/Contact/GitHub links

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Styling**: Tailwind CSS v4 with custom animations
- **Icons**: Lucide React (clean, consistent icon system)
- **Language**: TypeScript
- **Font**: Geist Sans & Geist Mono

## Getting Started

```bash
# Install dependencies
bun install

# Run development server
bun run dev

# Build static export (outputs to ./out)
bun run build
```

This app is built with `output: 'export'` and deployed as a static site (GitHub Pages), so there is no production server to start — preview the exported site by serving the `out/` directory with any static file server (e.g. `bunx serve out`).

Open [http://localhost:3000](http://localhost:3000) to view the site.

## Project Structure

```
frontend/
├── app/
│   ├── components/
│   │   ├── sections/             # Header, FAQ, Features, etc.
│   │   ├── demo/                 # Live in-browser transcription demo
│   │   └── AuthModal.tsx         # Login/signup modal used by the optional dashboard
│   ├── dashboard/
│   │   └── page.tsx              # Optional usage-stats dashboard (not required to use the app)
│   ├── legal/                    # Privacy & Terms pages
│   ├── globals.css               # Custom animations & styles
│   ├── layout.tsx                # Root layout
│   └── page.tsx                  # Homepage
└── package.json
```

## Custom Animations

- `gradient-shift`: 8s flowing background gradients
- `gradient-fast`: 4s rapid flowing gradients for buttons
- `glow-pulse`: 3s pulsing glow effects
- `gradient-border`: Animated border gradients

## Deploy on GitHub Pages

This app builds to a static export (`output: 'export'`) and deploys to GitHub Pages via `.github/workflows/deploy-pages.yml`, which runs on every push to `master` that touches `frontend/**` (or can be triggered manually). The workflow installs dependencies and builds with bun, then publishes the `frontend/out/` directory using the official `actions/upload-pages-artifact` / `actions/deploy-pages` actions.

Check out the [Next.js static export documentation](https://nextjs.org/docs/app/building-your-application/deploying/static-exports) for more details.
