vim9script

import './state.vim' as state
import './fs.vim' as fs
import './icons.vim' as icons

export def Refresh(): void
  if !state.Has()
    return
  endif

  var lines: list<string> = []
  var line_paths: dict<any> = {}
  var line_meta: list<dict<any>> = []
  add(lines, BuildHeader(state.Root()))

  var help_enabled = state.HelpEnabled()
  var icons_enabled = icons.IconsEnabled()
  if help_enabled
    add(lines, '? help | <CR> open/toggle | l enter | - parent | . hidden | R refresh | q close')
    add(lines, '')
  endif

  BuildTree(
    state.Root(),
    0,
    lines,
    line_paths,
    line_meta,
    state.ShowHidden(),
    state.Expanded(),
    icons_enabled
  )
  if len(lines) == 1 || (help_enabled && len(lines) == 3)
    add(lines, '  [empty]')
    add(line_meta, {line: len(lines), kind: 'empty', start: 3, length: 7})
  endif

  state.SetLinePaths(line_paths)

  var view = winsaveview()
  setlocal modifiable
  silent! :%delete _
  setline(1, lines)
  setlocal nomodifiable
  setlocal nomodified
  ApplyHighlights(lines, line_meta)
  winrestview(view)
enddef

def BuildTree(
    root: string,
    depth: number,
    lines: list<string>,
    line_paths: dict<any>,
    line_meta: list<dict<any>>,
    show_hidden: bool,
    expanded: dict<any>,
    icons_enabled: bool
  ): void
  for entry in fs.ListDir(root, show_hidden)
    var expanded_dir = get(expanded, entry.path, false)
    var marker = entry.is_dir ? (expanded_dir ? '- ' : '+ ') : '  '
    var indent = repeat('  ', depth)
    var icon = icons_enabled ? icons.IconForEntry(entry) : {}
    var icon_text = get(icon, 'text', '')
    var suffix = EntrySuffix(entry)
    var prefix = indent .. marker .. icon_text
    var line = prefix .. entry.name .. suffix
    add(lines, line)
    line_paths[string(len(lines))] = entry.path
    add(line_meta, {
      line: len(lines),
      kind: entry.is_dir ? 'directory' : 'file',
      start: strlen(prefix) + 1,
      length: strlen(entry.name),
      marker_start: strlen(indent) + 1,
      marker_length: strlen(marker),
      icon_start: strlen(indent) + strlen(marker) + 1,
      icon_length: strlen(icon_text),
      icon_group: get(icon, 'group', 'V9FilerIconFile'),
      icon_color: get(icon, 'color', ''),
      suffix_start: strlen(prefix) + strlen(entry.name) + 1,
      suffix_length: strlen(suffix),
      suffix: suffix,
      hidden: entry.name =~# '^\.',
    })
    if entry.is_dir && expanded_dir
      BuildTree(
        entry.path,
        depth + 1,
        lines,
        line_paths,
        line_meta,
        show_hidden,
        expanded,
        icons_enabled
      )
    endif
  endfor
enddef

def EntrySuffix(entry: dict<any>): string
  if entry.is_dir
    return '/'
  endif
  if get(entry, 'is_symlink', false)
    return '@'
  endif
  return get(entry, 'is_executable', false) ? '*' : ''
enddef

def ApplyHighlights(lines: list<string>, line_meta: list<dict<any>>): void
  ClearHighlights()
  if !get(g:, 'v9filer_use_colors', true)
    return
  endif

  EnsureHighlightGroups()

  if !empty(lines[0])
    AddMatch('V9FilerBreadcrumb', [[1, 1, strlen(lines[0])]], 10)
  endif

  if len(lines) > 1 && lines[1] =~# '^? help'
    AddMatch('V9FilerHelp', [[2, 1, strlen(lines[1])]], 10)
  endif

  var directories: list<list<number>> = []
  var files: list<list<number>> = []
  var hidden: list<list<number>> = []
  var markers: list<list<number>> = []
  var icon_positions: dict<list<list<number>>> = {}
  var symlinks: list<list<number>> = []
  var executables: list<list<number>> = []
  var empty_lines: list<list<number>> = []

  for meta in line_meta
    var kind = get(meta, 'kind', '')
    if kind ==# 'empty'
      add(empty_lines, [meta.line, meta.start, meta.length])
      continue
    endif

    if get(meta, 'marker_length', 0) > 0
      add(markers, [meta.line, meta.marker_start, meta.marker_length])
    endif
    if get(meta, 'icon_length', 0) > 0
      var icon_group = IconHighlightGroup(
        get(meta, 'icon_color', ''),
        get(meta, 'icon_group', 'V9FilerIconFile')
      )
      if empty(icon_group)
        icon_group = 'V9FilerIconFile'
      endif
      if !has_key(icon_positions, icon_group)
        icon_positions[icon_group] = []
      endif
      add(icon_positions[icon_group], [meta.line, meta.icon_start, meta.icon_length])
    endif

    var name_pos = [meta.line, meta.start, meta.length]
    if kind ==# 'directory'
      add(directories, name_pos)
    else
      add(files, name_pos)
    endif
    if get(meta, 'hidden', false)
      add(hidden, name_pos)
    endif

    if get(meta, 'suffix_length', 0) > 0
      var suffix_pos = [meta.line, meta.suffix_start, meta.suffix_length]
      if meta.suffix ==# '@'
        add(symlinks, suffix_pos)
      elseif meta.suffix ==# '*'
        add(executables, suffix_pos)
      endif
    endif
  endfor

  AddMatch('V9FilerDirectory', directories, 10)
  AddMatch('V9FilerFile', files, 10)
  AddMatch('V9FilerMarker', markers, 11)
  for [group, positions] in items(icon_positions)
    AddMatch(group, positions, 11)
  endfor
  AddMatch('V9FilerSymlink', symlinks, 12)
  AddMatch('V9FilerExecutable', executables, 12)
  AddMatch('V9FilerHidden', hidden, 13)
  AddMatch('V9FilerEmpty', empty_lines, 10)
enddef

def EnsureHighlightGroups(): void
  highlight default link V9FilerBreadcrumb Title
  highlight default link V9FilerDirectory Directory
  highlight default link V9FilerFile Normal
  highlight default link V9FilerMarker Special
  highlight default link V9FilerIconDirectory Directory
  highlight default link V9FilerIconExecutable Statement
  highlight default link V9FilerIconFile Normal
  highlight default link V9FilerIconSymlink Special
  highlight default link V9FilerSymlink Special
  highlight default link V9FilerExecutable Statement
  highlight default link V9FilerHidden Comment
  highlight default link V9FilerHelp Comment
  highlight default link V9FilerEmpty Comment
enddef

def IconHighlightGroup(color: string, fallback: string): string
  if !icons.IsIconColor(color)
    return fallback
  endif

  var group = 'V9FilerIconColor' .. tolower(strpart(color, 1))
  execute 'highlight ' .. group .. ' guifg=' .. color
  return group
enddef

export def ClearHighlights(): void
  for id in get(w:, 'v9filer_match_ids', [])
    try
      matchdelete(id)
    catch
    endtry
  endfor
  w:v9filer_match_ids = []
enddef

def AddMatch(group: string, positions: list<list<number>>, priority: number): void
  if empty(positions)
    return
  endif
  for start in range(0, len(positions) - 1, 8)
    var id = matchaddpos(group, positions[start : start + 7], priority)
    add(w:v9filer_match_ids, id)
  endfor
enddef

def BuildHeader(root: string): string
  return 'v9filer: ' .. fnamemodify(fs.Normalize(root), ':~')
enddef
