vim9script

import './fs.vim' as fs

# GitStatus is a compact lookup table used by render.vim.
# {
#   files: dict<string>,     # absolute changed file paths -> "added" or "changed"
#   directories: dict<bool>, # absolute directories containing changed paths
# }
export def StatusFor(root: string): dict<any>
  var status = {
    files: {},
    directories: {},
  }

  var repo_root = RepositoryRoot(root)
  if empty(repo_root)
    return status
  endif

  var lines = systemlist([
    'git',
    '-C',
    repo_root,
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
  ])
  if v:shell_error != 0
    throw 'v9filer: failed to get git status for ' .. repo_root
  endif

  for line in lines
    var parsed = ParseStatusLine(line)
    ApplyStatusLine(status, repo_root, parsed)
  endfor

  return status
enddef

export def HasChange(status: dict<any>, path: string, is_dir: bool): bool
  return !empty(KindFor(status, path, is_dir))
enddef

export def KindFor(status: dict<any>, path: string, is_dir: bool): string
  var normalized = fs.Normalize(path)
  if is_dir
    return get(get(status, 'directories', {}), normalized, false) ? 'directory' : ''
  endif
  return get(get(status, 'files', {}), normalized, '')
enddef

def RepositoryRoot(root: string): string
  var lines = systemlist(['git', '-C', root, 'rev-parse', '--show-toplevel'])
  if v:shell_error != 0 || empty(lines)
    return ''
  endif
  return fs.Normalize(lines[0])
enddef


# Parse porcelain v1 status line
def ParseStatusLine(line: string): dict<any>
  if strlen(line) < 4
    ThrowParseError(line, 'too short')
  endif
  if strpart(line, 2, 1) !=# ' '
    ThrowParseError(line, 'missing field separator')
  endif

  var status_text = strpart(line, 0, 2)
  var is_rename_or_copy = status_text =~# '[RC]'

  var path_text = strpart(line, 3)
  if empty(path_text)
    ThrowParseError(line, 'missing path')
  endif

  var orig_path = ''
  var path = path_text
  if is_rename_or_copy
    if stridx(path_text, ' -> ') < 0
      ThrowParseError(line, 'missing rename/copy separator')
    endif
    var parts = split(path_text, ' -> ')
    if len(parts) != 2
      ThrowParseError(line, 'ambiguous rename/copy paths')
    endif
    orig_path = get(parts, 0, '')
    path = get(parts, 1, '')

    if empty(orig_path)
      ThrowParseError(line, 'missing original path for rename/copy')
    endif
  endif
  
  if empty(path)
    ThrowParseError(line, 'missing path')
  endif

  return {status: status_text, orig_path: orig_path, path: path}
enddef

def ThrowParseError(line: string, reason: string): void
  throw 'v9filer: invalid git porcelain v1 status line: '
    .. reason .. ': ' .. string(line)
enddef

def ApplyStatusLine(status: dict<any>, repo_root: string, parsed: dict<any>): void
  var kind = parsed.status ==# '??' || parsed.status =~# 'A'
    ? 'added'
    : 'changed'

  var full_path = fs.Normalize(fs.Join(repo_root, parsed.path))
  if get(status.files, full_path, '') !=# 'added'
    status.files[full_path] = kind
  endif
  for directory in fs.Ancestors(full_path, repo_root)
    status.directories[directory] = true
  endfor
enddef
