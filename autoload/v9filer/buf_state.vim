vim9script

# Buffer-local render transient. b:v9filer_state lives only as long as the
# filer buffer (bufhidden=wipe) and is rebuilt by render.Refresh on every
# render. Persistent UI state (root, expanded, show_hidden, help) lives in
# tab_state instead.
#
# {
#   lines: dict<string, dict<any>>,
#       # 1-based buffer line number (as string) -> {path, is_working}.
#       # Each entry binds a buffer line to the path it represents and
#       # whether that line belongs to the Working Files section. Used so
#       # that mappings like `<CR>` and `x` can resolve cursor line to a path
#       # and tell tree rows from working file rows.
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

export def PathForLine(line_number: number): string
  return get(LineEntry(line_number), 'path', '')
enddef

export def WorkingFilePathForLine(line_number: number): string
  var entry = LineEntry(line_number)
  if !get(entry, 'is_working', false)
    return ''
  endif
  return get(entry, 'path', '')
enddef

export def TreePathForLine(line_number: number): string
  var entry = LineEntry(line_number)
  if get(entry, 'is_working', false)
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
