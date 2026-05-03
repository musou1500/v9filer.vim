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

  var prefix_resolved = fs.Join(repository_root.value, prefix.value)
  for record in git_cli.Status(root)
    var path = fs.Join(repository_root.value, record.path)
    # ignore if the status record is outside the root
    if stridx(path, prefix_resolved) != 0
      continue
    endif

    # mark file and all its ancestors as dirty
    var path_in_root = fs.Join(root, path[strlen(prefix_resolved) : ])
    status.paths[path_in_root] = GetStatusKind(record.status_text)
    for directory in fs.Ancestors(path_in_root, root)
      status.directories[directory] = true
    endfor
  endfor
  return status
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
