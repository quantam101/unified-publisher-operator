# Quick Start Guide

## ✨ One-Command Setup

```bash
git clone https://github.com/quantam101/unified-publisher-operator.git
cd unified-publisher-operator

# Make script executable
chmod +x tools/build_one_offline_program.sh

# Run it
./tools/build_one_offline_program.sh
```

**Done.** The script creates:
- ✅ Unified Publisher + Operator shell
- ✅ LCC offline assistant side-panel
- ✅ PWA (manifest, icons, service worker)
- ✅ Tauri desktop wrapper

---

## Prerequisites

### Required
- Bash shell
- `publisher/` directory with Next.js app
- `operator-assistance/` directory (optional but supported)

### For Development
- Node.js + npm
- Standard Unix tools (grep, sed, perl, rsync)

### For Tauri Desktop
- Rust toolchain: https://rustup.rs/
- Tauri CLI: `cargo install tauri-cli`

---

## Build Options

### 1. Scaffold Only (Default)
```bash
./tools/build_one_offline_program.sh
```

Creates all files but doesn't install dependencies.

**Output**:
- `publisher/src/features/` - All UI components
- `publisher/public/` - PWA assets
- `apps/tauri/` - Desktop wrapper

### 2. Scaffold + Tooling
```bash
./tools/build_one_offline_program.sh --tooling
```

Adds development tooling:
- ESLint (Next.js config)
- Prettier (format on save)
- Husky (Git hooks)
- lint-staged (pre-commit)

**Auto-configured scripts**:
- `npm run lint`
- `npm run format`
- `npm run format:check`

### 3. Scaffold + Build + Package
```bash
./tools/build_one_offline_program.sh --zip
```

Builds everything and creates `dist/publisher_operator_offline.zip`.

**Includes**:
- npm install
- npm run build
- ZIP packaging

### 4. Everything
```bash
./tools/build_one_offline_program.sh --tooling --zip
```

Full setup: scaffold + tooling + build + package.

---

## Running the App

### Web (Development)
```bash
cd publisher
npm install
npm run dev
```

Visit: http://localhost:3000

### PWA (Installable)
```bash
cd publisher
npm install
npm run dev
```

1. Visit http://localhost:3000
2. Click "Install" in browser address bar
3. App now works offline

**Verify**: 
- Open DevTools → Application → Service Workers
- Should show `sw.js` registered

### Desktop (Tauri)
```bash
# One-time setup
cargo install tauri-cli

# Run desktop app
cd apps/tauri
npm run dev
```

Desktop window opens automatically.

---

## What Gets Created

### Unified Shell
```
publisher/src/
├── app/
│   ├── layout.tsx          # PWA integration
│   ├── page.tsx            # Shell entry
│   └── globals.css
└── features/
    ├── publisher/ui/       # Publisher surface
    ├── operator/ui/        # Operator surface
    └── lcc/
        ├── shell/          # Unified shell
        ├── local/          # LCC engine
        ├── ui/             # Side-panel
        └── pwa/            # SW registration
```

### PWA Assets
```
publisher/public/
├── manifest.webmanifest    # PWA manifest
├── icon.svg                # App icon
├── maskable-icon.svg       # Maskable icon
├── sw.js                   # Service worker
└── changelog.json          # File-backed changelog
```

### Tauri Wrapper
```
apps/tauri/
├── package.json
└── src-tauri/
    ├── tauri.conf.json     # Config
    ├── Cargo.toml          # Rust deps
    ├── build.rs            # Build script
    └── src/main.rs         # Entry point
```

---

## Customization

### Switch Scenarios
Edit components directly:
- Publisher: `features/publisher/ui/PublisherRoot.tsx`
- Operator: `features/operator/ui/OperatorRoot.tsx`
- LCC: `features/lcc/local/lccEngine.ts`

### Add LCC Pattern
```typescript
// In features/lcc/local/lccEngine.ts
{
  match: /deploy|ship/i,
  handler: () =>
    "Deployment Checklist:
" +
    "- Version bump
" +
    "- Tests passing
" +
    "- Build verified
" +
    "- Tag created"
}
```

### Add Changelog Entry
```json
// In public/changelog.json
{
  "ts": "2026-01-05",
  "title": "New feature",
  "detail": "Description..."
}
```

---

## Verification

### Check Structure
```bash
ls -la publisher/src/features/
# Expected: publisher/ operator/ lcc/

ls -la publisher/public/
# Expected: manifest.webmanifest icon.svg sw.js

ls -la apps/tauri/src-tauri/
# Expected: Cargo.toml tauri.conf.json src/
```

### Test Components
```bash
# Start dev server
cd publisher && npm run dev

# Open browser to http://localhost:3000

# Test tabs: Publisher | Operator | Changelog
# Test LCC side-panel: type "checklist"
```

### Test PWA
```bash
# DevTools → Application → Service Workers
# Should show: sw.js (activated and running)

# DevTools → Application → Manifest
# Should show: Publisher • Lifelong Catch & Correct
```

### Test Tauri
```bash
cd apps/tauri && npm run dev
# Desktop window should open automatically
```

---

## Troubleshooting

### Script not executable
```bash
chmod +x tools/build_one_offline_program.sh
```

### Missing directories
```bash
mkdir -p publisher operator-assistance
```

### npm command not found
Install Node.js: https://nodejs.org/

### cargo command not found
Install Rust: https://rustup.rs/

### Service worker not registering
- Check browser console for errors
- Ensure running on localhost or HTTPS
- Clear cache and hard reload

### Tauri build fails
```bash
# Install Tauri prerequisites
# macOS: xcode-select --install
# Windows: Microsoft C++ Build Tools
# Linux: sudo apt install libwebkit2gtk-4.0-dev build-essential
```

---

## Next Steps

### 1. Customize UI
Replace placeholder components with your real Publisher and Operator UIs.

### 2. Extend LCC Engine
Add more patterns to `features/lcc/local/lccEngine.ts`.

### 3. Build Desktop App
```bash
cd apps/tauri && npm run build
# Installers in: src-tauri/target/release/bundle/
```

### 4. Deploy PWA
```bash
cd publisher
npm run build
# Deploy .next/ to static hosting
```

---

## Philosophy

This platform follows **offline-first principles**:

- ✅ **No network calls** during runtime
- ✅ **No telemetry** or analytics
- ✅ **Deterministic** LCC engine (rules, not ML)
- ✅ **Privacy-focused** - all data stays local
- ✅ **Idempotent** - safe to re-run script

**Complements**: [SOC Operator Training Platform](https://github.com/quantam101/soc-operator-training-platform)

---

## Resources

- **README**: https://github.com/quantam101/unified-publisher-operator/blob/main/README.md
- **Architecture**: https://github.com/quantam101/unified-publisher-operator/blob/main/ARCHITECTURE.md
- **Build Script**: https://github.com/quantam101/unified-publisher-operator/blob/main/tools/build_one_offline_program.sh

---

**Zero network dependency. Complete privacy. Single offline program.**
