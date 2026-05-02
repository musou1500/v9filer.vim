vim9script

import './fs.vim' as fs

# Returns Git status kinds for the tree under root.
# Paths are normalized absolute paths, and symlinks are matched as links
# instead of resolving their targets. Outside a Git repository, status is empty.
#
# Processing flow:
#   1. Find the repository root for the displayed root.
#   2. Read `git status --porcelain=v1` as stable path/status records.
#   3. Store direct file/link status and aggregate the strongest descendant
#      status onto each ancestor directory.
#
# GitStatus is keyed by normalized absolute paths.
# {
#   files: dict<dict>,       # file or symlink path -> status kind
#   directories: dict<dict>, # directory path -> strongest descendant status kind
# }
export def StatusFor(root: string): dict<any>
  var status = EmptyStatus()
  var repo_root = RepositoryRoot(root)
  if empty(repo_root)
    return status
  endif

  for line in StatusLines(repo_root)
    AddStatusLine(status, repo_root, ParseStatusLine(line))
  endfor
  return status
enddef

export def HasChange(status: dict<any>, path: string, is_dir: bool): bool
  return !empty(EntryStatus(status, path, is_dir))
enddef

export def KindFor(
    status: dict<any>,
    path: string,
    is_dir: bool,
    is_symlink: bool = false
  ): string
  return get(EntryStatus(status, path, is_dir, is_symlink), 'kind', '')
enddef

export def EntryStatus(
    status: dict<any>,
    path: string,
    is_dir: bool,
    is_symlink: bool = false
  ): dict<any>
  var normalized = fs.Normalize(path)
  if is_symlink
    var link_status = get(get(status, 'files', {}), normalized, {})
    if !empty(link_status)
      return link_status
    endif
  endif
  if is_dir
    return get(get(status, 'directories', {}), normalized, {})
  endif
  return get(get(status, 'files', {}), normalized, {})
enddef

def EmptyStatus(): dict<any>
  return {
    files: {},
    directories: {},
  }
enddef

def RepositoryRoot(root: string): string
  var lines = systemlist(['git', '-C', fs.Normalize(root), 'rev-parse', '--show-toplevel'])
  if v:shell_error != 0 || empty(lines)
    return ''
  endif
  return fs.Normalize(lines[0])
enddef

def StatusLines(repo_root: string): list<string>
  # --no-renames keeps a rename as separate delete/add records. That matches
  # the tree view: the new path can be shown directly, while the deleted old
  # path is only aggregated onto its parent directories.
  var lines = systemlist([
    'git',
    '-c',
    'core.quotePath=false',
    '-C',
    repo_root,
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
    '--no-renames',
  ])
  if v:shell_error != 0
    throw 'v9filer: failed to get git status for ' .. repo_root
  endif
  return lines
enddef

# Expected porcelain v1 line with --no-renames:
#   XY path
# where XY is the two-column Git status and path is the repository-relative
# path, possibly quoted by Git. Rename/copy "old -> new" lines are not expected.
def ParseStatusLine(line: string): dict<any>
  if strlen(line) < 4
    ThrowParseError(line, 'too short')
  endif
  if strpart(line, 2, 1) !=# ' '
    ThrowParseError(line, 'missing field separator')
  endif

  var status_text = strpart(line, 0, 2)
  var path_text = strpart(line, 3)
  if empty(path_text)
    ThrowParseError(line, 'missing path')
  endif
  var kind = StatusKind(status_text)

  return {
    kind: kind,
    path: DecodePath(path_text),
  }
enddef

def StatusKind(status_text: string): string
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

def StatusRank(kind: string): number
  var ranks = {
    'new': 10,
    'modified': 20,
    'deleted': 30,
    'conflict': 40,
  }
  if !has_key(ranks, kind)
    throw 'v9filer: invalid git status kind: ' .. string(kind)
  endif
  return ranks[kind]
enddef

def DecodePath(path_text: string): string
  if strpart(path_text, 0, 1) !=# '"'
    return path_text
  endif
  if strlen(path_text) < 2 || strpart(path_text, strlen(path_text) - 1, 1) !=# '"'
    ThrowParseError(path_text, 'unterminated quoted path')
  endif

  var result = ''
  var index = 1
  var last = strlen(path_text) - 1
  while index < last
    var char = strpart(path_text, index, 1)
    if char !=# '\'
      result ..= char
      index += 1
      continue
    endif

    if index + 1 >= last
      ThrowParseError(path_text, 'dangling path escape')
    endif
    var escaped = strpart(path_text, index + 1, 1)
    var simple = {
      '"': '"',
      '\': '\',
      'a': "\a",
      'b': "\b",
      'f': "\f",
      'n': "\n",
      'r': "\r",
      't': "\t",
      'v': "\v",
    }
    if has_key(simple, escaped)
      result ..= simple[escaped]
      index += 2
    elseif escaped =~# '[0-7]'
      var [decoded, next_index] = DecodeOctalEscape(path_text, index + 1, last)
      result ..= decoded
      index = next_index
    else
      result ..= escaped
      index += 2
    endif
  endwhile
  return result
enddef

def DecodeOctalEscape(text: string, start: number, end: number): list<any>
  var digits = ''
  var index = start
  while index < end && strlen(digits) < 3
    var char = strpart(text, index, 1)
    if char !~# '[0-7]'
      break
    endif
    digits ..= char
    index += 1
  endwhile
  return [nr2char(str2nr(digits, 8)), index]
enddef

def ThrowParseError(line: string, reason: string): void
  throw 'v9filer: invalid git porcelain v1 status line: '
    .. reason .. ': ' .. string(line)
enddef

def AddStatusLine(status: dict<any>, repo_root: string, parsed: dict<any>): void
  var path = fs.Normalize(fs.Join(repo_root, parsed.path))
  var entry_status = {
    kind: parsed.kind,
  }
  var entry_rank = StatusRank(parsed.kind)

  # Symlinks are matched by the link path reported by Git. Their targets are
  # intentionally not resolved, so a link does not inherit target changes.
  var current_file_status = get(status.files, path, {})
  if empty(current_file_status) || entry_rank > StatusRank(current_file_status.kind)
    status.files[path] = entry_status
  endif
  for directory in fs.Ancestors(path, repo_root)
    var current_directory_status = get(status.directories, directory, {})
    if empty(current_directory_status) || entry_rank > StatusRank(current_directory_status.kind)
      status.directories[directory] = entry_status
    endif
  endfor
enddef
