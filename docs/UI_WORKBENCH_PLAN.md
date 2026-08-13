# ForgeText UI Workbench Plan

ForgeText should feel like a serious native developer editor first: calm, fast, legible, and keyboard-friendly. Studio is the default direction. Retro styles remain optional presets, not the default information architecture.

## Shipped Shell

The main editor now contains only four sidebar destinations:

- `Files`: open documents and workspace tree
- `Search`: project-wide search
- `Source Control`: branch and changed-file essentials
- `Workbench`: workspace health plus entry points to deeper engineering workflows

Quick Open, Command Palette, tabs, the document, and a compact status bar remain the high-frequency surfaces. Tasks, terminal, AI, plugins, setup, support, and advanced controls stay available from menus, shortcuts, or the optional Engineering Workbench instead of permanent navigation.

## Engineering Workbench

`Tools > Engineering Workbench` or `Command-Shift-E` opens a native split-view window for:

- Workspace Health
- Code Intelligence
- Review Changes
- Tests + Coverage
- Remote Workspaces
- Investigations
- Data Tools
- AI Change Sets
- Enterprise
- Profile Packs

Sections use progressive disclosure. Git hunks, history, and worktrees appear only after a file is selected. Enterprise details and saved contexts do not compete with the editor.

## Design Principles

- The document is the center of gravity.
- Prefer one clear primary action and hide secondary detail until requested.
- Do not duplicate the same command in a header, sidebar, status bar, and card.
- Use native hierarchy, lists, disclosure groups, menus, focus rings, and keyboard behavior.
- Keep operational status compact: cursor, language, selection, trust, and active panel.
- Structured views are optional lenses; raw text is always authoritative.
- Keep dangerous actions explicit, explain policy blocks, and require confirmation or review where state can be lost or data can leave the Mac.
- Preserve a usable minimum window size and avoid card walls, nested bevels, decorative labels, or noisy background treatments.

## Shipped Noise Reduction

- removed permanent quick-action rows from the sidebar
- removed recent-file and recent-remote card walls from Files
- reduced six mixed-purpose sidebar panes to four focused destinations
- moved low-frequency metrics behind a compact status-bar Details menu
- replaced repeated header controls with a title, context line, and overflow menu
- retained Quiet UI, Balanced, and Full Retro presets without overwriting custom settings

## Structured View Direction

Delimited tables now provide inferred or overridden schemas, filtering, stable multi-column sorting, aggregations, visible-row copy/export, optional frozen-first-column behavior, and lazy row rendering. Further work should prioritize measured large-dataset performance and keyboard/VoiceOver validation before adding more decoration.

JSON, logs, configuration files, archives, and HTTP requests should follow the same pattern: useful bounded inspection, clear errors and empty states, and an immediate raw-text escape hatch.

## Accessibility And Validation

- preserve keyboard access and visible focus for every primary workflow
- maintain sufficient contrast in Studio and all optional presets
- keep scrollbars and selection states obvious
- test narrow and large windows for truncation, overlap, and scroll behavior
- keep the shipped Studio-shell smoke target stable and expand it to tabs, workbench navigation, dialogs, Git review, and raw/structured switching
- profile the shell with real Markdown, source code, CSV, and log fixtures rather than synthetic empty screens

## Next UI Work

The next visual pass should be evidence-driven: fix measured latency, overflow, contrast, focus, or workflow problems. It should not add another dashboard, rail, decorative theme layer, or permanent status surface.
