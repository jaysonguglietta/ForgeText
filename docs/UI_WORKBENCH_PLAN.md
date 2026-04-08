# ForgeText UI Workbench Plan

ForgeText should feel high-signal, memorable, and unmistakably native, even while the shell borrows visual language from late-90s web software. The app is at its best when it helps engineers recognize structure quickly, switch modes without friction, and keep one mental model across text editing and structured inspection.

## Current UI baseline

The current shipped shell already includes:

- a retro-web chrome system with beveled panels, bright portal colors, and monospaced control surfaces
- a left-rail document and workspace sidebar
- an integrated workspace explorer and embedded terminal surface
- a header that surfaces mode, language, theme, pane layout, and document actions
- breadcrumbs, outline rail, structured-view toggles, mode-aware banners, and per-line insight bars
- matching retro treatment across the main sheets like command palette, search, sessions, and shortcuts
- structured viewers for JSON, CSV, logs, configs, and HTTP request files

That baseline should be treated as the new visual system, not as disposable placeholder styling.

## Core workbench principles

- The document header should surface the current mode, language, and a fast toggle between raw text and structured views.
- Structured viewers should feel like alternate lenses on the same file, not separate tools with their own navigation rules.
- Status information should stay compact and meaningful: counts, file format, warnings, and mode-specific metrics.
- The sidebar should grow into a workbench rail with recent files, symbols, saved searches, and project utilities.
- Explorer, plugin, diagnostics, and task surfaces should feel like related tools, not separate mini-apps.
- The retro look should support utility, not block it. Novelty should live in the chrome while reading and editing stay legible.

## Near-term UI improvements

- Add synchronized split panes for compare and dual-context editing.
- Add pinned documents and better grouping for logs, configs, and scratch buffers.
- Add richer table interactions: sort, filter, freeze columns, hide columns, and copy cell/row actions.
- Add mode-aware empty and error states that explain what ForgeText is doing and how to get back to raw text.
- Add stronger visual treatment for active pane focus, compare mode, and read-only states.
- Make remote results, terminal output, and diagnostics panels feel like first-class workbench panes.

## Retro-shell guardrails

- Keep headings and controls bold and playful, but keep document content areas focused and readable.
- Prefer high-contrast cream, cyan, teal, pink, and gold accents over default macOS gray-on-gray surfaces.
- Use monospaced labels and compact utility phrasing for the shell.
- Avoid fake nostalgia that hurts usability. No blinking content, low-contrast text, or noisy backgrounds behind the editor surface.
- Structured viewers should look like they belong to the same portal-era workbench, even when they diverge in layout.

## Structured view direction

- CSV: evolve from a clean read-only table into a sortable, filterable grid.
- JSON: support recursive search, path copying, collapse/expand controls, and type-aware formatting.
- Logs: support severity filters, field grouping, saved filters, and timeline clustering.
- Config formats: add schema-aware or key-value views where structure is obvious and low-risk.
- HTTP: grow the request runner into a compact API workbench with environment variables, saved responses, and assertions.
