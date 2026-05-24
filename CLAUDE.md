# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-purpose Vim9script sidebar file explorer (`:V9Filer`). No build system, no test suite, no package config. Vim 9.0+ is the only dependency. After editing `doc/v9filer.txt`, run `:helptags doc` (or `:helptags ALL`) inside Vim to regenerate tags.

User-facing behavior is documented in `doc/v9filer.txt` and `README.md`; default mappings and config flags live in `plugin/v9filer.vim`. Keep all three in sync when changing surface area.

## Architecture: tab owns state, buffer is ephemeral

This is the core model and worth understanding before changing anything that touches state:

- **Per-tab UI state** lives in `t:` variables, accessed *only* through `autoload/v9filer/tab_state.vim`. Never read or write `t:v9filer_*` directly elsewhere — the wrapper exists so that adding/removing state stays local. The canonical "this tab has a filer" marker is `exists('t:v9filer_root')` (`tab_state.HasState()`).
- **The sidebar buffer is created fresh on every `Open()`** with `bufhidden=wipe`. Closing the window wipes the buffer; reopening rebuilds it from tab state. Because of this, `Close()` is just `:close` — no manual cleanup, the `BufWipeout` autocmd (`OnBufWipeout`) clears `t:v9filer_buf`.
- **Buffer name is `v9filer #<id>`**, where `<id>` is allocated once per tab from a script-local monotonic counter in `tab_state.vim`. The root is not in the name (it goes in the breadcrumb header), so `ChangeRoot` never renames the buffer and two tabs at the same root cannot collide on name (E95).
- **`b:v9filer_state`** is render-transient only: `{lines: {<lnum>: {kind, path}}}` where `kind` is `'tree' | 'working' | 'home'`. It dies with the buffer. Its presence (`buf_state.Has()`) is also the source-of-truth for "is this buffer a filer?" — used by `IsFilerBuffer`, `target_window.IsManaged`, and `working_files.IsTrackable`.
- **Working Files** (`t:v9filer_working_files`) is separate from the UI-state group because tracking starts on any normal-file `BufWinEnter`, even before `:V9Filer` runs in the tab.

Previous designs stored state in `b:` or encoded the root into the buffer name and ran into E95 / state-leak bugs when multiple tabs aliased the same buffer. Don't reintroduce those.

## Home view

`home.vim` owns a per-tab scratch buffer named `v9filer home #<id>` (id from
`tab_state.AllocateHomeId()`, sharing the monotonic counter with the sidebar
id). It is rendered independently of `render.Refresh`: `home.Render` walks
`git.Summary(root)` and `todo.Scan(root)` and writes lines with `setline` and
`matchaddpos`. The buffer carries `b:v9filer_home = true` so
`target_window.IsManaged` and `IsFilerBuffer` exclude it when picking a
target window for files.

The sidebar shows a one-line `Home` menu row above Working Files. Its row in
`buf_state.line_index` is `{kind: 'home', path: ''}`. `actions.OpenOrExpand`,
`actions.OpenPath` and `autoload/v9filer.vim:OpenInNewTab` all check
`buf_state.IsHomeLine` *before* the empty-path early-return so the row
dispatches to `home.Open(kind)` instead of silently no-oping.

## Render pipeline

`render.Refresh()` is the single rebuild path. Everything that changes UI state ends with `render.Refresh()`. The pipeline is:

1. Build a `view` dict (lines + `line_index` + `highlight_positions` buckets) by appending in order: `AddHelp` (optional) → `AddHomeMenu` → `AddWorkingFilesSection` → `AddHeader` → `AddDirectoryTree`.
2. `Flush(view)` writes once via `setline(1, view.lines)`, then `ApplyHighlights` calls `matchaddpos` per bucket. Match IDs are tracked in `w:v9filer_match_ids` and cleared on each refresh.
3. `buf_state.SetLines(view.line_index)` is the only way line numbers get bound to paths. All cursor-based actions resolve through `buf_state.PathForLine` / `TreePathForLine` / `WorkingFilePathForLine` — never re-parse the buffer text.

Each row is `indent + marker + icon + name + suffix(@/*) + git_status + parent_path`; the comment block at the top of `AddEntry` in `render.vim` is the authoritative format reference.

## Git status

`git.Status(root)` shells out via `git_cli.vim` (`rev-parse --show-prefix`, `rev-parse --show-toplevel`, `status --porcelain=v1 --no-renames --untracked-files=all`) and remaps repo-relative paths back onto the displayed root. Two subtleties:

- Paths are *not* symlink-resolved during normalization. A repo opened through a symlink keeps status markers attached to the symlinked path.
- Porcelain v1 C-style-quotes paths even with `core.quotePath=false`; `git_cli.DecodePath` handles `\n \t \" \\ \<octal>`. Don't bypass it.

Outside a Git repo, `Status` returns an empty result silently — callers should expect that.

## Module responsibilities (autoload/v9filer/)

When adding new behavior, slot it into the module whose responsibility matches. Don't grow new siblings unless none fit.

- **tab_state.vim** — Accessor for `t:v9filer_*`. State-only, no side effects. Allocates and tracks the per-tab monotonic id used in buffer names.
- **buf_state.vim** — `b:v9filer_state` (render-transient). Maps buffer line numbers to `{kind, path}` (kind: `'tree' | 'working' | 'home'`) and answers cursor-line lookups for actions.
- **fs.vim** — Filesystem I/O: `Normalize`, `Join`, `IsUnder`, `Ancestors`, `Parent`, `IsDir`, `Exists`, `ListDir`, `Create`, `Delete`, `Rename`, `RenameTarget`, `CreateTarget`. Wraps Vim builtins so callers don't sprinkle path math.
- **icons.vim** — Resolves file kind / name into a Nerd Font icon + highlight group. Extensible via `g:v9filer_nerd_font_icon_rules`.
- **git_cli.vim** — `git` subprocess calls (`Prefix`, `TopLevel`, `Status`) and porcelain v1 path decoding. Returns `{ok, value}` shapes. No state, no side effects.
- **git.vim** — Translates `git_cli` records into the displayed root's absolute paths (preserving symlink spellings) and marks ancestor directories dirty. Outside a repo, returns an empty result silently.
- **working_files.vim** — CRUD for `t:v9filer_working_files` plus the `BufWinEnter` hook that auto-registers normal-file buffers.
- **render.vim** — Sidebar render pipeline. Builds a `view` dict (lines + `line_index` + `highlight_positions`), then `Flush` writes once and `ApplyHighlights` applies `matchaddpos` per bucket. Owns highlight group definitions.
- **target_window.vim** — Decides which window opens a file or Home (`MoveTo`), and tells callers whether a given window is one of v9filer's own managed windows (`IsManaged`).
- **actions.vim** — Sidebar buffer keymap handlers. File operations, root change, copy, working-file removal, refresh, help/hidden toggle.
- **todo.vim** — Scans the tree for `TODO` comments via `rg` (preferred) or `git grep` (fallback). Returns a sorted list of `{path, lnum, text}`.
- **home.vim** — Per-tab Home scratch buffer (`v9filer home #<id>`, `bufhidden=wipe`). Renders branch + diff totals + per-file changes (from `git.Summary`) and the TODO list (from `todo.Scan`). Owns its own keymap and highlight groups; does not flow through `render.Refresh`.
- **autoload/v9filer.vim** — Top-level entry: `Open`, `RevealCurrentFile`, autocmd handlers (`AutoReveal`, `OnBufWinEnter`, `OnBufWipeout`, `RememberFocusWindow`). Owns the sidebar buffer setup (`SetupBuffer`, `DefineBufferMappings`) and the new-tab open shortcut.
- **plugin/v9filer.vim** — Entry-point: command definitions, default mappings, autocmd groups.

## Conventions

- Vim9script everywhere. New files start with `vim9script` and use `export def` / `import './x.vim' as x`. Match the existing import style.
- The module split is by responsibility (see above). New behavior should slot into the matching module rather than spawning a sibling.
- File-mutation actions (`Delete`, `Rename`, `Create`) wrap `fs.*` in `try/catch` and surface errors with `echoerr v:exception`. Follow that pattern for new ops; don't let `fs.*` exceptions escape to the user as raw stack traces.
- When an action changes anything visible, it must call `render.Refresh()` (or delegate to one that does) — there is no implicit redraw.
