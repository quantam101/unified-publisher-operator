# Architecture Overview

## Design Philosophy

### Core Principles

1. **Offline-First**: No runtime network calls
2. **Privacy-Focused**: No telemetry, all data local
3. **Deterministic**: Rule-based, not opaque ML
4. **Single Program**: Unified shell, not separate apps

### Alignment with SOC Training Platform

Both platforms share:
- Zero network dependency
- Complete privacy
- Deterministic behavior
- One-command setup
- Idempotent scripts

---

## System Architecture

### High-Level Structure

```
┌─────────────────────────────────────┐
│   Unified Shell (Next.js App)       │
│                                     │
│  ┌─────────┬─────────┬───────────┐ │
│  │Publisher│Operator │ Changelog │ │
│  │         │         │           │ │
│  └─────────┴─────────┴───────────┘ │
│                                     │
│  ┌─────────────────────────────────┤
│  │ LCC Side-Panel                  │
│  │ (Always-on offline assistant)   │
│  └─────────────────────────────────┤
└─────────────────────────────────────┘
```

### Component Breakdown

#### 1. Unified Shell
- **Location**: `features/lcc/shell/UnifiedShell.tsx`
- **Role**: Top-level container with tab navigation
- **State**: Manages active view (publisher/operator/changelog)

#### 2. Publisher Surface
- **Location**: `features/publisher/ui/PublisherRoot.tsx`
- **Role**: Primary content creation/management surface
- **Extensibility**: Wire your Publisher UI here

#### 3. Operator Surface
- **Location**: `features/operator/ui/OperatorRoot.tsx`
- **Role**: Embedded operator assistance and workflows
- **Extensibility**: Wire your Operator flows here

#### 4. LCC Side-Panel
- **Location**: `features/lcc/ui/LccSidePanel.tsx`
- **Role**: Always-visible offline assistant
- **Engine**: Pattern-based responses (not LLM)

#### 5. LCC Engine
- **Location**: `features/lcc/local/lccEngine.ts`
- **Type**: Pure function: `(history, input) => response`
- **Rules**: Array of `{ match: RegExp, handler: () => string }`
- **Extensibility**: Add rules, no network calls

---

## Deployment Paths

### 1. Web (Next.js)
```
npm run dev → localhost:3000 → Browser
```

**Features**:
- Standard web access
- Hot reload in dev
- Static export for prod

### 2. PWA (Service Worker)
```
npm run dev → localhost:3000 → Install → Offline
```

**Features**:
- Installable (Add to Home Screen)
- Offline-capable
- Cache-first strategy
- Push notifications (optional)

**Service Worker Flow**:
1. **Install**: Cache core assets (/, manifest, icons, changelog)
2. **Activate**: Clean old caches, claim clients
3. **Fetch**: Cache-first for same-origin GET requests
4. **Offline**: Serve cached app shell for navigation

### 3. Desktop (Tauri)
```
cargo build → Native Binary → Desktop App
```

**Features**:
- Native window management
- File system access
- No browser chrome
- Auto-launch on open

**Tauri Flow**:
- **Dev**: Runs Next dev server, Tauri opens webview
- **Build**: Bundles `.next` export, creates installer
- **Runtime**: Rust backend, webview frontend

---

## Data Flow

### LCC Conversation
```
User Input (LccSidePanel)
    ↓
lccRespond(history, input)
    ↓
Pattern Matching (rules)
    ↓
Handler Execution
    ↓
Response (LccSidePanel)
```

**No network, no state persistence** (in-memory only).

### Changelog Loading
```
ChangelogViewer Mount
    ↓
fetch('/changelog.json')
    ↓
Parse JSON
    ↓
Render Items
```

**File-backed**, offline-ready.

---

## Extensibility Points

### Add LCC Pattern
```typescript
// features/lcc/local/lccEngine.ts
{
  match: /test|coverage|e2e/i,
  handler: () =>
    "Testing Checklist:\n" +
    "- Unit tests passing\n" +
    "- Integration tests passing\n" +
    "- E2E smoke test\n" +
    "- Coverage > 80%"
}
```

### Add Operator Flow
```typescript
// features/operator/ui/MyOperatorFlow.tsx
export function MyOperatorFlow() {
  return <section>Custom operator logic</section>;
}

// Wire into OperatorRoot.tsx
import { MyOperatorFlow } from "./MyOperatorFlow";
```

### Add Changelog Entry
```json
// public/changelog.json
{
  "ts": "2026-01-05",
  "title": "Added X feature",
  "detail": "Description..."
}
```

---

## Offline Guarantees

### Service Worker Strategy

**Core Assets** (cached on install):
- `/` (app shell)
- `/manifest.webmanifest`
- `/icon.svg`
- `/maskable-icon.svg`
- `/changelog.json`

**Fetch Strategy**:
1. Check cache first
2. If cached: return immediately
3. If not: fetch from network
4. On success: cache for next time
5. On failure (offline): serve cached shell (navigation only)

### LCC Engine

**Pure function**:
```typescript
export function lccRespond(
  history: LccMsg[],
  input: string
): LccMsg {
  // No async, no network, no state mutation
  for (const rule of rules) {
    if (rule.match.test(input)) {
      return { role: "assistant", content: rule.handler() };
    }
  }
  return { role: "assistant", content: "..." };
}
```

**Deterministic**: Same input → same output, every time.

---

## Build Process

### Script Flow

```bash
./tools/build_one_offline_program.sh [--tooling] [--zip]
```

**Steps**:
1. **Validate** - Check for `publisher/` and `operator-assistance/` dirs
2. **Copy Operator** - Embed operator sources into `features/operator/module/`
3. **Create Components** - Write all TSX/TS/CSS files
4. **Inject PWA** - Add manifest link + SW registration to layout
5. **Scaffold Tauri** - Create Rust app wrapper
6. **Optional: Tooling** - Add ESLint/Prettier/Husky
7. **Optional: Build** - Run `npm run build` and package ZIP

### Idempotency

**Safe to re-run**:
- `write_if_missing()` - Only creates files that don't exist
- `rsync --ignore-existing` - Non-destructive copy
- Patch scripts check before modifying

---

## Comparison: SOC vs Publisher/Operator

| Aspect | SOC Training | Publisher/Operator |
|--------|--------------|-------------------|
| **Purpose** | Operator development | Content + assistance |
| **Evaluation** | Non-scoring judgment | N/A |
| **Assistant** | None (human instructor) | LCC side-panel |
| **Content** | 4 Tier-3+ scenarios | User-defined |
| **Deployment** | Bash scripts | PWA + Tauri |
| **UI** | Terminal + MD memos | Next.js web app |
| **Shared** | Offline, privacy, deterministic | ✓ |

---

## Security Considerations

### No Network Calls
- LCC engine: Pure function, no `fetch`
- Service worker: Same-origin only
- Tauri: No network features enabled

### No Secrets
- No API keys
- No auth tokens
- No user tracking

### Local-Only Data
- LCC history: In-memory (lost on refresh)
- Changelog: Public static file
- User data: localStorage (optional, not implemented yet)

### Tauri Hardening
```json
{
  "security": {
    "csp": null  // Add CSP for production
  }
}
```

**Recommendation**: Add Content Security Policy for prod builds.

---

## Performance Characteristics

### LCC Engine
- **Latency**: <1ms (rule matching + string concatenation)
- **Memory**: O(n) where n = conversation length
- **CPU**: Negligible (regex matching)

### Service Worker
- **Install**: ~10-50ms (cache 5 files)
- **Fetch (cached)**: ~5-10ms
- **Fetch (network)**: ~50-500ms (then cached)

### Next.js Build
- **Dev**: ~3-5s first load, <1s hot reload
- **Build**: ~20-60s (depends on size)
- **Bundle**: ~200-500KB (with LCC engine)

### Tauri
- **Binary size**: ~10-20MB (depends on platform)
- **Launch time**: ~500ms-1s
- **Memory**: ~50-100MB (webview + Rust)

---

**Offline-first architecture. Zero network dependency. Complete control.**
