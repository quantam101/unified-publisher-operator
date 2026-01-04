# Unified Publisher + Operator Platform

> **One offline program. Three deployment options. Zero network dependency.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 One-Command Build

```bash
git clone https://github.com/quantam101/unified-publisher-operator.git
cd unified-publisher-operator
chmod +x tools/build_one_offline_program.sh
./tools/build_one_offline_program.sh
```

**That's it.** Creates:
- ✅ Unified Publisher + Operator shell
- ✅ Offline LCC side-panel (pattern-based assistant)
- ✅ PWA (installable web app with service worker)
- ✅ Tauri scaffold (desktop wrapper)

---

## Philosophy

**Aligned with SOC Operator Training Platform principles**:
- ✅ **Offline-first** - No runtime network calls
- ✅ **Privacy-focused** - No telemetry, all data local
- ✅ **Deterministic** - Rule-based LCC engine, not opaque ML
- ✅ **One program** - Publisher + Operator unified, not separate apps

---

## Deployment Options

### 1. Web (Next.js)
```bash
cd publisher && npm i && npm run dev
# Visit http://localhost:3000
```

### 2. PWA (Installable)
```bash
cd publisher && npm i && npm run dev
# Visit http://localhost:3000
# Click "Install" in browser address bar
# Works offline after first load
```

### 3. Desktop (Tauri)
```bash
# One-time: Install Rust + Tauri CLI
cargo install tauri-cli

# Run desktop app
cd apps/tauri && npm run dev
```

---

## Build Options

### Scaffold Only
```bash
./tools/build_one_offline_program.sh
```

Creates all components but doesn't install dependencies or build.

### Scaffold + Tooling
```bash
./tools/build_one_offline_program.sh --tooling
```

Adds ESLint, Prettier, Husky, lint-staged with pre-commit hooks.

### Scaffold + Build + Package
```bash
./tools/build_one_offline_program.sh --zip
```

Builds and creates `dist/publisher_operator_offline.zip`.

### Everything
```bash
./tools/build_one_offline_program.sh --tooling --zip
```

---

## Architecture

### Unified Shell
Single Next.js app with tab navigation:
- **Publisher** - Main content surface
- **Operator** - Embedded operator assistance
- **Changelog** - File-backed changelog viewer

### LCC Side-Panel
Always-visible offline assistant:
- Pattern-based responses (not LLM)
- Extensible rule system
- Local-only computation

### Components
```
publisher/
├── src/
│   ├── app/
│   │   ├── layout.tsx          # PWA integration
│   │   ├── page.tsx            # Unified shell entry
│   │   └── globals.css
│   └── features/
│       ├── publisher/ui/       # Publisher surface
│       ├── operator/ui/        # Operator surface
│       └── lcc/
│           ├── shell/          # Unified shell
│           ├── local/          # LCC engine
│           ├── ui/             # LCC side-panel
│           └── pwa/            # SW registration
└── public/
    ├── manifest.webmanifest
    ├── icon.svg
    ├── maskable-icon.svg
    ├── sw.js                   # Service worker
    └── changelog.json          # File-backed changelog

apps/tauri/                     # Desktop wrapper
├── package.json
└── src-tauri/
    ├── tauri.conf.json
    ├── Cargo.toml
    ├── build.rs
    └── src/main.rs
```

---

## LCC Engine

**Pattern-based offline assistant** in `features/lcc/local/lccEngine.ts`:

```typescript
const rules: Rule[] = [
  { match: /bug|error|fail/i, handler: debuggingFlow },
  { match: /checklist/i, handler: releaseChecklist },
  { match: /optimize|performance/i, handler: performanceReview },
  { match: /security|audit/i, handler: securityAudit }
];
```

**Extend** by adding rules:
```typescript
{
  match: /accessibility|a11y/i,
  handler: () => "Accessibility Checklist:\n- Semantic HTML\n- ARIA labels\n- Keyboard navigation\n- Color contrast\n- Screen reader testing"
}
```

---

## PWA Features

- ✅ **Installable** - Add to home screen
- ✅ **Offline** - Service worker caches all assets
- ✅ **Real icons** - SVG with maskable variant
- ✅ **Auto-registration** - Client component in layout
- ✅ **Cache-first** - Fast offline access

**Service Worker Strategy**:
1. Install: Cache core assets
2. Fetch: Cache-first for static, network fallback
3. Offline: Serve cached app shell

---

## Tauri Desktop

**Minimal Rust wrapper** for Publisher Next.js app:

```toml
[dependencies]
tauri = { version = "2", features = [] }
```

**Auto-launch**: Opens main window on app start (no splash, no manual trigger).

**Dev**: Points to localhost:3000 (Next dev server)  
**Build**: Uses `.next` static export

---

## Tooling (Optional)

Run with `--tooling` flag to add:
- **ESLint** - Next.js config
- **Prettier** - Format on save
- **Husky** - Git hooks
- **lint-staged** - Pre-commit formatting

**Auto-configured**:
- `npm run lint` - ESLint check
- `npm run format` - Prettier write
- `npm run format:check` - Prettier verify
- Pre-commit hook runs lint-staged

---

## Verification

### Check Structure
```bash
ls -la publisher/src/features/
# Should show: publisher/ operator/ lcc/

ls -la publisher/public/
# Should show: manifest.webmanifest icon.svg sw.js changelog.json

ls -la apps/tauri/src-tauri/
# Should show: Cargo.toml tauri.conf.json src/main.rs
```

### Test PWA
```bash
cd publisher && npm run dev
# Visit http://localhost:3000
# Open DevTools > Application > Service Workers
# Should show sw.js registered
```

### Test Tauri
```bash
cd apps/tauri && npm run dev
# Desktop app should open automatically
```

---

## Privacy & Offline Guarantees

- ✅ **No network calls** during execution
- ✅ **No telemetry** or analytics
- ✅ **No API keys** required
- ✅ **All data local** (localStorage + file system)
- ✅ **Service worker** caches everything
- ✅ **Deterministic** LCC engine (rules, not ML)

---

## Extending the Platform

### Add New Operator Flow
1. Create component in `features/operator/ui/`
2. Wire into `OperatorRoot.tsx`
3. Add navigation if needed

### Add LCC Pattern
```typescript
// In features/lcc/local/lccEngine.ts
{
  match: /deploy|release|ship/i,
  handler: () =>
    "Deployment Checklist:\n" +
    "- Version bump\n" +
    "- Changelog updated\n" +
    "- Tests passing\n" +
    "- Build verified\n" +
    "- Smoke test complete\n" +
    "- Tag created\n" +
    "- Artifacts uploaded"
}
```

### Add Changelog Entry
```json
// In public/changelog.json
{
  "ts": "2026-01-05",
  "title": "New feature added",
  "detail": "Description of what changed"
}
```

---

## Companion Project

This platform complements the **[SOC Operator Training Platform](https://github.com/quantam101/soc-operator-training-platform)**:

| Platform | Purpose | Philosophy |
|----------|---------|-----------|
| **SOC Training** | Non-scoring operator development | Judgment under ambiguity |
| **Publisher/Operator** | Content + decision support | Offline-first assistance |

**Both**:
- Offline-first
- Privacy-focused
- Deterministic
- No telemetry
- One-command setup

---

## Contributing

Contributions welcome! Focus areas:
- New LCC patterns
- Operator workflow templates
- Publisher features
- Documentation improvements

---

## License

MIT License

---

**Zero network dependency. Complete privacy. Single offline program.**
