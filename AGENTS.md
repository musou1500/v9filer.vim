# Repository Guidelines

## Project Structure & Module Organization

This repository contains a Vim9script file explorer plugin.

- `plugin/v9filer.vim`: thin startup entrypoint. Defines commands, global mappings, and autocmds.
- `autoload/v9filer.vim`: public orchestration API for opening, toggling, and revealing files.
- `autoload/v9filer/*.vim`: internal modules.
  - `state.vim`: buffer-local state helpers.
  - `fs.vim`: filesystem listing and file operations.
  - `render.vim`: breadcrumb and tree buffer rendering.
  - `actions.vim`: buffer-local command and mapping actions.
- `doc/v9filer.txt`: user-facing help and behavior specification.

There is currently no dedicated `test/` directory or asset directory.

## Build, Test, and Development Commands

No build step is required. Validate changes directly with Vim:

```sh
vim -Nu NONE -i NONE -n --not-a-term -es -S script.vim
```

Useful smoke test pattern:

```vim
set rtp^=/path/to/v9filer.vim
runtime plugin/v9filer.vim
V9Filer /tmp
qa!
```

Use temporary directories via Vim `tempname()` for tests that create, rename, or delete files.

## Coding Style & Naming Conventions

Use `vim9script` for all implementation files. Keep modules small and responsibility-focused. Public autoload functions use `UpperCamelCase`, for example `Open()` and `RevealCurrentFile()`. Script-local helpers should be descriptive and action-oriented, such as `ParseArgs()` or `BuildTree()`.

Use two-space indentation, avoid unnecessary comments, and prefer simple dictionaries/lists over class-like abstractions. Keep `plugin/v9filer.vim` thin; implementation logic belongs in `autoload/`.

## Testing Guidelines

Tests are currently ad hoc Vim scripts. Cover both module-level helpers and user workflows:

- command loading and buffer setup
- embedded and toggle modes
- tree rendering, sorting, hidden files, and suffixes
- mappings/actions such as expand, refresh, split open, yank, and close
- filesystem operations in temporary directories only
- `:V9FilerReveal` behavior for files inside and outside the sidebar root

Use `assert_equal()`, `assert_true()`, and `v:errors`; exit with `cquit` on failure.

## Commit & Pull Request Guidelines

This workspace has no Git history, so no repository-specific commit convention can be inferred. Use concise imperative commit messages, for example `Add reveal support` or `Fix toggle sidebar close`.

Pull requests should include a short behavior summary, test commands run, and any updates to `doc/v9filer.txt` when user-visible behavior changes. Include screenshots only if UI rendering changes are difficult to describe textually.

## Agent-Specific Instructions

Do not edit generated or temporary files into the repository. Keep changes aligned with `doc/v9filer.txt`, and update the help file whenever commands, mappings, or configuration behavior changes.
