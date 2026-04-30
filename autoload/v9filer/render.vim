vim9script

import './state.vim' as state
import './fs.vim' as fs
import './git.vim' as git
import './icons.vim' as icons

const IconHighlightGroups: dict<string> = {
  directory: 'V9FilerIconDirectory',
  executable: 'V9FilerIconExecutable',
  file: 'V9FilerIconFile',
  symlink: 'V9FilerIconSymlink',
}

# Rendering is staged through a view dictionary: collect the text lines and
# highlight positions first, write the lines to the buffer, then apply all
# highlights with matchaddpos().
export def Refresh(): void
  if !state.Has()
    return
  endif

  var view = {
    lines: [],
    line_paths: {},
    entry_count: 0,
    highlight_positions: {
      breadcrumb: [],
      help: [],
      directories: [],
      files: [],
      hidden: [],
      markers: [],
      git_added_statuses: [],
      git_changed_statuses: [],
      icons: {},
      symlinks: [],
      executables: [],
      empty_lines: [],
    },
  }

  AddHeader(view)

  if state.HelpEnabled()
    AddHelp(view)
  endif

  AddDirectoryTree(
    view,
    state.Root(),
    0,
    state.ShowHidden(),
    state.Expanded(),
    git.StatusFor(state.Root())
  )
  if view.entry_count == 0
    AddEmptyLine(view)
  endif

  Flush(view)
enddef

def Flush(view: dict<any>): void
  state.SetLinePaths(view.line_paths)

  var saved_view = winsaveview()
  setlocal modifiable
  silent! :%delete _
  setline(1, view.lines)
  setlocal nomodifiable
  setlocal nomodified
  ApplyHighlights(view)
  winrestview(saved_view)
enddef

def AddHeader(view: dict<any>): void
  var header_text = fnamemodify(fs.Normalize(state.Root()), ':~')
  add(view.lines, header_text)
  add(view.highlight_positions.breadcrumb, [len(view.lines), 1, strlen(header_text)])
enddef

def AddHelp(view: dict<any>): void
  var help_text = '? help | <CR> open/toggle | l enter | - parent | . hidden | R refresh | q close'
  add(view.lines, help_text)
  add(view.highlight_positions.help, [len(view.lines), 1, strlen(help_text)])
  add(view.lines, '')
enddef

def AddEmptyLine(view: dict<any>): void
  add(view.lines, '  [empty]')
  add(view.highlight_positions.empty_lines, [len(view.lines), 3, 7])
enddef

def AddDirectoryTree(
    view: dict<any>,
    root: string,
    depth: number,
    show_hidden: bool,
    expanded: dict<any>,
    git_status: dict<any>
  ): void
  for entry in fs.ListDir(root, show_hidden)
    var expanded_dir = get(expanded, entry.path, false)
    AddEntry(view, entry, depth, expanded_dir, icons.Resolve(entry), git_status)
    if entry.is_dir && expanded_dir
      AddDirectoryTree(
        view,
        entry.path,
        depth + 1,
        show_hidden,
        expanded,
        git_status
      )
    endif
  endfor
enddef

def AddEntry(
    view: dict<any>,
    entry: dict<any>,
    depth: number,
    expanded_dir: bool,
    icon: dict<string>,
    git_status: dict<any>
  ): void
  # Entry lines are composed as: indent + marker + icon + name + type suffix + git status.
  # Examples without an icon:
  #   1. "- src/"        expanded directory at depth 0. the marker is '- '.
  #   2. "  app.vim"     file at depth 0; the marker is two alignment spaces
  #   3. "      app.vim" file at depth 2; indent is four spaces, marker is two alignment spaces
  #   4. "    run*"      executable at depth 1. the suffix is '*'. marker is two alignment spaces.
  #   5. "    link@"     symlink at depth 1. the suffix is '@'. marker is two alignment spaces.

  var lnum = len(view.lines) + 1
  var text = ''
  var col = 1

  # indent
  var indent = repeat('  ', depth)
  text ..= indent
  col += strlen(indent)

  # marker
  var marker = entry.is_dir ? (expanded_dir ? '- ' : '+ ') : '  '
  var marker_width = strlen(marker)
  text ..= marker
  add(view.highlight_positions.markers, [lnum, col, marker_width])
  col += marker_width

  # icon
  var icon_text = icon.text
  var icon_width = strlen(icon_text)
  text ..= icon_text
  if icon_width > 0
    var icon_group = IconHighlightGroup(
      get(icon, 'color', ''),
      get(IconHighlightGroups, get(icon, 'kind', 'file'), 'V9FilerIconFile')
    )
    if !has_key(view.highlight_positions.icons, icon_group)
      view.highlight_positions.icons[icon_group] = []
    endif
    add(view.highlight_positions.icons[icon_group], [lnum, col, icon_width])
  endif
  col += icon_width

  # name
  var name_width = strlen(entry.name)
  text ..= entry.name
  if entry.is_dir
    add(view.highlight_positions.directories, [lnum, col, name_width])
  else
    add(view.highlight_positions.files, [lnum, col, name_width])
  endif
  if entry.name =~# '^\.'
    add(view.highlight_positions.hidden, [lnum, col, name_width])
  endif
  col += name_width

  # suffix
  var suffix = ''
  if entry.is_dir
    suffix = '/'
  elseif get(entry, 'is_symlink', false)
    suffix = '@'
    add(view.highlight_positions.symlinks, [lnum, col, strlen(suffix)])
  else
    suffix = get(entry, 'is_executable', false) ? '*' : ''
    if get(entry, 'is_executable', false)
      add(view.highlight_positions.executables, [lnum, col, strlen(suffix)])
    endif
  endif
  text ..= suffix

  # git status
  var git_status_kind = git.KindFor(git_status, entry.path, entry.is_dir)
  if !empty(git_status_kind)
    var git_status_text = GitStatusText(git_status_kind)
    var git_status_group = git_status_kind ==# 'added'
      ? view.highlight_positions.git_added_statuses
      : view.highlight_positions.git_changed_statuses
    col += strlen(suffix) + 1
    add(git_status_group, [lnum, col, strlen(git_status_text)])
    text ..= ' ' .. git_status_text
  endif

  # apply built text and highlights to view
  add(view.lines, text)
  view.line_paths[string(lnum)] = entry.path
  view.entry_count += 1
enddef

def ApplyHighlights(view: dict<any>): void
  ClearHighlights()
  if !get(g:, 'v9filer_use_colors', true)
    return
  endif

  EnsureHighlightGroups()

  var positions = view.highlight_positions
  AddMatch('V9FilerBreadcrumb', positions.breadcrumb, 10)
  AddMatch('V9FilerHelp', positions.help, 10)
  AddMatch('V9FilerDirectory', positions.directories, 10)
  AddMatch('V9FilerFile', positions.files, 10)
  AddMatch('V9FilerMarker', positions.markers, 11)
  AddMatch('V9FilerGitChanged', positions.git_changed_statuses, 12)
  AddMatch('V9FilerGitAdded', positions.git_added_statuses, 12)
  for [group, icon_positions] in items(positions.icons)
    AddMatch(group, icon_positions, 11)
  endfor
  AddMatch('V9FilerSymlink', positions.symlinks, 12)
  AddMatch('V9FilerExecutable', positions.executables, 12)
  AddMatch('V9FilerHidden', positions.hidden, 13)
  AddMatch('V9FilerEmpty', positions.empty_lines, 10)
enddef

def EnsureHighlightGroups(): void
  highlight default link V9FilerBreadcrumb Title
  highlight default link V9FilerDirectory Directory
  highlight default link V9FilerFile Normal
  highlight default link V9FilerMarker Special
  highlight default V9FilerGitChanged cterm=bold gui=bold ctermfg=179 guifg=#C89B5A
  highlight default V9FilerGitAdded cterm=bold gui=bold ctermfg=108 guifg=#7FAF7F
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

def GitStatusText(kind: string): string
  if kind ==# 'added'
    return '[+]'
  endif
  if kind ==# 'changed'
    return '[~]'
  endif
  return '[*]'
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
  var id = matchaddpos(group, positions, priority)
  add(w:v9filer_match_ids, id)
enddef
