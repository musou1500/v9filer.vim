vim9script

import './fs.vim' as fs
import './git_cli.vim' as git_cli

# Returns Git status for the tree under root.
# Changed paths and ancestor directories are normalized absolute paths, and
# symlinks are matched as links instead of resolving their targets. Outside a
# Git repository, status is empty.
#
# Processing flow:
#   1. Find the Git prefix for the displayed root.
#   2. Read `git status --porcelain=v1` as stable path/status records.
#   3. Map repository-relative Git paths back onto the displayed root, preserving
#      symlink spellings used to open the tree.
#   4. Store changed paths and mark their ancestor directories as dirty.
#
# GitStatus is keyed by normalized absolute paths.
# {
#   paths: dict<string>,     # changed path -> status kind
#   directories: dict<bool>, # ancestor directory of a changed path -> true
# }
export def Status(root: string): dict<any>
  var status = {
    paths: {},
    directories: {},
  }
  var prefix = git_cli.Prefix(root)
  var repository_root = git_cli.TopLevel(root)
  if !prefix.ok || !repository_root.ok
    return status
  endif

  var prefix_resolved = fs.Normalize(fs.Join(repository_root.value, prefix.value))
  for record in git_cli.Status(root)
    var path = fs.Normalize(fs.Join(repository_root.value, record.path))
    # ignore if the status record is outside the root
    if !fs.IsUnder(path, prefix_resolved)
      continue
    endif

    # mark file and all its ancestors as dirty
    var relative = path ==# prefix_resolved ? '' : path[strlen(prefix_resolved) + 1 :]
    var path_in_root = empty(relative) ? root : fs.Join(root, relative)
    status.paths[path_in_root] = GetStatusKind(record.status_text)
    for directory in fs.Ancestors(path_in_root, root)
      status.directories[directory] = true
    endfor
  endfor
  return status
enddef

# Returns a dashboard-style summary for the Home view.
# {
#   ok: bool,        # false when root is outside any git repository
#   branch: string,  # `main`, `feature/x`, or `HEAD` (detached) — empty when ok is false
#   totals: {added: int, deleted: int, files: int},   # tracked changes vs HEAD only
#   files: list<{kind, path, abs_path, added, deleted}>,
#     # kind:    'modified' | 'new' | 'deleted' | 'conflict'
#     # path:    repo-prefix-relative display path (e.g. 'autoload/v9filer/home.vim')
#     # abs_path: normalized absolute path on disk (used for jump-to-file)
#     # added/deleted: tracked diff vs HEAD; 0 for untracked files (numstat does
#     #                not cover them, and totals therefore excludes them).
# }
export def Summary(root: string): dict<any>
  var result = {
    ok: false,
    branch: '',
    totals: {added: 0, deleted: 0, files: 0},
    files: [],
  }

  var branch = git_cli.Branch(root)
  if !branch.ok
    return result
  endif
  result.ok = true
  result.branch = branch.value

  var prefix = git_cli.Prefix(root)
  var toplevel = git_cli.TopLevel(root)
  if !prefix.ok || !toplevel.ok
    return result
  endif

  var prefix_resolved = fs.Normalize(fs.Join(toplevel.value, prefix.value))

  var numstat_result = git_cli.Numstat(root)
  var numstat_by_path: dict<dict<number>> = {}
  if numstat_result.ok
    for record in numstat_result.value
      var abs_path = fs.Normalize(fs.Join(toplevel.value, record.path))
      numstat_by_path[abs_path] = {added: record.added, deleted: record.deleted}
      result.totals.added += record.added
      result.totals.deleted += record.deleted
    endfor
  endif

  for record in git_cli.Status(root)
    var abs_path = fs.Normalize(fs.Join(toplevel.value, record.path))
    if abs_path !=# prefix_resolved && !fs.IsUnder(abs_path, prefix_resolved)
      continue
    endif
    var relative = abs_path ==# prefix_resolved
      ? ''
      : abs_path[strlen(prefix_resolved) + 1 :]
    var display_path = empty(relative) ? '.' : relative
    var ns = get(numstat_by_path, abs_path, {added: 0, deleted: 0})
    add(result.files, {
      kind: GetStatusKind(record.status_text),
      path: display_path,
      abs_path: abs_path,
      added: ns.added,
      deleted: ns.deleted,
    })
  endfor
  result.totals.files = len(result.files)

  return result
enddef

def GetStatusKind(status_text: string): string
  if status_text =~# 'U' || index(['AA', 'DD'], status_text) >= 0
    return 'conflict'
  endif
  if status_text =~# 'D'
    return 'deleted'
  endif
  if status_text ==# '??' || status_text =~# '[AC]'
    return 'new'
  endif
  return 'modified'
enddef
