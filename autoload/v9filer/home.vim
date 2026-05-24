vim9script

import './tab_state.vim' as tab_state
import './target_window.vim' as target_window
import './git.vim' as git
import './todo.vim' as todo
import './icons.vim' as icons

# The Home view is a per-tab scratch buffer (`v9filer home #<id>`,
# bufhidden=wipe) rendered with setline. It is intentionally independent of
# the sidebar's render.Refresh pipeline: render.Refresh assumes a sidebar
# (tab_state.HasState) and a tree to draw, while Home has its own data
# sources (git.Summary + todo.Scan) and a different keymap surface.
#
# b:v9filer_home is the discriminator used by target_window.IsManaged and
# autoload/v9filer.vim's IsFilerBuffer so the Home window is excluded from
# "where to open a file" decisions.
#
# b:v9filer_home_lines maps 1-based buffer line numbers to
# {kind, abs_path, ?lnum}. kind is 'git_file' or 'todo'.

const SECTION_GIT = 'Git'
const SECTION_TODO = 'TODO'

# Section header glyphs used only when `g:v9filer_nerd_font_icons` is enabled.
# Trailing space puts visual padding between glyph and label.
const HEADER_ICON_HOME = ' '   # nf-fa-home
const HEADER_ICON_GIT  = ' '   # nf-fa-git
const HEADER_ICON_TODO = ' '   # nf-fa-tasks

# Kind -> short label used in the file list (`[M]`, `[+]`, `[D]`, `[!]`).
const STATUS_MARKER: dict<string> = {
  modified: '[M]',
  new:      '[+]',
  deleted:  '[D]',
  conflict: '[!]',
}

const STATUS_HIGHLIGHT: dict<string> = {
  modified: 'V9FilerHomeStatusModified',
  new:      'V9FilerHomeStatusNew',
  deleted:  'V9FilerHomeStatusDeleted',
  conflict: 'V9FilerHomeStatusConflict',
}

export def Open(kind: string): void
  if kind ==# 'tab'
    execute 'tabnew'
    LoadHomeBufferInCurrentWindow()
    return
  endif

  if kind ==# 'edit-here'
    LoadHomeBufferInCurrentWindow()
    return
  endif

  target_window.MoveTo()
  if kind ==# 'vertical'
    rightbelow vertical new
  elseif kind ==# 'horizontal'
    rightbelow new
  endif
  LoadHomeBufferInCurrentWindow()
enddef

export def Refresh(): void
  if !IsHomeBuffer()
    return
  endif
  Render()
enddef

export def IsHomeBuffer(): bool
  return get(b:, 'v9filer_home', false)
enddef

export def IsHomeBufferNr(bufnr: number): bool
  return getbufvar(bufnr, 'v9filer_home', false)
enddef

export def JumpFromCursor(open_mode: string): void
  if !IsHomeBuffer()
    return
  endif
  var entry = LineEntry(line('.'))
  if empty(entry)
    return
  endif
  OpenEntry(entry, open_mode)
enddef

export def Close(): void
  close
enddef

export def OnBufWipeout(bufnr: number): void
  if tab_state.HomeBuf() == bufnr
    tab_state.UnsetHomeBuf()
  endif
enddef

export def OnBufWinLeave(bufnr: number): void
  if !IsHomeBufferNr(bufnr)
    return
  endif
  # matchaddpos matches are window-local and survive buffer swaps (e.g.
  # `:edit <file>` replacing the Home buffer in-place). Without this hook,
  # the Home highlights would leak onto whatever buffer takes its place.
  ClearMatches()
enddef

def LoadHomeBufferInCurrentWindow(): void
  var existing = tab_state.HomeBuf()
  if existing > 0 && bufexists(existing)
    execute 'buffer ' .. existing
    Refresh()
    return
  endif

  enew
  tab_state.AllocateHomeId()
  tab_state.SetHomeBuf(bufnr('%'))
  SetupBuffer()
  Render()
enddef

def SetupBuffer(): void
  EnsureHighlightGroups()
  execute 'file ' .. fnameescape(printf('v9filer home #%d', tab_state.HomeId()))
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nowrap
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal foldcolumn=0
  setlocal filetype=v9filer_home
  b:v9filer_home = true
  b:v9filer_home_lines = {}
  DefineBufferMappings()
enddef

def DefineBufferMappings(): void
  nmap <buffer> <CR>  <Plug>(V9FilerHomeOpen)
  nmap <buffer> s     <Plug>(V9FilerHomeOpenHorizontal)
  nmap <buffer> v     <Plug>(V9FilerHomeOpenVertical)
  nmap <buffer> t     <Plug>(V9FilerHomeOpenInNewTab)
  nmap <buffer> R     <Plug>(V9FilerHomeRefresh)
  nmap <buffer> q     <Plug>(V9FilerHomeClose)
enddef

def Render(): void
  var root = ResolveRoot()
  var summary = git.Summary(root)
  var todos = todo.Scan(root)

  var view = {
    lines: [],
    line_index: {},
    matches: {
      header: [],
      section: [],
      branch: [],
      added: [],
      deleted: [],
      status_modified: [],
      status_new: [],
      status_deleted: [],
      status_conflict: [],
      todo_keyword: [],
      path: [],
      icons: {},
    },
  }

  RenderHeader(view)
  RenderGitSection(view, summary)
  RenderTodoSection(view, todos)

  Flush(view)
enddef

def ResolveRoot(): string
  if tab_state.HasState()
    return tab_state.Root()
  endif
  return getcwd()
enddef

def RenderHeader(view: dict<any>): void
  var prefix = icons.IconsEnabled() ? HEADER_ICON_HOME : ''
  var text = prefix .. 'V9Filer Home'
  add(view.lines, text)
  add(view.matches.header, [len(view.lines), 1, strlen(text)])
  add(view.lines, '')
enddef

def RenderGitSection(view: dict<any>, summary: dict<any>): void
  var section_prefix = icons.IconsEnabled() ? HEADER_ICON_GIT : ''
  var section_prefix_width = strlen(section_prefix)

  if !summary.ok
    var line = section_prefix .. 'Git: (not a git repository)'
    add(view.lines, line)
    var lnum = len(view.lines)
    add(view.matches.section, [lnum, section_prefix_width + 1, strlen('Git:')])
    add(view.lines, '')
    return
  endif

  # Header: <icon> Git: <branch>  +N -M  (K files)
  var header = section_prefix .. printf('Git: %s', summary.branch)
  var lnum_header = len(view.lines) + 1
  add(view.matches.section, [lnum_header, section_prefix_width + 1, strlen('Git:')])
  var branch_col = section_prefix_width + strlen('Git: ') + 1
  add(view.matches.branch, [lnum_header, branch_col, strlen(summary.branch)])

  var totals = summary.totals
  var added_str = '+' .. totals.added
  var deleted_str = '-' .. totals.deleted
  var files_str = printf('(%d files)', totals.files)

  var added_col = strlen(header) + 1 + 1  # +1 separator space
  header ..= '  ' .. added_str
  add(view.matches.added, [lnum_header, added_col + 1, strlen(added_str)])

  var deleted_col = strlen(header) + 1 + 1
  header ..= ' ' .. deleted_str
  add(view.matches.deleted, [lnum_header, deleted_col, strlen(deleted_str)])

  header ..= '  ' .. files_str
  add(view.lines, header)

  if empty(summary.files)
    add(view.lines, '  (no changes)')
    add(view.lines, '')
    return
  endif

  for file in summary.files
    RenderGitFileLine(view, file)
  endfor
  add(view.lines, '')
enddef

def RenderGitFileLine(view: dict<any>, file: dict<any>): void
  var marker = get(STATUS_MARKER, file.kind, '[?]')
  var hl = get(STATUS_HIGHLIGHT, file.kind, '')
  # `  [M] <icon>path  +N -M`
  # Icon text already carries its trailing space when present; when icons are
  # disabled it is empty and the row reduces to the previous `  [M] path` form.
  var prefix = '  ' .. marker .. ' '
  var icon = ResolveFileIcon(file.abs_path)
  var lnum = len(view.lines) + 1

  var marker_col = 3  # after the two leading spaces
  if !empty(hl)
    add(view.matches[StatusBucket(file.kind)], [lnum, marker_col, strlen(marker)])
  endif

  var line = prefix
  var icon_col = strlen(line) + 1
  line ..= icon.text
  RegisterIconHighlight(view, lnum, icon_col, icon)

  var path_col = strlen(line) + 1
  line ..= file.path
  add(view.matches.path, [lnum, path_col, strlen(file.path)])

  if file.added > 0 || file.deleted > 0
    line ..= '  '
    var added_str = '+' .. file.added
    var deleted_str = '-' .. file.deleted
    var added_col = strlen(line) + 1
    line ..= added_str
    add(view.matches.added, [lnum, added_col, strlen(added_str)])
    line ..= ' '
    var deleted_col = strlen(line) + 1
    line ..= deleted_str
    add(view.matches.deleted, [lnum, deleted_col, strlen(deleted_str)])
  endif

  add(view.lines, line)
  view.line_index[string(lnum)] = {
    kind: 'git_file',
    abs_path: file.abs_path,
  }
enddef

def StatusBucket(kind: string): string
  if kind ==# 'modified'
    return 'status_modified'
  elseif kind ==# 'new'
    return 'status_new'
  elseif kind ==# 'deleted'
    return 'status_deleted'
  elseif kind ==# 'conflict'
    return 'status_conflict'
  endif
  return 'status_modified'
enddef

def RenderTodoSection(view: dict<any>, todos: list<dict<any>>): void
  var prefix = icons.IconsEnabled() ? HEADER_ICON_TODO : ''
  var prefix_width = strlen(prefix)
  var heading_lnum = len(view.lines) + 1
  add(view.lines, prefix .. 'TODO:')
  add(view.matches.section, [heading_lnum, prefix_width + 1, strlen('TODO:')])

  if empty(todos)
    add(view.lines, '  (no TODO comments found)')
    return
  endif

  var root = ResolveRoot()
  for entry in todos
    RenderTodoEntry(view, entry, root)
  endfor
enddef

def RenderTodoEntry(view: dict<any>, entry: dict<any>, root: string): void
  var display_path = DisplayPath(entry.path, root)
  var icon = ResolveFileIcon(entry.path)
  var head_lnum = len(view.lines) + 1
  var head = '  '
  var icon_col = strlen(head) + 1
  head ..= icon.text
  RegisterIconHighlight(view, head_lnum, icon_col, icon)
  var path_col = strlen(head) + 1
  head ..= printf('%s:%d', display_path, entry.lnum)
  add(view.matches.path, [head_lnum, path_col, strlen(display_path) + 1 + strlen(string(entry.lnum))])
  add(view.lines, head)

  var body = '    ' .. entry.text
  var body_lnum = len(view.lines) + 1
  var keyword_col = stridx(entry.text, 'TODO')
  if keyword_col >= 0
    add(view.matches.todo_keyword, [body_lnum, 5 + keyword_col, strlen('TODO')])
  endif
  add(view.lines, body)

  view.line_index[string(head_lnum)] = {
    kind: 'todo',
    abs_path: entry.path,
    lnum: entry.lnum,
  }
  view.line_index[string(body_lnum)] = {
    kind: 'todo',
    abs_path: entry.path,
    lnum: entry.lnum,
  }
enddef

def ResolveFileIcon(abs_path: string): dict<string>
  return icons.Resolve({
    name: fnamemodify(abs_path, ':t'),
    is_dir: false,
    is_symlink: false,
    is_executable: false,
  })
enddef

def RegisterIconHighlight(view: dict<any>, lnum: number, col: number, icon: dict<string>): void
  var width = strlen(icon.text)
  if width <= 0
    return
  endif
  var group = icons.HighlightGroup(
    get(icon, 'color', ''),
    get(icons.KindFallbackGroup, get(icon, 'kind', 'file'), 'V9FilerIconFile')
  )
  if !has_key(view.matches.icons, group)
    view.matches.icons[group] = []
  endif
  add(view.matches.icons[group], [lnum, col, width])
enddef

def DisplayPath(abs_path: string, root: string): string
  if !empty(root) && abs_path ==# root
    return '.'
  endif
  if !empty(root) && strpart(abs_path, 0, strlen(root) + 1) ==# root .. '/'
    return abs_path[strlen(root) + 1 :]
  endif
  return fnamemodify(abs_path, ':~')
enddef

def Flush(view: dict<any>): void
  b:v9filer_home_lines = view.line_index

  var saved = winsaveview()
  setlocal modifiable
  silent! :%delete _
  setline(1, view.lines)
  setlocal nomodifiable
  setlocal nomodified
  ApplyMatches(view.matches)
  winrestview(saved)
enddef

def ApplyMatches(matches: dict<any>): void
  ClearMatches()
  if !get(g:, 'v9filer_use_colors', true)
    return
  endif
  ApplyBucket('V9FilerHomeHeader', matches.header)
  ApplyBucket('V9FilerHomeSection', matches.section)
  ApplyBucket('V9FilerHomeBranch', matches.branch)
  ApplyBucket('V9FilerHomeAdded', matches.added)
  ApplyBucket('V9FilerHomeDeleted', matches.deleted)
  ApplyBucket('V9FilerHomeStatusModified', matches.status_modified)
  ApplyBucket('V9FilerHomeStatusNew', matches.status_new)
  ApplyBucket('V9FilerHomeStatusDeleted', matches.status_deleted)
  ApplyBucket('V9FilerHomeStatusConflict', matches.status_conflict)
  ApplyBucket('V9FilerHomeTodoKeyword', matches.todo_keyword)
  ApplyBucket('V9FilerHomePath', matches.path)
  for [group, positions] in items(matches.icons)
    ApplyBucket(group, positions)
  endfor
enddef

def ApplyBucket(group: string, positions: list<any>): void
  if empty(positions)
    return
  endif
  # matchaddpos accepts up to 8 positions per call.
  var ids = get(w:, 'v9filer_home_match_ids', [])
  var index = 0
  while index < len(positions)
    var batch = positions[index : index + 7]
    add(ids, matchaddpos(group, batch))
    index += 8
  endwhile
  w:v9filer_home_match_ids = ids
enddef

def ClearMatches(): void
  for id in get(w:, 'v9filer_home_match_ids', [])
    silent! matchdelete(id)
  endfor
  w:v9filer_home_match_ids = []
enddef

def LineEntry(line_number: number): dict<any>
  return get(b:, 'v9filer_home_lines', {})
    ->get(string(line_number), {})
enddef

def OpenEntry(entry: dict<any>, open_mode: string): void
  if empty(entry)
    return
  endif

  if open_mode ==# 'tab'
    execute 'tabnew ' .. fnameescape(entry.abs_path)
    JumpToLnumIfTodo(entry)
    return
  endif

  if open_mode ==# 'horizontal' || open_mode ==# 'vertical'
    var split_cmd = open_mode ==# 'vertical' ? 'vertical split' : 'split'
    execute split_cmd .. ' ' .. fnameescape(entry.abs_path)
    JumpToLnumIfTodo(entry)
    return
  endif

  # `edit` overrides the current Home window. The Home buffer is wiped
  # (bufhidden=wipe) which is fine — the user has found what they wanted.
  execute 'edit ' .. fnameescape(entry.abs_path)
  JumpToLnumIfTodo(entry)
enddef

def JumpToLnumIfTodo(entry: dict<any>): void
  if entry.kind ==# 'todo'
    cursor(entry.lnum, 1)
  endif
enddef

def EnsureHighlightGroups(): void
  highlight default link V9FilerHomeHeader Title
  highlight default link V9FilerHomeSection Statement
  highlight default link V9FilerHomeBranch Identifier
  highlight default link V9FilerHomeAdded DiffAdd
  highlight default link V9FilerHomeDeleted DiffDelete
  highlight default link V9FilerHomeStatusModified WarningMsg
  highlight default link V9FilerHomeStatusNew MoreMsg
  highlight default link V9FilerHomeStatusDeleted ErrorMsg
  highlight default link V9FilerHomeStatusConflict ErrorMsg
  highlight default link V9FilerHomeTodoKeyword Todo
  highlight default link V9FilerHomePath Directory
  # Icon kind fallbacks. The sidebar render pipeline defines the same groups;
  # duplicating the `highlight default link` here keeps Home self-sufficient
  # when it is opened before the sidebar has rendered in the current session.
  highlight default link V9FilerIconDirectory Directory
  highlight default link V9FilerIconExecutable Statement
  highlight default link V9FilerIconFile Normal
enddef
