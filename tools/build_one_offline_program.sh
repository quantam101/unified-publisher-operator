#!/usr/bin/env bash
set -euo pipefail

# tools/build_one_offline_program.sh
# One script that:
# 1) Unifies Operator into Publisher (single program shell)
# 2) Adds offline-only LCC side-panel + file-backed changelog
# 3) Scaffolds PWA (manifest + icons + service worker + registration)
# 4) Scaffolds Tauri wrapper (desktop auto-launch on open)
# 5) Optionally sets up tooling (eslint/prettier/husky/lint-staged)
# 6) Optionally builds + packages ZIP

ROOT="$(pwd)"
PUBLISHER="$ROOT/publisher"
OPERATOR="$ROOT/operator-assistance"

APP_DIR="$PUBLISHER/src/app"
PUBLIC_DIR="$PUBLISHER/public"
FEATURES_DIR="$PUBLISHER/src/features"

PUBLISHER_FEAT="$FEATURES_DIR/publisher"
OPERATOR_FEAT="$FEATURES_DIR/operator"
LCC_FEAT="$FEATURES_DIR/lcc"

DO_TOOLING=0
DO_ZIP=0

for arg in "$@"; do
  case "$arg" in
    --tooling) DO_TOOLING=1 ;;
    --zip) DO_ZIP=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
need_dir() { [[ -d "$1" ]] || die "Missing directory: $1"; }
ensure_dir() { mkdir -p "$1"; }

write_file() {
  local path="$1"
  local content="$2"
  ensure_dir "$(dirname "$path")"
  printf "%s" "$content" > "$path"
}

write_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    write_file "$path" "$content"
  fi
}

copy_operator_sources() {
  if [[ -d "$OPERATOR/src" ]]; then
    ensure_dir "$OPERATOR_FEAT/module"
    rsync -a --ignore-existing "$OPERATOR/src/" "$OPERATOR_FEAT/module/"
  fi
}

patch_layout_for_pwa() {
  local layout="$APP_DIR/layout.tsx"
  [[ -f "$layout" ]] || die "Missing $layout (run unify step first)."

  if ! grep -q 'RegisterServiceWorker' "$layout"; then
    perl -0777 -i -pe 's/(import type \{ ReactNode \} from "react";)/$1\nimport { RegisterServiceWorker } from "@\/features\/lcc\/pwa\/RegisterServiceWorker";/s' "$layout"
  fi

  if ! grep -q 'manifest.webmanifest' "$layout"; then
    perl -0777 -i -pe 's/<html lang="en">\s*<body>/<html lang="en">\n      <head>\n        <link rel="manifest" href="\/manifest.webmanifest" \/>\n        <meta name="theme-color" content="#0b0b0c" \/>\n        <meta name="apple-mobile-web-app-capable" content="yes" \/>\n        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" \/>\n      <\/head>\n      <body>/s' "$layout"
  fi

  if ! grep -q '<RegisterServiceWorker' "$layout"; then
    perl -0777 -i -pe 's/<body>\s*/<body>\n        <RegisterServiceWorker \/>\n/s' "$layout"
  fi
}

setup_tooling() {
  need_dir "$PUBLISHER"
  [[ -f "$PUBLISHER/package.json" ]] || die "Missing publisher/package.json"
  (cd "$PUBLISHER" && npm i -D eslint prettier husky lint-staged)

  node - <<'NODE'
const fs = require("fs");
const p = "publisher/package.json";
const pkg = JSON.parse(fs.readFileSync(p, "utf8"));

pkg.scripts ||= {};
pkg.scripts.lint ||= "next lint";
pkg.scripts.format ||= "prettier --write .";
pkg.scripts["format:check"] ||= "prettier --check .";
pkg.scripts.prepare ||= "husky";

pkg["lint-staged"] ||= {
  "*.{js,jsx,ts,tsx,json,md,css}": ["prettier --write"],
  "*.{js,jsx,ts,tsx}": ["eslint --fix"]
};

fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
console.log("Tooling scripts set.");
NODE

  (cd "$PUBLISHER" && npx husky init >/dev/null 2>&1 || true)
  ensure_dir "$PUBLISHER/.husky"
  write_file "$PUBLISHER/.husky/pre-commit" \
'#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
npx lint-staged
'
  chmod +x "$PUBLISHER/.husky/pre-commit"

  write_if_missing "$PUBLISHER/.prettierrc" \
'{
  "semi": true,
  "printWidth": 100
}
'
}

package_zip() {
  need_dir "$PUBLISHER"
  ensure_dir "$ROOT/dist"

  (cd "$PUBLISHER" && npm install && npm run build)

  local ZIP="$ROOT/dist/publisher_operator_offline.zip"
  rm -f "$ZIP"

  (cd "$ROOT" && zip -r "$ZIP" \
    publisher operator-assistance apps tools README.md 2>/dev/null \
    -x "**/node_modules/*" "**/.next/cache/*" "**/.git/*" || true)

  echo "Packaged: $ZIP"
}

main() {
  need_dir "$PUBLISHER"
  need_dir "$OPERATOR"
  need_dir "$PUBLISHER/src"

  ensure_dir "$FEATURES_DIR"
  ensure_dir "$APP_DIR"
  ensure_dir "$PUBLIC_DIR"
  ensure_dir "$PUBLISHER_FEAT/ui"
  ensure_dir "$OPERATOR_FEAT/ui"
  ensure_dir "$LCC_FEAT/ui"
  ensure_dir "$LCC_FEAT/shell"
  ensure_dir "$LCC_FEAT/local"
  ensure_dir "$LCC_FEAT/pwa"

  copy_operator_sources

  write_if_missing "$APP_DIR/layout.tsx" \
'import "./globals.css";
import type { ReactNode } from "react";

export const metadata = {
  title: "Publisher • Lifelong Catch & Correct",
  description: "Single offline program: Publisher + Operator + LCC",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
'

  write_file "$APP_DIR/page.tsx" \
'import { UnifiedShell } from "@/features/lcc/shell/UnifiedShell";

export default function Home() {
  return <UnifiedShell />;
}
'

  write_if_missing "$APP_DIR/globals.css" \
':root { color-scheme: dark; }
html, body { height: 100%; }
body {
  margin: 0;
  background: #0b0b0c;
  color: #f2f2f2;
  font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
}
button {
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid rgba(255,255,255,0.12);
  background: rgba(255,255,255,0.06);
  color: inherit;
  cursor: pointer;
}
button[aria-pressed="true"] { background: rgba(255,255,255,0.14); }
input, textarea {
  padding: 10px;
  border-radius: 10px;
  border: 1px solid rgba(255,255,255,0.12);
  background: rgba(255,255,255,0.04);
  color: inherit;
}
'

  write_if_missing "$LCC_FEAT/shell/UnifiedShell.tsx" \
'"use client";

import { useMemo, useState } from "react";
import { PublisherRoot } from "@/features/publisher/ui/PublisherRoot";
import { OperatorRoot } from "@/features/operator/ui/OperatorRoot";
import { LccSidePanel } from "@/features/lcc/ui/LccSidePanel";
import { ChangelogViewer } from "@/features/lcc/ui/ChangelogViewer";

type Tab = "publisher" | "operator" | "changelog";

export function UnifiedShell() {
  const [tab, setTab] = useState<Tab>("publisher");

  const title = useMemo(() => {
    if (tab === "publisher") return "Publisher • Lifelong Catch & Correct";
    if (tab === "operator") return "Operator Assistance Design";
    return "Codex Changelog Viewer";
  }, [tab]);

  return (
    <div style={{ display: "flex", height: "100dvh", width: "100%", overflow: "hidden" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
        <header
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            padding: "12px 14px",
            borderBottom: "1px solid rgba(255,255,255,0.08)",
          }}
        >
          <div style={{ fontSize: 14, fontWeight: 900 }}>{title}</div>
          <nav style={{ display: "flex", gap: 8 }}>
            <button onClick={() => setTab("publisher")} aria-pressed={tab === "publisher"}>Publisher</button>
            <button onClick={() => setTab("operator")} aria-pressed={tab === "operator"}>Operator</button>
            <button onClick={() => setTab("changelog")} aria-pressed={tab === "changelog"}>Changelog</button>
          </nav>
        </header>

        <main style={{ flex: 1, minHeight: 0, overflow: "auto" }}>
          {tab === "publisher" && <PublisherRoot />}
          {tab === "operator" && <OperatorRoot />}
          {tab === "changelog" && <ChangelogViewer />}
        </main>
      </div>

      <aside
        style={{
          width: 380,
          maxWidth: "38vw",
          borderLeft: "1px solid rgba(255,255,255,0.08)",
          height: "100%",
          overflow: "hidden",
        }}
      >
        <LccSidePanel />
      </aside>
    </div>
  );
}
'

  write_if_missing "$PUBLISHER_FEAT/ui/PublisherRoot.tsx" \
'"use client";

export function PublisherRoot() {
  return (
    <section style={{ padding: 16 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Publisher</h2>
      <p style={{ opacity: 0.8, marginTop: 8 }}>
        Unified program primary surface. Replace this component with your real Publisher UI.
      </p>
    </section>
  );
}
'

  write_if_missing "$OPERATOR_FEAT/ui/OperatorRoot.tsx" \
'"use client";

export function OperatorRoot() {
  return (
    <section style={{ padding: 16 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Operator Assistance</h2>
      <p style={{ opacity: 0.8, marginTop: 8 }}>
        Embedded Operator module surface. Replace this component with your real Operator UI.
      </p>
    </section>
  );
}
'

  write_if_missing "$LCC_FEAT/local/lccEngine.ts" \
'export type LccMsg = { role: "user" | "assistant"; content: string };

type Rule = { match: RegExp; handler: () => string };

const rules: Rule[] = [
  { match: /bug|error|fail/i, handler: () =>
    "Debug Flow:\n1) Reproduce\n2) Isolate minimal failing case\n3) Root cause\n4) Patch\n5) Regression test\n6) Lint/format/build\n\nPaste the exact error text + snippet." },
  { match: /checklist/i, handler: () =>
    "Offline Release Checklist:\n- Lint clean\n- Format clean\n- Build passes\n- No placeholders\n- Local persistence verified\n- Mobile viewport verified\n- ZIP + app bundle built\n- Smoke test complete" },
  { match: /optimize|performance/i, handler: () =>
    "Performance Review:\n- Bundle size\n- Render hot paths\n- State churn\n- Idle CPU cost\n- Memory growth\n- Storage I/O" },
  { match: /security|audit/i, handler: () =>
    "Offline Security Audit:\n- No network calls\n- No embedded secrets\n- Deterministic rules\n- Local-only persistence\n- Dependency review\n- CSP/app hardening (Tauri: restrict allowlist)" }
];

export function lccRespond(history: LccMsg[], input: string): LccMsg {
  const text = String(input || "").trim();
  for (const r of rules) {
    if (r.match.test(text)) return { role: "assistant", content: r.handler() };
  }
  return {
    role: "assistant",
    content:
      "Lifelong Catch & Correct (offline) is active.\n" +
      "Try: checklist | paste an error | '\''security audit'\'' | '\''optimize'\''"
  };
}
'

  write_if_missing "$LCC_FEAT/ui/LccSidePanel.tsx" \
'"use client";

import { useMemo, useRef, useState } from "react";
import type { LccMsg } from "@/features/lcc/local/lccEngine";
import { lccRespond } from "@/features/lcc/local/lccEngine";

export function LccSidePanel() {
  const [messages, setMessages] = useState<LccMsg[]>([
    { role: "assistant", content: "Lifelong Catch & Correct (offline) is active." }
  ]);
  const [input, setInput] = useState("");
  const listRef = useRef<HTMLDivElement | null>(null);

  const canSend = useMemo(() => input.trim().length > 0, [input]);

  function send() {
    const text = input.trim();
    if (!text) return;
    setInput("");
    setMessages((m) => {
      const next = [...m, { role: "user", content: text }];
      const reply = lccRespond(next, text);
      return [...next, reply];
    });
    queueMicrotask(() => listRef.current?.scrollTo({ top: 1e9, behavior: "smooth" }));
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 12, borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
        <div style={{ fontSize: 13, fontWeight: 900 }}>Lifelong Catch & Correct</div>
        <div style={{ fontSize: 12, opacity: 0.7 }}>Offline side-panel</div>
      </div>

      <div ref={listRef} style={{ flex: 1, padding: 12, overflow: "auto", display: "grid", gap: 10 }}>
        {messages.map((m, i) => (
          <div
            key={i}
            style={{
              justifySelf: m.role === "user" ? "end" : "start",
              maxWidth: "90%",
              padding: 10,
              borderRadius: 14,
              border: "1px solid rgba(255,255,255,0.12)",
              background: m.role === "user" ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.04)",
              whiteSpace: "pre-wrap",
              fontSize: 12,
              lineHeight: 1.4
            }}
          >
            {m.content}
          </div>
        ))}
      </div>

      <form
        onSubmit={(e) => { e.preventDefault(); send(); }}
        style={{ display: "flex", gap: 8, padding: 12, borderTop: "1px solid rgba(255,255,255,0.08)" }}
      >
        <input value={input} onChange={(e) => setInput(e.target.value)} placeholder="Type…" style={{ flex: 1 }} />
        <button type="submit" disabled={!canSend}>Send</button>
      </form>
    </div>
  );
}
'

  write_if_missing "$PUBLIC_DIR/changelog.json" \
'[
  {
    "ts": "2026-01-04",
    "title": "Unified offline program created",
    "detail": "Operator embedded into Publisher; LCC side-panel always-on; PWA + Tauri scaffolded."
  }
]
'

  write_if_missing "$LCC_FEAT/ui/ChangelogViewer.tsx" \
'"use client";

import { useEffect, useState } from "react";

type Item = { ts: string; title: string; detail?: string };

export function ChangelogViewer() {
  const [items, setItems] = useState<Item[]>([]);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    fetch("/changelog.json")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("Missing changelog.json"))))
      .then((d) => setItems(Array.isArray(d) ? d : []))
      .catch((e) => setErr(String(e?.message || e)));
  }, []);

  return (
    <section style={{ padding: 16 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Codex Changelog Viewer</h2>
      {err ? <div style={{ marginTop: 10, opacity: 0.75, fontSize: 12 }}>Error: {err}</div> : null}
      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>
        {items.map((x) => (
          <div key={x.ts + x.title} style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 12 }}>
            <div style={{ fontSize: 12, opacity: 0.7 }}>{x.ts}</div>
            <div style={{ fontSize: 13, fontWeight: 900, marginTop: 4 }}>{x.title}</div>
            {x.detail ? <div style={{ fontSize: 12, opacity: 0.85, marginTop: 6 }}>{x.detail}</div> : null}
          </div>
        ))}
      </div>
    </section>
  );
}
'

  write_file "$PUBLIC_DIR/manifest.webmanifest" \
'{
  "name": "Publisher • Lifelong Catch & Correct",
  "short_name": "Publisher",
  "description": "Single offline program: Publisher + Operator + Lifelong Catch & Correct",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#0b0b0c",
  "theme_color": "#0b0b0c",
  "icons": [
    { "src": "/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any" },
    { "src": "/maskable-icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "maskable" }
  ]
}
'

  write_file "$PUBLIC_DIR/icon.svg" \
'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="96" fill="#0b0b0c"/>
  <path d="M148 352V160h140c52 0 88 30 88 78 0 49-36 79-88 79H222v35h-74zm74-91h64c22 0 34-11 34-23s-12-22-34-22h-64v45z"
        fill="#f2f2f2"/>
</svg>
'

  write_file "$PUBLIC_DIR/maskable-icon.svg" \
'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#0b0b0c"/>
  <circle cx="256" cy="256" r="220" fill="#0b0b0c" stroke="#f2f2f2" stroke-width="18"/>
  <path d="M170 350V162h132c50 0 84 29 84 75 0 47-34 76-84 76h-61v37h-71zm71-91h56c20 0 31-10 31-22 0-11-11-21-31-21h-56v43z"
        fill="#f2f2f2"/>
</svg>
'

  write_file "$PUBLIC_DIR/sw.js" \
'const CACHE = "publisher-offline-v1";
const CORE = ["/", "/manifest.webmanifest", "/icon.svg", "/maskable-icon.svg", "/changelog.json"];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(CORE);
    self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => (k === CACHE ? null : caches.delete(k))));
    self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(req);
    if (cached) return cached;

    try {
      const fresh = await fetch(req);
      if (fresh && fresh.status === 200 && (fresh.type === "basic" || fresh.type === "cors")) {
        cache.put(req, fresh.clone()).catch(() => {});
      }
      return fresh;
    } catch {
      if (req.mode === "navigate") {
        const shell = await cache.match("/");
        if (shell) return shell;
      }
      throw new Error("Offline and not cached");
    }
  })());
});
'

  write_if_missing "$LCC_FEAT/pwa/RegisterServiceWorker.tsx" \
'"use client";

import { useEffect } from "react";

export function RegisterServiceWorker() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    const register = async () => {
      try {
        await navigator.serviceWorker.register("/sw.js", { scope: "/" });
      } catch {}
    };
    register();
  }, []);
  return null;
}
'

  TAURI_DIR="$ROOT/apps/tauri"
  SRC_TAURI="$TAURI_DIR/src-tauri"
  ensure_dir "$SRC_TAURI/src"

  write_if_missing "$TAURI_DIR/package.json" \
'{
  "name": "publisher-tauri",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "tauri dev",
    "build": "tauri build"
  }
}
'

  write_if_missing "$SRC_TAURI/tauri.conf.json" \
'{
  "productName": "Publisher • Lifelong Catch & Correct",
  "version": "0.1.0",
  "identifier": "com.publisher.lcc",
  "build": {
    "beforeDevCommand": "cd ../../publisher && npm run dev -- --port 3000",
    "devUrl": "http://localhost:3000",
    "beforeBuildCommand": "cd ../../publisher && npm run build",
    "frontendDist": "../../publisher/.next"
  },
  "app": {
    "windows": [
      {
        "title": "Publisher • Lifelong Catch & Correct",
        "width": 1280,
        "height": 800,
        "resizable": true,
        "fullscreen": false
      }
    ],
    "security": {
      "csp": null
    }
  }
}
'

  write_if_missing "$SRC_TAURI/Cargo.toml" \
'[package]
name = "publisher_lcc"
version = "0.1.0"
edition = "2021"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }

[features]
default = []
'

  write_if_missing "$SRC_TAURI/src/main.rs" \
'#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
  tauri::Builder::default()
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
'

  write_if_missing "$SRC_TAURI/build.rs" \
'fn main() {
  tauri_build::build()
}
'

  write_if_missing "$TAURI_DIR/README.md" \
'# Publisher • Lifelong Catch & Correct (Tauri)

## Dev
- Install Tauri CLI: `cargo install tauri-cli`
- Run: `cd apps/tauri && npm run dev`

## Build
- `cd apps/tauri && npm run build`
'

  patch_layout_for_pwa

  if [[ "$DO_TOOLING" == "1" ]]; then
    echo "Setting up tooling..."
    setup_tooling
  fi

  if [[ "$DO_ZIP" == "1" ]]; then
    echo "Building and packaging..."
    package_zip
  fi

  echo ""
  echo "====================================="
  echo " Unified Offline Program: COMPLETE"
  echo "====================================="
  echo ""
  echo "Structure:"
  echo "  Publisher + Operator unified"
  echo "  LCC side-panel (offline engine)"
  echo "  PWA scaffolded (manifest + icons + SW)"
  echo "  Tauri scaffolded (desktop wrapper)"
  echo ""
  echo "Next steps:"
  echo "  cd publisher && npm i && npm run dev"
  echo "  # Visit http://localhost:3000"
  echo "  # Install PWA from browser"
  echo ""
  echo "Desktop app:"
  echo "  cargo install tauri-cli"
  echo "  cd apps/tauri && npm run dev"
}

main "$@"
