vim9script

import './state.vim' as state
import './fs.vim' as fs
import './git.vim' as git
import './icons.vim' as icons

const IconHighlightGroups: dict<string> = {
  directory: 'V9FilerIconDirectory',
  executable: 'V9FilerIconExecutable',
  file: 'V9FilerIconFile',
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
      git_new_statuses: [],
      git_modified_statuses: [],
      git_deleted_statuses: [],
      git_conflict_statuses: [],
      git_directory_statuses: [],
      icons: {},
      symlinks: [],
      executables: [],
      empty_lines: [],
    },
  }

  var git_status = git.Status(state.Root())

  AddHeader(view, git_status)

  if state.HelpEnabled()
    AddHelp(view)
  endif

  AddDirectoryTree(
    view,
    state.Root(),
    0,
    state.ShowHidden(),
    state.Expanded(),
    git_status
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

def AddHeader(view: dict<any>, git_status: dict<any>): void
  var header_text = fnamemodify(fs.Normalize(state.Root()), ':~')
  var lnum = len(view.lines) + 1
  var text = header_text
  add(view.lines, text)
  add(view.highlight_positions.breadcrumb, [lnum, 1, strlen(header_text)])
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
  # Entry lines are composed as: indent + marker + icon + name + type suffixes + git status.
  # Examples without an icon:
  #   1. "- src/"        expanded directory at depth 0. the marker is '- '.
  #   2. "  app.vim"     file at depth 0; the marker is two alignment spaces
  #   3. "      app.vim" file at depth 2; indent is four spaces, marker is two alignment spaces
  #   4. "    run*"      executable at depth 1. the suffix is '*'. marker is two alignment spaces.
  #   5. "    link@"     symlink at depth 1. the suffix is '@'. marker is two alignment spaces.
  #   6. "+ link/@"      symlink directory at depth 0. suffixes are '/' and '@'.
  #   7. "    link@*"    symlink to executable at depth 1. suffixes are '@' and '*'.

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
  if entry.is_dir
    text ..= '/'
    col += 1
  endif
  if get(entry, 'is_symlink', false)
    add(view.highlight_positions.symlinks, [lnum, col, 1])
    text ..= '@'
    col += 1
  endif
  if !entry.is_dir && get(entry, 'is_executable', false)
    add(view.highlight_positions.executables, [lnum, col, 1])
    text ..= '*'
    col += 1
  endif

  # git status
  if entry.is_dir
      && (has_key(git_status.paths, entry.path)
        || get(git_status.directories, entry.path, false))
    var label = '[*]'
    text ..= ' '
    col += 1
    add(view.highlight_positions.git_directory_statuses, [lnum, col, strlen(label)])
    text ..= '[*]'
    col += strlen(label)
  elseif !entry.is_dir && has_key(git_status.paths, entry.path)
    var label = {
      'new': '[N]',
      'modified': '[M]',
      'deleted': '[D]',
      'conflict': '[!]',
    }[git_status.paths[entry.path]]
    text ..= ' '
    col += 1
    add(GitStatusHighlightGroup(view, git_status.paths[entry.path]), [lnum, col, strlen(label)])
    text ..= label
    col += strlen(label)
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
  AddMatch('V9FilerGitDirectoryChanged', positions.git_directory_statuses, 12)
  AddMatch('V9FilerGitModified', positions.git_modified_statuses, 12)
  AddMatch('V9FilerGitNew', positions.git_new_statuses, 12)
  AddMatch('V9FilerGitDeleted', positions.git_deleted_statuses, 12)
  AddMatch('V9FilerGitConflict', positions.git_conflict_statuses, 12)
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
  highlight default V9FilerGitDirectoryChanged cterm=bold gui=bold ctermfg=179 guifg=#C89B5A
  highlight default V9FilerGitModified cterm=bold gui=bold ctermfg=179 guifg=#C89B5A
  highlight default V9FilerGitNew cterm=bold gui=bold ctermfg=108 guifg=#7FAF7F
  highlight default V9FilerGitDeleted cterm=bold gui=bold ctermfg=203 guifg=#D75F5F
  highlight default V9FilerGitConflict cterm=bold gui=bold ctermfg=197 guifg=#FF005F
  highlight default link V9FilerIconDirectory Directory
  highlight default link V9FilerIconExecutable Statement
  highlight default link V9FilerIconFile Normal
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

def GitStatusLabel(kind: string): string
  var labels = {
    'new': '[N]',
    'modified': '[M]',
    'deleted': '[D]',
    'conflict': '[!]',
  }
  if !has_key(labels, kind)
    throw 'v9filer: invalid git status kind: ' .. string(kind)
  endif
  return labels[kind]
enddef

def GitStatusHighlightGroup(view: dict<any>, kind: string): list<list<number>>
  if kind ==# 'new'
    return view.highlight_positions.git_new_statuses
  endif
  if kind ==# 'modified'
    return view.highlight_positions.git_modified_statuses
  endif
  if kind ==# 'deleted'
    return view.highlight_positions.git_deleted_statuses
  endif
  if kind ==# 'conflict'
    return view.highlight_positions.git_conflict_statuses
  endif
  throw 'v9filer: invalid git status kind: ' .. string(kind)
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
