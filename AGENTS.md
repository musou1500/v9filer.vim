# Repository Guidelines

## Project Structure & Module Organization

This repository is a Vim 9 file explorer plugin.

- `plugin/v9filer.vim`: plugin entrypoint, user commands, mappings, and autocmds.
- `autoload/v9filer.vim`: main public implementation loaded by the plugin.
- `autoload/v9filer/*.vim`: internal modules by responsibility, including `actions`, `render`, `fs`, `git`, `git_cli`, `tab_state`, `buf_state`, `working_files`, and `icons`.
- `doc/v9filer.txt`: Vim help documentation. Keep it aligned with `README.md` and command/config changes.
- `screenshot.png`: README asset.

## Build, Test, and Development Commands

There is no package manager, build step, or generated source. Develop directly against Vim 9.0+.

- `vim --clean -Nu NONE -n +'set rtp+=.' +':V9Filer'`: quick local smoke test with this checkout on `runtimepath`.
- `vim -Nu NONE -n +'set rtp+=.' +'helptags doc' +qa`: regenerate help tags after editing `doc/v9filer.txt`.
- `git status --short`: check the working tree before and after edits.

## Coding Style & Naming Conventions

Use Vim9script for all Vim files. New files should start with `vim9script`, export only interfaces that other modules need, and import sibling modules like `import './fs.vim' as fs`.

Keep module ownership clear: state access belongs in `tab_state` or `buf_state`, rendering in `render`, filesystem operations in `fs`, user actions in `actions`, and Git shelling/parsing in `git_cli`/`git`. Prefer simple, readable code over new abstractions.

When visible state changes, call `render.Refresh()` or delegate to code that does. File mutation actions should catch `fs.*` errors and show `echoerr v:exception`.

## Testing Guidelines

No automated test suite is currently present. Manually smoke test behavior in Vim after changes:

- Open and close `:V9Filer` and `:Filer`.
- Navigate directories, expand/collapse entries, and reveal the current file with `:V9FilerReveal`.
- For filesystem changes, test create, rename, delete, and overwrite confirmation paths.
- For Git changes, test inside and outside a Git repository, including paths with spaces or special characters.

## Commit & Pull Request Guidelines

The existing history uses short imperative or descriptive commit messages, often in Japanese, for example `add comment`, `refactor`, or `Git連携機能を修正`. Keep commits focused and concise.

Pull requests should describe the user-visible behavior change, list manual Vim smoke tests performed, and mention documentation updates when commands, mappings, options, or help text change. Include screenshot updates only when the sidebar UI appearance changes.

## Agent-Specific Instructions

Do not read or write `t:v9filer_*` directly outside `autoload/v9filer/tab_state.vim`. Do not parse rendered buffer text to recover paths; use `buf_state` lookups. Keep `README.md`, `doc/v9filer.txt`, and `plugin/v9filer.vim` synchronized when changing public commands, mappings, or configuration.
