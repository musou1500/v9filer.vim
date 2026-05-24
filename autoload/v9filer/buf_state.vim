vim9script

# Buffer-local render transient. b:v9filer_state lives only as long as the
# filer buffer (bufhidden=wipe) and is rebuilt by render.Refresh on every
# render. Persistent UI state (root, expanded, show_hidden, help) lives in
# tab_state instead.
#
# {
#   lines: dict<string, dict<any>>,
#       # 1-based buffer line number (as string) -> {kind, path}.
#       # kind is one of:
#       #   'tree'    — a directory tree row, path is the file/dir path
#       #   'working' — a Working Files row, path is the file path
#       #   'home'    — the sidebar Home menu row, path is empty
#       # Cursor-based actions resolve through KindOfLine + the *PathForLine
#       # helpers below.
# }
export def New(): dict<any>
  return {lines: {}}
enddef

export def Get(): dict<any>
  return get(b:, 'v9filer_state', {})
enddef

export def Set(st: dict<any>): void
  b:v9filer_state = st
enddef

export def Has(): bool
  return !empty(Get())
enddef

export def SetLines(lines: dict<any>): void
  Patch({lines: lines})
enddef

export def KindOfLine(line_number: number): string
  return get(LineEntry(line_number), 'kind', '')
enddef

export def IsHomeLine(line_number: number): bool
  return KindOfLine(line_number) ==# 'home'
enddef

export def PathForLine(line_number: number): string
  return get(LineEntry(line_number), 'path', '')
enddef

export def WorkingFilePathForLine(line_number: number): string
  var entry = LineEntry(line_number)
  if get(entry, 'kind', '') !=# 'working'
    return ''
  endif
  return get(entry, 'path', '')
enddef

export def TreePathForLine(line_number: number): string
  var entry = LineEntry(line_number)
  if get(entry, 'kind', '') !=# 'tree'
    return ''
  endif
  return get(entry, 'path', '')
enddef

def LineEntry(line_number: number): dict<any>
  return Get()
    ->get('lines', {})
    ->get(string(line_number), {})
enddef

def Patch(changes: dict<any>): void
  var st = Get()
  if empty(st)
    st = New()
  endif
  for [k, v] in items(changes)
    st[k] = v
  endfor
  Set(st)
enddef
