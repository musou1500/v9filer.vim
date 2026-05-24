vim9script

import './fs.vim' as fs
import './git_cli.vim' as git_cli

# Scan the tree under root for `# TODO:` / `// TODO:` comments.
# Only matches a comment marker at the start of a line (optionally indented);
# inline trailing comments like `foo;  # TODO:` are excluded. This trades a
# few real hits for a much cleaner list — docs, string literals, and inline
# notes would otherwise dominate.
# Returns a list of {path, lnum, text} sorted by path then lnum, where path is
# a normalized absolute path on disk and text is the entire matched line.
# Prefers `rg` (respects .gitignore, fast) and falls back to `git grep` when
# rg is unavailable but root is inside a Git repository. If neither tool is
# available the user is warned once per call and an empty list is returned.
export def Scan(root: string): list<dict<any>>
  if executable('rg')
    return ScanWithRg(root)
  endif
  if executable('git') && IsInsideRepo(root)
    return ScanWithGitGrep(root)
  endif
  echohl WarningMsg
  echom 'v9filer: rg or git is required to scan TODO comments'
  echohl None
  return []
enddef

def ScanWithRg(root: string): list<dict<any>>
  var output = system([
    'rg',
    '--line-number',
    '--no-heading',
    '--color=never',
    '--hidden',
    '--glob',
    '!.git/',
    '^\s*(#|//)\s*TODO:',
    root,
  ])
  # rg returns 1 when there are no matches; treat as an empty result, not an
  # error. >=2 is an actual failure.
  if v:shell_error >= 2
    return []
  endif
  return SortEntries(ParseGrepLines(split(output, '\r\?\n'), ''))
enddef

def ScanWithGitGrep(root: string): list<dict<any>>
  var toplevel = git_cli.TopLevel(root)
  if !toplevel.ok
    return []
  endif
  var output = system([
    'git',
    '-C',
    root,
    'grep',
    '--line-number',
    '--no-color',
    '--untracked',
    '-E',
    '^[[:space:]]*(#|//)[[:space:]]*TODO:',
  ])
  if v:shell_error >= 2
    return []
  endif
  # git grep prints paths relative to the repository toplevel; expand to
  # absolute so callers do not need to know which fallback ran.
  return SortEntries(ParseGrepLines(split(output, '\r\?\n'), toplevel.value))
enddef

def ParseGrepLines(lines: list<string>, path_base: string): list<dict<any>>
  var entries: list<dict<any>> = []
  for line in lines
    if empty(line)
      continue
    endif
    var matches = matchlist(line, '\v^(.{-}):(\d+):(.*)$')
    if empty(matches)
      continue
    endif
    var raw_path = matches[1]
    var lnum = str2nr(matches[2])
    var text = matches[3]
    var abs_path = empty(path_base)
      ? fs.Normalize(raw_path)
      : fs.Normalize(fs.Join(path_base, raw_path))
    add(entries, {path: abs_path, lnum: lnum, text: text})
  endfor
  return entries
enddef

def SortEntries(entries: list<dict<any>>): list<dict<any>>
  return sort(entries, (a, b) => {
    if a.path ==# b.path
      return a.lnum - b.lnum
    endif
    return a.path <# b.path ? -1 : 1
  })
enddef

def IsInsideRepo(root: string): bool
  return git_cli.TopLevel(root).ok
enddef
