# ForgeText UI Workbench Plan

ForgeText should feel like a serious native developer editor first: calm, fast, legible, and keyboard-friendly. The Studio workbench is now the default direction. Retro styling remains part of the product identity, but it should be an optional expression layer rather than the default reading experience.

## Current UI Baseline

The current shell includes:

- a Studio-first workbench style with flatter panels, neutral surfaces, and lower visual noise
- optional Retro Classic, Retro Pro, and Minimal Pro workbench styles
- persistent `Quiet UI`, `Balanced`, and `Full Retro` workbench presets that preserve custom layout state
- a first-run chooser that helps new installs pick the right shell without hunting through preferences
- an activity-rail sidebar with focused panes for Explorer, Source Control, Workspace, Navigate, Tools, and Extensions
- Quick Open and Command Palette as keyboard-first overlays
- workspace explorer, project search, embedded terminal, task runner, problems panel, and test explorer
- Git Workbench, GitHub Workflow, AI Workbench, and AI Context Center
- Activity Center, First-Run Setup, Release Readiness, Performance HUD, Theme Lab, and diagnostic export
- document header controls for file actions, workbench mode, language, theme, pane layout, and major tools
- breadcrumbs, inspector, structured-view toggles, mode-aware banners, and per-line insight bars
- structured viewers for JSON, CSV, logs, configs, HTTP request files, archives, and binary previews

## Core Workbench Principles

- The document is the center of gravity. Chrome should support editing, not compete with it.
- The default workbench should be calm enough for long editing sessions on real code, logs, and config files.
- The sidebar should behave like a workbench, not a miscellaneous control dashboard.
- Quick Open and Command Palette should be the fastest path to most navigation and actions.
- Source control, AI, and terminal tools should feel like peers inside the editor workflow, not detached utilities.
- Structured viewers should feel like alternate lenses on the same document, not separate products.
- Status information should stay compact and meaningful: counts, file format, warnings, mode, Git state, and task status.
- Retro styling should stay usable when enabled: no noisy content areas, low contrast, or distracting decoration.

## Current Workbench Surfaces

### Activity Rail

- Provides fast switching between the main left-side panes.
- Should stay compact, scannable, and muscle-memory friendly.
- Should not duplicate detailed actions better handled inside each pane.

### Explorer

- Combines open documents, workspace tree, and recent files.
- Should feel like a true file-navigation surface, not a stack of cards.
- Future work should keep reducing visual weight and improve tree affordances.

### Source Control

- Surfaces branch state, changed files, and stage/unstage actions close to the editor.
- The sidebar pane should cover the most common Git actions quickly.
- The full Git Workbench should remain available for deeper flows such as history, stash, remotes, and conflict handling.

### Workspace

- Manages roots, trust, clone/open flows, sessions, and remote entry points.
- Should make workspace context obvious without overwhelming the user.

### Navigate

- Groups Quick Open, Command Palette, search, go-to-line, keyboard shortcuts, and activity.
- Should stay keyboard-first and latency-sensitive.

### Tools And Extensions

- Collect higher-order workflows such as Git, AI, terminal, tests, plugins, snippets, setup, and appearance.
- Should not become the dumping ground for every secondary action.

### Quick Open

- Primary keyboard path for indexed files and symbols.
- Powered by the local workspace index.
- Should stay fast, compact, and predictable.

### Command Palette

- Supports `>`, `@`, and `#` mode prefixes.
- Acts as the universal action layer for commands, navigation, settings, and tool entry points.
- Future work should improve ranking, recency, and selection behavior.

### Theme Lab

- Controls workbench style, density, editor theme, focus mode, and inspector state.
- Should make `Studio` the obvious daily-driver choice while preserving retro variants cleanly.

## Visual Guardrails

- Keep document reading areas quiet and high-contrast.
- Prefer restrained use of accent color in the default Studio shell.
- Use bold monospaced labels only where they add orientation value.
- Avoid stacked bevels, repeated card framing, and decorative panel nesting in high-frequency flows.
- Keep overlays compact and focused.
- Keep scrollbars, selection states, focus rings, and active-pane states obvious.

## Structured View Direction

- CSV: continue evolving toward sortable, filterable, copy-friendly grids.
- JSON: add recursive search, path copying, collapse/expand presets, and type-aware formatting.
- Logs: add timestamp parsing, severity filters, field grouping, saved filters, and timeline clustering.
- Config formats: add schema-aware or key-value views for infrastructure files.
- HTTP: grow the request runner into a compact API workbench with environment variables, saved responses, and assertions.

## Accessibility And Polish

- Keep keyboard navigation complete for every panel and overlay.
- Ensure focus rings and active pane states are obvious in every chrome style.
- Add UI regression coverage for the Studio shell and remaining retro variants.
- Audit color contrast in every workbench style and density.
- Keep scrollbars visible and usable in structured views and large documents.
