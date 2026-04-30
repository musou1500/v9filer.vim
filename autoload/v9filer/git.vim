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
    return status
  endif

  for line in lines
    var kind = KindForLine(line)
    for path in ChangedPaths(line)
      var full_path = fs.Normalize(fs.Join(repo_root, path))
      status.files[full_path] = MergeFileKind(
        get(status.files, full_path, ''),
        kind
      )
      MarkDirectories(status.directories, full_path, repo_root)
    endfor
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

def KindForLine(line: string): string
  if stridx(line, '??') == 0 || strpart(line, 0, 2) =~# 'A'
    return 'added'
  endif
  return 'changed'
enddef

def MergeFileKind(current: string, next: string): string
  if current ==# 'added' || next ==# 'added'
    return 'added'
  endif
  return 'changed'
enddef

def ChangedPaths(line: string): list<string>
  if strlen(line) < 4
    return []
  endif

  var path_text = strpart(line, 3)
  if empty(path_text)
    return []
  endif

  if stridx(path_text, ' -> ') >= 0
    return split(path_text, ' -> ')
  endif

  return [path_text]
enddef

def MarkDirectories(directories: dict<bool>, path: string, repo_root: string): void
  var current = fs.Parent(path)
  var root = fs.Normalize(repo_root)
  while fs.IsUnder(current, root)
    directories[current] = true
    if current ==# root
      return
    endif
    current = fs.Parent(current)
  endwhile
enddef
