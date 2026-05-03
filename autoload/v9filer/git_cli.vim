vim9script

export def Prefix(root: string): dict<any>
  # Unlike `git status --porcelain`, `rev-parse --show-prefix` prints the prefix
  # bytes directly instead of C-style quoting special bytes. Keep everything
  # except Git's final record newline as-is.
  var output = system([
    'git',
    '-C',
    root,
    'rev-parse',
    '--show-prefix',
  ])
  if v:shell_error != 0 || empty(output)
    return {
      ok: false,
      value: '',
    }
  endif
  return {
    ok: true,
    # Remove the final newline and any preceding carriage return
    value: substitute(output, '\r\?\n\%$', '', ''),
  }
enddef


export def TopLevel(root: string): dict<any>
  var output = system([
    'git',
    '-C',
    root,
    'rev-parse',
    '--show-toplevel',
  ])
  if v:shell_error != 0 || empty(output)
    return {
      ok: false,
      value: '',
    }
  endif
  return {
    ok: true,
    # Remove the final newline and any preceding carriage return
    value: substitute(output, '\r\?\n\%$', '', ''),
  }
enddef

export def Status(root: string): list<dict<any>>
  # --no-renames keeps a rename as separate delete/add records. That matches
  # the tree view: the new path can be shown directly, while the deleted old
  # path is only aggregated onto its parent directories.
  # Even with core.quotePath=false, Git still C-style quotes double-quotes,
  # backslashes, and control bytes at or below 0x80. See:
  # https://git-scm.com/docs/git-config#Documentation/git-config.txt-corequotePath
  # So parsed porcelain records must decode quoted path text.
  var output = system([
    'git',
    '-c',
    'core.quotePath=false',
    '-C',
    root,
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
    '--no-renames',
  ])
  if v:shell_error != 0
    throw 'v9filer: failed to get git status for ' .. root
  endif

  var lines = split(output, '\r\?\n')
  var records: list<dict<any>> = []
  for line in lines
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

    add(records, {
      status_text: status_text,
      path: DecodePath(path_text),
    })
  endfor

  return records
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
      'a': nr2char(7),
      'b': nr2char(8),
      'f': nr2char(12),
      'n': nr2char(10),
      'r': nr2char(13),
      't': nr2char(9),
      'v': nr2char(11),
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
  var byte = str2nr(digits, 8)
  var decoded = join(blob2str(list2blob([byte]), {encoding: 'none'}), "\n")
  return [decoded, index]
enddef

def ThrowParseError(line: string, reason: string): void
  throw 'v9filer: invalid git porcelain v1 status line: '
    .. reason .. ': ' .. string(line)
enddef
