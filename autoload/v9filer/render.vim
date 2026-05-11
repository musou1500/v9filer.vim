vim9script

import './buf_state.vim' as buf_state
import './tab_state.vim' as tab_state
import './fs.vim' as fs
import './git.vim' as git
import './icons.vim' as icons
import './working_files.vim' as working_files

const IconHighlightGroups: dict<string> = {
  directory: 'V9FilerIconDirectory',
  executable: 'V9FilerIconExecutable',
  file: 'V9FilerIconFile',
}

# Rendering is staged through a view dictionary: collect the text lines and
# highlight positions first, write the lines to the buffer, then apply all
# highlights with matchaddpos().
export def Refresh(): void
  if !buf_state.Has() || !tab_state.HasState()
    return
  endif

  var view = {
    lines: [],
    line_index: {},
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
      working_files_header: [],
      working_files_paths: [],
    },
  }

  var git_status = git.Status(tab_state.Root())

  if tab_state.HelpEnabled()
    AddHelp(view)
  endif

  AddWorkingFilesSection(view, tab_state.Root(), git_status)

  AddHeader(view, git_status)

  try
    AddDirectoryTree(
      view,
      tab_state.Root(),
      0,
      tab_state.ShowHidden(),
      tab_state.Expanded(),
      git_status
    )
  catch
    echoerr v:exception
    return
  endtry
  if view.entry_count == 0
    AddEmptyLine(view)
  endif

  Flush(view)
enddef

def Flush(view: dict<any>): void
  buf_state.SetLines(view.line_index)

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
  var header_text = fnamemodify(fs.Normalize(tab_state.Root()), ':~')
  var lnum = len(view.lines) + 1
  var text = header_text
  add(view.lines, text)
  add(view.highlight_positions.breadcrumb, [lnum, 1, strlen(header_text)])
enddef

def AddHelp(view: dict<any>): void
  var help_text = '? help | <CR> open/expand | l enter | - parent | x remove | . hidden | R refresh | q close'
  add(view.lines, help_text)
  add(view.highlight_positions.help, [len(view.lines), 1, strlen(help_text)])
  add(view.lines, '')
enddef

def AddWorkingFilesSection(
    view: dict<any>,
    root: string,
    git_status: dict<any>
  ): void
  var files = working_files.List()
  if empty(files)
    return
  endif

  if !empty(view.lines) && view.lines[-1] !=# ''
    add(view.lines, '')
  endif

  var heading = 'Working Files'
  add(view.lines, heading)
  add(view.highlight_positions.working_files_header,
    [len(view.lines), 1, strlen(heading)])

  for path in files
    AddWorkingFileEntry(view, path, root, git_status)
  endfor

  add(view.lines, '')
enddef

def AddWorkingFileEntry(
    view: dict<any>,
    path: string,
    root: string,
    git_status: dict<any>
  ): void
  # Working file lines are: alignment + icon + name + suffixes + path + git status.
  # The two-space alignment matches the marker width used by file rows in the
  # tree section so the icon column lines up vertically.
  var name = fnamemodify(path, ':t')
  var is_symlink = getftype(path) ==# 'link'
  var is_executable = !isdirectory(path) && executable(path) > 0
  var icon = icons.Resolve({
    name: name,
    is_dir: false,
    is_symlink: is_symlink,
    is_executable: is_executable,
  })

  var lnum = len(view.lines) + 1
  var text = ''
  var col = 1

  # alignment (matches file marker width in the tree)
  text ..= '  '
  col += 2

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
  var name_width = strlen(name)
  text ..= name
  add(view.highlight_positions.files, [lnum, col, name_width])
  if name =~# '^\.'
    add(view.highlight_positions.hidden, [lnum, col, name_width])
  endif
  col += name_width

  # symlink suffix
  if is_symlink
    add(view.highlight_positions.symlinks, [lnum, col, 1])
    text ..= '@'
    col += 1
  endif

  # executable suffix
  if is_executable
    add(view.highlight_positions.executables, [lnum, col, 1])
    text ..= '*'
    col += 1
  endif

  # separator
  text ..= ' '
  col += 1

  # git status
  if has_key(git_status.paths, path)
    var label = GitStatusLabel(git_status.paths[path])
    add(GitStatusHighlightGroup(view, git_status.paths[path]),
      [lnum, col, strlen(label)])
    text ..= label
    col += strlen(label)
    text ..= ' '
    col += 1
  endif

  # parent directory path; the shorter of (a) relative-from-root (with ../ for
  # outside-root files) and (b) absolute path with ~ for home.
  var rel = ParentDisplay(fs.Parent(path), root)
  if !empty(rel)
    add(view.highlight_positions.working_files_paths, [lnum, col, strlen(rel)])
    text ..= rel
    col += strlen(rel)
  endif

  add(view.lines, text)
  view.line_index[string(lnum)] = {path: path, is_working: true}
enddef

def ParentDisplay(parent: string, root: string): string
  if parent ==# root
    return ''
  endif
  var rel = RelativeWithDotDot(parent, root)
  var abs = fnamemodify(parent, ':~')
  if !empty(rel) && strlen(rel) <= strlen(abs)
    return rel
  endif
  return abs
enddef

def RelativeWithDotDot(target: string, root: string): string
  if target ==# root
    return ''
  endif
  if root ==# '/'
    return target[1 :]
  endif
  var prefix = root .. '/'
  if stridx(target, prefix) == 0
    return target[strlen(prefix) :]
  endif

  # target is outside root: walk up to a common ancestor and back down.
  var target_parts = split(target, '/')
  var root_parts = split(root, '/')
  var common = 0
  while common < len(target_parts)
        && common < len(root_parts)
        && target_parts[common] ==# root_parts[common]
    common += 1
  endwhile
  var ups = len(root_parts) - common
  var down_parts = target_parts[common :]
  var ups_str = repeat('../', ups)
  if empty(down_parts)
    return substitute(ups_str, '/$', '', '')
  endif
  return ups_str .. join(down_parts, '/')
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
  view.line_index[string(lnum)] = {path: entry.path, is_working: false}
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
  AddMatch('V9FilerWorkingFilesHeader', positions.working_files_header, 10)
  AddMatch('V9FilerWorkingFilesPath', positions.working_files_paths, 10)
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
  highlight default link V9FilerWorkingFilesHeader Title
  highlight default link V9FilerWorkingFilesPath Comment
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
