vim9script

# State is stored in b:v9filer_state for each filer buffer.
# {
#   root: string,        # normalized directory displayed as the tree root
#   show_hidden: bool,   # whether dotfiles are listed
#   expanded: dict<bool>, # absolute directory path -> expanded
#   line_paths: dict<string>, # 1-based buffer line number as string -> path
#   working_file_lines: dict<bool>, # 1-based line number (string) -> true; marks
#                                   # which lines belong to the working files
#                                   # section so that section-only actions can
#                                   # tell tree rows from working file rows.
#   help: bool,          # whether the quick-help rows are visible
# }
export def New(root: string): dict<any>
  return {
    root: root,
    show_hidden: get(g:, 'v9filer_show_hidden', true),
    expanded: {},
    line_paths: {},
    working_file_lines: {},
    help: false,
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

export def ShowHidden(): bool
  return get(Get(), 'show_hidden', false)
enddef

export def HelpEnabled(): bool
  return get(Get(), 'help', false)
enddef

export def Expanded(): dict<any>
  return get(Get(), 'expanded', {})
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

export def SetWorkingFileLines(lines: dict<any>): void
  Patch({working_file_lines: lines})
enddef

export def IsWorkingFileLine(line_number: number): bool
  return get(get(Get(), 'working_file_lines', {}), string(line_number), false)
enddef

export def Patch(changes: dict<any>): dict<any>
  var st = Get()
  for [key, value] in items(changes)
    st[key] = value
  endfor
  Set(st)
  return st
enddef
