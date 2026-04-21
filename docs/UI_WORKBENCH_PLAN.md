# ForgeText UI Workbench Plan

ForgeText should feel high-signal, memorable, and unmistakably native, even while the shell borrows visual language from late-90s web software. The app is at its best when it helps engineers recognize structure quickly, switch modes without friction, and keep one mental model across raw text editing, structured inspection, Git, AI, and production-readiness tools.

## Current UI Baseline

The current shell includes:

- retro-web chrome with beveled panels, cream/cyan/pink/gold portal colors, and monospaced control surfaces
- a left-rail document, workspace, and Control Center sidebar
- Quick Open and Command Palette 2.0 for keyboard-first navigation
- workspace explorer, project search, embedded terminal, task runner, problems panel, and test explorer
- Git Workbench, GitHub Workflow, AI Workbench, and AI Context Center
- Activity Center, First-Run Setup, Release Readiness, Performance HUD, Theme Lab, and diagnostic export
- document header controls for mode, language, theme, pane layout, document actions, Git, AI, and workspace tools
- breadcrumbs, inspector, outline, structured-view toggles, mode-aware banners, and per-line insight bars
- structured viewers for JSON, CSV, logs, configs, HTTP request files, archives, and binary previews

That baseline is the visual system, not disposable placeholder styling.

## Core Workbench Principles

- The document header should surface the current mode, language, and fast raw/structured toggles.
- Structured viewers should feel like alternate lenses on the same file, not separate tools with different rules.
- Status information should stay compact and meaningful: counts, file format, warnings, mode, Git state, and task status.
- The sidebar should stay useful without becoming noisy; it should provide document switching, workspace context, and high-value control-center actions.
- Command Palette and Quick Open should be the fastest path to almost every feature.
- Git and AI panels should feel like native workbench peers, not bolted-on modal utilities.
- Release, diagnostic, and performance surfaces should feel like production tools, not debug leftovers.
- The retro look should support utility. Novelty belongs in the chrome while reading and editing stay legible.

## New 1.1 Surfaces

### Quick Open

- Primary keyboard path for files and symbols.
- Powered by a local workspace index.
- Should stay fast, compact, and predictable.

### Command Palette 2.0

- Supports `>`, `@`, and `#` mode prefixes.
- Should remain the global universal action layer.
- Future work should add better ranking, recent command memory, and user-defined aliases.

### Control Center Sidebar

- Groups higher-order tools: Quick Open, Activity Center, AI Context, GitHub Workflow, and Setup Checklist.
- Should avoid duplicating every menu item.
- Should surface only tools that help orient or accelerate the workspace.

### Activity Center

- Local mission log for files, indexing, diagnostics, release checks, and support exports.
- Should become the place for long-running operations and background task progress.

### First-Run Setup

- Checklist for onboarding a workspace.
- Should stay practical and reversible.
- Future work can add guided setup for AI providers, Git identity, and update feeds.

### AI Context Center

- Shows rules and reusable prompt files before AI actions.
- Should help users trust what context will be sent.
- Future work should add per-file and per-folder context previews.

### GitHub Workflow

- Detects GitHub remotes and opens repository/compare pages.
- Should evolve into PR creation, issue lookup, and review workflows.

### Release Readiness

- Checks Sparkle, appcast, DMG, docs, version, and release script setup.
- Should remain conservative and clear about blockers versus warnings.

### Performance HUD

- Lightweight local health snapshot.
- Should help diagnose workspace size, index size, plugins, and task count without telemetry.

### Theme Lab

- Central place for retro intensity, density, editor theme, focus mode, and inspector state.
- Should preserve the late-90s identity while making production editing calmer.

## Retro-Shell Guardrails

- Keep headings and controls bold and playful, but keep document content areas focused and readable.
- Prefer high-contrast cream, cyan, teal, pink, and gold accents over default gray-on-gray surfaces.
- Use monospaced labels and compact utility phrasing for shell chrome.
- Avoid fake nostalgia that hurts usability: no blinking content, low-contrast text, or noisy editor backgrounds.
- Structured viewers should look like they belong to the same portal-era workbench, even when they diverge in layout.
- Busy screens should collapse into grouped menus, panels, and progressive disclosure.

## Structured View Direction

- CSV: evolve from a table view into sortable, filterable, copy-friendly grids.
- JSON: add recursive search, path copying, collapse/expand presets, and type-aware formatting.
- Logs: add timestamp parsing, severity filters, field grouping, saved filters, and timeline clustering.
- Config formats: add schema-aware or key-value views for infrastructure files.
- HTTP: grow the request runner into a compact API workbench with environment variables, saved responses, and assertions.

## Accessibility And Polish

- Keep keyboard navigation complete for every panel.
- Ensure focus rings and active pane states are obvious.
- Add UI regression coverage for new panels and structured views.
- Audit color contrast in every chrome style and density.
- Keep scrollbars visible and usable in structured views and large documents.
