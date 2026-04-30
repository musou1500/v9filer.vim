vim9script

# State is stored in b:v9filer_state for each filer buffer.
# {
#   root: string,        # normalized directory displayed as the tree root
#   mode: string,        # "embedded" or "toggle"
#   show_hidden: bool,   # whether dotfiles are listed
#   expanded: dict<bool>, # absolute directory path -> expanded
#   line_paths: dict<string>, # 1-based buffer line number as string -> path
#   help: bool,          # whether the quick-help rows are visible
#   prev_buf: number,    # buffer to restore when closing embedded mode
# }
export def New(root: string, mode: string, prev_buf: number): dict<any>
  return {
    root: root,
    mode: mode,
    show_hidden: get(g:, 'v9filer_show_hidden', true),
    expanded: {},
    line_paths: {},
    help: false,
    prev_buf: prev_buf,
  }
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

export def Root(): string
  return get(Get(), 'root', '')
enddef

export def Mode(): string
  return get(Get(), 'mode', '')
enddef

export def IsToggle(): bool
  return Mode() ==# 'toggle'
enddef

export def ShowHidden(): bool
  return get(Get(), 'show_hidden', false)
enddef

export def HelpEnabled(): bool
  return get(Get(), 'help', false)
enddef

export def Expanded(): dict<any>
  return get(Get(), 'expanded', {})
enddef

export def PreviousBuffer(): number
  return get(Get(), 'prev_buf', 0)
enddef

export def SetRoot(root: string): void
  Patch({
    root: root,
    expanded: {},
  })
enddef

export def ToggleHidden(): void
  Patch({show_hidden: !ShowHidden()})
enddef

export def ToggleHelp(): void
  Patch({help: !HelpEnabled()})
enddef

export def ToggleExpanded(path: string): void
  var expanded = Expanded()
  if get(expanded, path, false)
    remove(expanded, path)
  else
    expanded[path] = true
  endif
  Patch({expanded: expanded})
enddef

export def ExpandPaths(paths: list<string>): void
  var expanded = Expanded()
  for path in paths
    expanded[path] = true
  endfor
  Patch({expanded: expanded})
enddef

export def SetLinePaths(line_paths: dict<any>): void
  Patch({line_paths: line_paths})
enddef

export def PathForLine(line_number: number): string
  return get(get(Get(), 'line_paths', {}), string(line_number), '')
enddef

export def Patch(changes: dict<any>): dict<any>
  var st = Get()
  for [key, value] in items(changes)
    st[key] = value
  endfor
  Set(st)
  return st
enddef
