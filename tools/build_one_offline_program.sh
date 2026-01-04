#!/usr/bin/env bash
set -euo pipefail

# tools/build_one_offline_program.sh
# One script that:
# 1) Unifies Operator into Publisher (single program shell)
# 2) Adds offline-only LCC side-panel + file-backed changelog
# 3) Scaffolds PWA (manifest + icons + service worker + registration)
# 4) Scaffolds Tauri wrapper (desktop auto-launch + OS-login autostart)
# 5) Adds IndexedDB (via idb) + Workflow DSL + Client-side PDF export
# 6) Optionally sets up tooling (eslint/prettier/husky/lint-staged)
# 7) Optionally builds + packages ZIP

ROOT="$(pwd)"
PUBLISHER="$ROOT/publisher"
OPERATOR="$ROOT/operator-assistance"
DIST="$ROOT/dist"

APP="$PUBLISHER/src/app"
FEATURES="$PUBLISHER/src/features"
PUBLIC="$PUBLISHER/public"

PUB_FEAT="$FEATURES/publisher"
OP_FEAT="$FEATURES/operator"
LCC_FEAT="$FEATURES/lcc"

PWA_FEAT="$LCC_FEAT/pwa"
LOCAL_FEAT="$LCC_FEAT/local"

APPS_DIR="$ROOT/apps"
TAURI_DIR="$APPS_DIR/tauri"
SRC_TAURI="$TAURI_DIR/src-tauri"

DO_TOOLING=0
DO_ZIP=0
DO_DEPS=0

for arg in "$@"; do
  case "$arg" in
    --tooling) DO_TOOLING=1 ;;
    --zip) DO_ZIP=1 ;;
    --deps) DO_DEPS=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

fail(){ echo "ERROR: $*" >&2; exit 1; }
need(){ [[ -d "$1" ]] || fail "Missing directory: $1"; }
mkdirs(){ mkdir -p "$@"; }

need "$PUBLISHER"
need "$PUBLISHER/src"
need "$OPERATOR"

mkdirs \
  "$APP" "$PUBLIC" "$FEATURES" "$DIST" \
  "$PUB_FEAT/ui" "$OP_FEAT/ui" \
  "$LCC_FEAT/ui" "$LCC_FEAT/shell" "$LOCAL_FEAT" "$PWA_FEAT" \
  "$APPS_DIR" "$TAURI_DIR" "$SRC_TAURI/src"

############################################
# OPTIONAL: Install client libraries
############################################
if [[ "$DO_DEPS" == "1" ]]; then
  command -v npm >/dev/null 2>&1 || fail "npm not found (required for --deps)"
  (cd "$PUBLISHER" && npm i idb jspdf html2canvas)
fi

############################################
# Embed operator source (non-destructive)
############################################
if [[ -d "$OPERATOR/src" ]]; then
  mkdir -p "$OP_FEAT/module"
  rsync -a --ignore-existing "$OPERATOR/src/" "$OP_FEAT/module/"
fi

############################################
# NEXT APP SHELL
############################################
cat > "$APP/layout.tsx" <<'EOF'
import "./globals.css";
import type { ReactNode } from "react";
import { RegisterServiceWorker } from "@/features/lcc/pwa/RegisterServiceWorker";

export const metadata = {
  title: "Publisher • Lifelong Catch & Correct",
  description: "Single offline program: Publisher + Operator + LCC",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="manifest" href="/manifest.webmanifest" />
        <meta name="theme-color" content="#0b0b0c" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
      </head>
      <body>
        <RegisterServiceWorker />
        {children}
      </body>
    </html>
  );
}
EOF

cat > "$APP/page.tsx" <<'EOF'
import { UnifiedShell } from "@/features/lcc/shell/UnifiedShell";
export default function Home() { return <UnifiedShell />; }
EOF

cat > "$APP/globals.css" <<'EOF'
:root { color-scheme: dark; }
html, body { height: 100%; }
body { margin: 0; background: #0b0b0c; color: #f2f2f2; font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; }
button { padding: 8px 10px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.12); background: rgba(255,255,255,0.06); color: inherit; cursor: pointer; }
button[aria-pressed="true"] { background: rgba(255,255,255,0.14); }
input, textarea { padding: 10px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.12); background: rgba(255,255,255,0.04); color: inherit; }
EOF

############################################
# UNIFIED SHELL
############################################
cat > "$LCC_FEAT/shell/UnifiedShell.tsx" <<'EOF'
"use client";

import { useState } from "react";
import { PublisherRoot } from "@/features/publisher/ui/PublisherRoot";
import { OperatorRoot } from "@/features/operator/ui/OperatorRoot";
import { LccSidePanel } from "@/features/lcc/ui/LccSidePanel";
import { ChangelogViewer } from "@/features/lcc/ui/ChangelogViewer";

export function UnifiedShell() {
  const [tab, setTab] = useState<"publisher" | "operator" | "changelog">("publisher");

  return (
    <div style={{ display: "flex", height: "100dvh", width: "100%", overflow: "hidden" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
        <header style={{ padding: 12, borderBottom: "1px solid rgba(255,255,255,0.08)", display: "flex", gap: 8 }}>
          <button onClick={() => setTab("publisher")} aria-pressed={tab === "publisher"}>Publisher</button>
          <button onClick={() => setTab("operator")} aria-pressed={tab === "operator"}>Operator</button>
          <button onClick={() => setTab("changelog")} aria-pressed={tab === "changelog"}>Changelog</button>
        </header>

        <main style={{ flex: 1, minHeight: 0, overflow: "auto" }}>
          {tab === "publisher" && <PublisherRoot />}
          {tab === "operator" && <OperatorRoot />}
          {tab === "changelog" && <ChangelogViewer />}
        </main>
      </div>

      <aside style={{ width: 380, maxWidth: "38vw", borderLeft: "1px solid rgba(255,255,255,0.08)" }}>
        <LccSidePanel />
      </aside>
    </div>
  );
}
EOF

############################################
# LOCAL DATABASE (IndexedDB via idb)
############################################
cat > "$PUB_FEAT/ui/localDb.ts" <<'EOF'
import { openDB, type DBSchema } from "idb";

type Doc = { id: string; title: string; body: string; updatedAt: number };

interface PublisherDB extends DBSchema {
  docs: {
    key: string;
    value: Doc;
    indexes: { "by-updatedAt": number };
  };
  workflows: {
    key: string;
    value: { id: string; name: string; spec: unknown; updatedAt: number };
    indexes: { "by-updatedAt": number };
  };
}

export async function getDb() {
  return openDB<PublisherDB>("publisher_lcc_db", 1, {
    upgrade(db) {
      const docs = db.createObjectStore("docs", { keyPath: "id" });
      docs.createIndex("by-updatedAt", "updatedAt");
      const wfs = db.createObjectStore("workflows", { keyPath: "id" });
      wfs.createIndex("by-updatedAt", "updatedAt");
    },
  });
}

export async function upsertDoc(doc: Doc) {
  const db = await getDb();
  await db.put("docs", doc);
}

export async function listDocs() {
  const db = await getDb();
  return db.getAllFromIndex("docs", "by-updatedAt");
}
EOF

############################################
# OPERATOR WORKFLOW DSL
############################################
cat > "$OP_FEAT/ui/workflowDsl.ts" <<'EOF'
export type Workflow = {
  id: string;
  name: string;
  steps: Array<
    | { type: "prompt"; label: string }
    | { type: "decision"; label: string; options: Array<{ label: string; next: number }> }
    | { type: "note"; text: string }
  >;
};

export type RunState = {
  stepIndex: number;
  history: Array<{ at: number; label: string; choice?: string }>;
};

export function startRun(): RunState {
  return { stepIndex: 0, history: [] };
}

export function applyChoice(wf: Workflow, state: RunState, choiceLabel?: string): RunState {
  const step = wf.steps[state.stepIndex];
  const now = Date.now();

  if (!step) return state;

  if (step.type === "decision") {
    const opt = step.options.find((o) => o.label === choiceLabel);
    if (!opt) return state;
    return {
      stepIndex: opt.next,
      history: [...state.history, { at: now, label: step.label, choice: opt.label }],
    };
  }

  return {
    stepIndex: state.stepIndex + 1,
    history: [...state.history, { at: now, label: (step as any).label ?? step.type }],
  };
}
EOF

############################################
# PUBLISHER (DB + Export)
############################################
cat > "$PUB_FEAT/ui/exporters.ts" <<'EOF'
export function downloadText(filename: string, content: string, mime = "text/plain") {
  const blob = new Blob([content], { type: mime });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function exportMarkdown(title: string, body: string) {
  const md = `# ${title}\n\n${body}\n`;
  downloadText(`${safe(title)}.md`, md, "text/markdown");
}

function safe(s: string) {
  return (s || "export").trim().replace(/[^\w\-]+/g, "_").slice(0, 80);
}

export async function exportPdfFromElement(el: HTMLElement, filename: string) {
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
    import("html2canvas"),
    import("jspdf"),
  ]);

  const canvas = await html2canvas(el, { scale: 2 });
  const img = canvas.toDataURL("image/png");

  const pdf = new jsPDF({ unit: "pt", format: "a4" });
  const pageW = pdf.internal.pageSize.getWidth();
  const pageH = pdf.internal.pageSize.getHeight();

  const ratio = Math.min(pageW / canvas.width, pageH / canvas.height);
  const w = canvas.width * ratio;
  const h = canvas.height * ratio;

  pdf.addImage(img, "PNG", (pageW - w) / 2, 24, w, h);
  pdf.save(filename);
}
EOF

cat > "$PUB_FEAT/ui/PublisherRoot.tsx" <<'EOF'
"use client";

import { useEffect, useRef, useState } from "react";
import { listDocs, upsertDoc } from "./localDb";
import { exportMarkdown, exportPdfFromElement } from "./exporters";

export function PublisherRoot() {
  const [title, setTitle] = useState("Untitled");
  const [body, setBody] = useState("Write here…");
  const [docs, setDocs] = useState<any[]>([]);
  const previewRef = useRef<HTMLDivElement | null>(null);

  async function refresh() {
    const all = await listDocs();
    setDocs(all);
  }

  useEffect(() => { refresh(); }, []);

  async function save() {
    await upsertDoc({ id: crypto.randomUUID(), title, body, updatedAt: Date.now() });
    await refresh();
  }

  return (
    <section style={{ padding: 16, display: "grid", gap: 12 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Publisher</h2>

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button onClick={save}>Save Local</button>
        <button onClick={() => exportMarkdown(title, body)}>Export MD</button>
        <button
          onClick={async () => {
            if (!previewRef.current) return;
            await exportPdfFromElement(previewRef.current, `${title}.pdf`);
          }}
        >
          Export PDF
        </button>
      </div>

      <input value={title} onChange={(e) => setTitle(e.target.value)} />
      <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={10} />

      <div ref={previewRef} style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 12 }}>
        <div style={{ fontWeight: 900, marginBottom: 8 }}>{title}</div>
        <div style={{ whiteSpace: "pre-wrap", opacity: 0.9 }}>{body}</div>
      </div>

      <div style={{ marginTop: 8, opacity: 0.8, fontSize: 12 }}>
        Local Docs: {docs.length}
      </div>
    </section>
  );
}
EOF

############################################
# OPERATOR (DSL workflow engine)
############################################
cat > "$OP_FEAT/ui/OperatorRoot.tsx" <<'EOF'
"use client";

import { useMemo, useState } from "react";
import { Workflow, applyChoice, startRun } from "./workflowDsl";

export function OperatorRoot() {
  const wf: Workflow = useMemo(() => ({
    id: "wf-1",
    name: "Operator Assist: Publish Decision",
    steps: [
      { type: "prompt", label: "Define objective" },
      { type: "decision", label: "Risk level?", options: [
        { label: "Low", next: 3 },
        { label: "High", next: 2 }
      ]},
      { type: "note", text: "High risk: require review + export evidence." },
      { type: "note", text: "Proceed to Publisher export when ready." }
    ]
  }), []);

  const [state, setState] = useState(() => startRun());

  const step = wf.steps[state.stepIndex];

  return (
    <section style={{ padding: 16, display: "grid", gap: 12 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Operator Assistance</h2>
      <div style={{ opacity: 0.8, fontSize: 12 }}>Workflow: {wf.name}</div>

      <div style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 12 }}>
        {!step ? (
          <div>Done.</div>
        ) : step.type === "note" ? (
          <div>{step.text}</div>
        ) : step.type === "prompt" ? (
          <div>
            <div style={{ fontWeight: 900 }}>{step.label}</div>
            <button onClick={() => setState(applyChoice(wf, state))} style={{ marginTop: 10 }}>
              Next
            </button>
          </div>
        ) : (
          <div>
            <div style={{ fontWeight: 900 }}>{step.label}</div>
            <div style={{ display: "flex", gap: 8, marginTop: 10, flexWrap: "wrap" }}>
              {step.options.map((o) => (
                <button key={o.label} onClick={() => setState(applyChoice(wf, state, o.label))}>{o.label}</button>
              ))}
            </div>
          </div>
        )}
      </div>

      <div style={{ fontSize: 12, opacity: 0.8, whiteSpace: "pre-wrap" }}>
        {state.history.map((h) => `• ${new Date(h.at).toLocaleString()}: ${h.label}${h.choice ? ` → ${h.choice}` : ""}`).join("\n")}
      </div>
    </section>
  );
}
EOF

############################################
# LCC ENGINE (offline, deterministic)
############################################
cat > "$LOCAL_FEAT/lccEngine.ts" <<'EOF'
export type LccMsg = { role: "user" | "assistant"; content: string };

export function lccRespond(_: LccMsg[], input: string): LccMsg {
  const t = (input || "").toLowerCase();
  if (t.includes("checklist")) return { role: "assistant", content: "Checklist: lint → build → export → test → zip" };
  if (t.includes("security")) return { role: "assistant", content: "Security: no network, no secrets, local-only persistence, dependency review." };
  if (t.includes("export")) return { role: "assistant", content: "Exports: MD is text; PDF uses client render capture (no server)." };
  return { role: "assistant", content: "LCC active (offline). Try: checklist | security | export" };
}
EOF

cat > "$LCC_FEAT/ui/LccSidePanel.tsx" <<'EOF'
"use client";

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
          <div key={i} style={{
            justifySelf: m.role === "user" ? "end" : "start",
            maxWidth: "90%",
            padding: 10,
            borderRadius: 14,
            border: "1px solid rgba(255,255,255,0.12)",
            background: m.role === "user" ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.04)",
            whiteSpace: "pre-wrap",
            fontSize: 12,
            lineHeight: 1.4
          }}>{m.content}</div>
        ))}
      </div>

      <form onSubmit={(e) => { e.preventDefault(); send(); }}
        style={{ display: "flex", gap: 8, padding: 12, borderTop: "1px solid rgba(255,255,255,0.08)" }}>
        <input value={input} onChange={(e) => setInput(e.target.value)} placeholder="Type…" style={{ flex: 1 }} />
        <button type="submit" disabled={!canSend}>Send</button>
      </form>
    </div>
  );
}
EOF

############################################
# CHANGELOG (file-backed)
############################################
cat > "$PUBLIC/changelog.json" <<'EOF'
[
  { "ts": "2026-01-04", "title": "DB + DSL + Export + Autostart added", "detail": "Local persistence, workflow engine, MD/PDF export, OS-login autostart (Tauri)." }
]
EOF

cat > "$LCC_FEAT/ui/ChangelogViewer.tsx" <<'EOF'
"use client";
import { useEffect, useState } from "react";
export function ChangelogViewer() {
  const [items, setItems] = useState<any[]>([]);
  useEffect(() => { fetch("/changelog.json").then(r => r.json()).then(setItems).catch(() => setItems([])); }, []);
  return (
    <section style={{ padding: 16 }}>
      <h2 style={{ margin: 0, fontSize: 16 }}>Codex Changelog Viewer</h2>
      <pre style={{ whiteSpace: "pre-wrap", opacity: 0.9 }}>{JSON.stringify(items, null, 2)}</pre>
    </section>
  );
}
EOF

############################################
# PWA (manifest + SW + registration)
############################################
cat > "$PUBLIC/manifest.webmanifest" <<'EOF'
{
  "name": "Publisher • Lifelong Catch & Correct",
  "short_name": "Publisher",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#0b0b0c",
  "theme_color": "#0b0b0c",
  "icons": [
    { "src": "/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any" },
    { "src": "/maskable-icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "maskable" }
  ]
}
EOF

cat > "$PUBLIC/icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="96" fill="#0b0b0c"/>
  <path d="M148 352V160h140c52 0 88 30 88 78 0 49-36 79-88 79H222v35h-74zm74-91h64c22 0 34-11 34-23s-12-22-34-22h-64v45z" fill="#f2f2f2"/>
</svg>
EOF

cat > "$PUBLIC/maskable-icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#0b0b0c"/>
  <circle cx="256" cy="256" r="220" fill="#0b0b0c" stroke="#f2f2f2" stroke-width="18"/>
  <path d="M170 350V162h132c50 0 84 29 84 75 0 47-34 76-84 76h-61v37h-71zm71-91h56c20 0 31-10 31-22 0-11-11-21-31-21h-56v43z" fill="#f2f2f2"/>
</svg>
EOF

cat > "$PUBLIC/sw.js" <<'EOF'
const CACHE = "publisher-offline-v1";
const CORE = ["/", "/manifest.webmanifest", "/icon.svg", "/maskable-icon.svg", "/changelog.json"];

self.addEventListener("install", (e) => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(CORE);
    self.skipWaiting();
  })());
});

self.addEventListener("activate", (e) => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => (k === CACHE ? null : caches.delete(k))));
    self.clients.claim();
  })());
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;

  e.respondWith((async () => {
    const c = await caches.open(CACHE);
    const cached = await c.match(e.request);
    if (cached) return cached;
    try {
      const fresh = await fetch(e.request);
      if (fresh && fresh.status === 200) c.put(e.request, fresh.clone()).catch(() => {});
      return fresh;
    } catch {
      if (e.request.mode === "navigate") return (await c.match("/")) || new Response("Offline");
      throw new Error("Offline");
    }
  })());
});
EOF

cat > "$PWA_FEAT/RegisterServiceWorker.tsx" <<'EOF'
"use client";
import { useEffect } from "react";
export function RegisterServiceWorker() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => {});
  }, []);
  return null;
}
EOF

############################################
# TAURI + OS-LOGIN AUTOSTART
############################################
cat > "$SRC_TAURI/Cargo.toml" <<'EOF'
[package]
name = "publisher_lcc"
version = "0.1.0"
edition = "2021"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-autostart = "2"

[features]
default = []
EOF

cat > "$SRC_TAURI/build.rs" <<'EOF'
fn main() { tauri_build::build() }
EOF

cat > "$SRC_TAURI/src/main.rs" <<'EOF'
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
  tauri::Builder::default()
    .setup(|app| {
      #[cfg(desktop)]
      {
        app.handle().plugin(
          tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None
          )
        );
      }
      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
EOF

cat > "$SRC_TAURI/tauri.conf.json" <<'EOF'
{
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
    "windows": [{ "title": "Publisher • Lifelong Catch & Correct", "width": 1280, "height": 800 }]
  }
}
EOF

cat > "$TAURI_DIR/package.json" <<'EOF'
{
  "name": "publisher-tauri",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": { "dev": "tauri dev", "build": "tauri build" }
}
EOF

############################################
# OPTIONAL TOOLING
############################################
if [[ "$DO_TOOLING" == "1" ]]; then
  command -v npm >/dev/null 2>&1 || fail "npm not found"
  [[ -f "$PUBLISHER/package.json" ]] || fail "Missing publisher/package.json"
  (cd "$PUBLISHER" && npm i -D eslint prettier husky lint-staged)
fi

############################################
# OPTIONAL ZIP
############################################
if [[ "$DO_ZIP" == "1" ]]; then
  command -v npm >/dev/null 2>&1 || fail "npm not found"
  (cd "$PUBLISHER" && npm i && npm run build)
  mkdir -p "$DIST"
  rm -f "$DIST/publisher_operator_offline.zip"
  (cd "$ROOT" && zip -r "$DIST/publisher_operator_offline.zip" publisher operator-assistance apps tools -x "**/node_modules/*" "**/.next/cache/*" "**/.git/*")
fi

############################################
# VERIFICATION
############################################
req() { [[ -e "$1" ]] || fail "Missing: $1"; }

req "$PUB_FEAT/ui/localDb.ts"
req "$OP_FEAT/ui/workflowDsl.ts"
req "$PUB_FEAT/ui/exporters.ts"
req "$PUBLIC/manifest.webmanifest"
req "$PUBLIC/sw.js"
req "$SRC_TAURI/src/main.rs"

echo ""
echo "====================================="
echo " Unified Offline Program: COMPLETE"
echo "====================================="
echo ""
echo "Features:"
echo "  ✔ Publisher + Operator unified"
echo "  ✔ IndexedDB local storage"
echo "  ✔ Workflow DSL engine"
echo "  ✔ MD + PDF export (client-side)"
echo "  ✔ LCC side-panel (offline)"
echo "  ✔ PWA (manifest + SW + icons)"
echo "  ✔ Tauri (desktop + OS-login autostart)"
echo ""
echo "Run web:"
echo "  cd publisher && npm i && npm run dev"
echo ""
echo "Install PWA:"
echo "  Browser → Install App"
echo ""
echo "Run desktop:"
echo "  cargo install tauri-cli"
echo "  cd apps/tauri && npm run dev"
echo ""
[[ "$DO_ZIP" == "1" ]] && echo "ZIP ready: dist/publisher_operator_offline.zip"
echo ""
