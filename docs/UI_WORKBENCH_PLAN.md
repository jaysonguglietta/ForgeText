# ForgeText UI Workbench Plan

ForgeText should feel calm, high-signal, and intentional. The app is at its best when it helps engineers recognize structure quickly, switch modes without friction, and keep one mental model across text editing and structured inspection.

## Core workbench principles

- The document header should surface the current mode, language, and a fast toggle between raw text and structured views.
- Structured viewers should feel like alternate lenses on the same file, not separate tools with their own navigation rules.
- Status information should stay compact and meaningful: counts, file format, warnings, and mode-specific metrics.
- The sidebar should grow into a workbench rail with recent files, symbols, saved searches, and project utilities.

## Near-term UI improvements

- Add breadcrumbs and symbol outline for code and config files.
- Add split panes with synchronized scrolling for compare and dual-context editing.
- Add pinned documents and better grouping for logs, configs, and scratch buffers.
- Add richer table interactions: sort, filter, freeze columns, hide columns, and copy cell/row actions.
- Add mode-aware empty and error states that explain what ForgeText is doing and how to get back to raw text.

## Structured view direction

- CSV: evolve from a clean read-only table into a sortable, filterable grid.
- JSON: support recursive search, path copying, collapse/expand controls, and type-aware formatting.
- Logs: support severity filters, field grouping, saved filters, and timeline clustering.
- Config formats: add schema-aware or key-value views where structure is obvious and low-risk.
