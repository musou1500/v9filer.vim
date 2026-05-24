vim9script

import './v9filer/buf_state.vim' as buf_state
import './v9filer/tab_state.vim' as tab_state
import './v9filer/fs.vim' as fs
import './v9filer/render.vim' as render
import './v9filer/actions.vim' as actions
import './v9filer/working_files.vim' as working_files
import './v9filer/home.vim' as home

export def CurrentFileDir(): string
  var path = expand('%:p:h')
  return empty(path) ? getcwd() : path
enddef

export def Toggle(args: string = ''): void
  if tab_state.HasState() && bufwinnr(tab_state.Buf()) != -1
    var current = win_getid()
    win_gotoid(win_getid(bufwinnr(tab_state.Buf())))
    close
    if win_id2win(current) != 0
      win_gotoid(current)
    endif
    return
  endif
  Open(args)
enddef

export def Open(args: string = ''): void
  var root = fs.Normalize(empty(args) ? getcwd() : args)
  # Snapshot the current window before any navigation below. The WinEnter
  # autocmd normally keeps t:v9filer_last_focus_winid up to date, but it does
  # not fire for the initial window at Vim startup nor for the first window
  # of a freshly-created tab — so we record it explicitly here.
  RememberFocusWindow()

  if !tab_state.HasState()
    tab_state.AllocateId()
    tab_state.InitState(root)
  elseif tab_state.Root() !=# root
    tab_state.SetRoot(root)
  endif

  var existing_win = bufwinnr(tab_state.Buf())
  if existing_win != -1
    win_gotoid(win_getid(existing_win))
    render.Refresh()
    return
  endif

  var width = get(g:, 'v9filer_width', 30)
  # `topleft vertical new` below fires WinEnter on the new window before
  # SetupBuffer() runs, so IsFilerBuffer() cannot yet recognize it as the
  # filer. Guard the WinEnter handler so RememberFocusWindow does not record
  # the filer window itself as the last-focused window.
  tab_state.SetOpening(true)
  try
    topleft vertical new
  finally
    tab_state.SetOpening(false)
  endtry
  execute 'vertical resize ' .. width
  setlocal winfixwidth

  tab_state.SetBuf(bufnr('%'))
  SetupBuffer()
  render.Refresh()
enddef

export def RevealCurrentFile(): void
  Reveal(false)
enddef

export def AutoReveal(): void
  if get(g:, 'v9filer_auto_reveal', false)
    Reveal(true)
  endif
enddef

export def RememberFocusWindow(): void
  if !tab_state.IsOpening() && !IsFilerBuffer() && !home.IsHomeBuffer()
    tab_state.SetLastFocusWinid(win_getid())
  endif
enddef

export def OpenHome(): void
  if !tab_state.HasState()
    # No sidebar in this tab — open Home in the current window rather than
    # splitting off an unrelated one.
    home.Open('edit-here')
    return
  endif
  home.Open('edit')
enddef

# Invoked on VimEnter. Opens both the sidebar and Home when:
#   - `g:v9filer_open_home_on_startup` is truthy, AND
#   - Vim was started with no file arguments, AND
#   - the initial buffer is still the empty, unnamed default (so stdin pipes,
#     `vim -c 'edit foo'`, session restores, etc. are left alone).
export def OpenHomeOnStartup(): void
  if !get(g:, 'v9filer_open_home_on_startup', true)
    return
  endif
  if argc() != 0
    return
  endif
  if !empty(bufname('%')) || &buftype !=# '' || line('$') > 1 || !empty(getline(1))
    return
  endif
  Open('')
  OpenHome()
enddef

export def OnBufWinEnter(): void
  working_files.HandleBufWinEnter()
  RefreshFilerIfVisible()
enddef

export def OnBufWipeout(bufnr: number): void
  if tab_state.Buf() == bufnr
    tab_state.UnsetBuf()
  endif
  home.OnBufWipeout(bufnr)
enddef

export def OnBufWinLeave(bufnr: number): void
  home.OnBufWinLeave(bufnr)
enddef

def RefreshFilerIfVisible(): void
  var winnr = bufwinnr(tab_state.Buf())
  if winnr == -1
    return
  endif
  var current = win_getid()
  win_gotoid(win_getid(winnr))
  try
    render.Refresh()
  finally
    win_gotoid(current)
  endtry
enddef

export def OpenInNewTab(): void
  if buf_state.IsHomeLine(line('.'))
    home.Open('tab')
    return
  endif
  var path = buf_state.PathForLine(line('.'))
  if empty(path)
    return
  endif
  if fs.IsDir(path)
    var root = fs.Normalize(path)
    execute 'tabnew'
    execute 'tcd ' .. fnameescape(root)
    Open(root)
  else
    execute 'tabnew ' .. fnameescape(path)
    execute 'tcd ' .. fnameescape(fs.Parent(path))
  endif
enddef

def IsFilerBuffer(): bool
  # Home buffers also set b:v9filer_state when they reuse the render
  # infrastructure — they don't, but the explicit exclusion makes the
  # contract obvious.
  return buf_state.Has() && !home.IsHomeBuffer()
enddef

def SetupBuffer(): void
  execute 'file ' .. fnameescape(printf('v9filer #%d', tab_state.Id()))
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nowrap
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal foldcolumn=0
  setlocal nomodifiable

  buf_state.Set(buf_state.New())
  DefineBufferMappings()
enddef

def DefineBufferMappings(): void
  nmap <buffer> <CR>  <Plug>(V9FilerOpenOrExpand)
  nmap <buffer> l     <Plug>(V9FilerChangeRoot)
  nmap <buffer> -     <Plug>(V9FilerGoParent)
  nmap <buffer> <BS>  <Plug>(V9FilerGoParent)
  nmap <buffer> v     <Plug>(V9FilerOpenVertical)
  nmap <buffer> s     <Plug>(V9FilerOpenHorizontal)
  nmap <buffer> t     <Plug>(V9FilerOpenInNewTab)
  nmap <buffer> D     <Plug>(V9FilerDelete)
  nmap <buffer> r     <Plug>(V9FilerRename)
  nmap <buffer> %     <Plug>(V9FilerCreate)
  nmap <buffer> .     <Plug>(V9FilerToggleHidden)
  nmap <buffer> R     <Plug>(V9FilerRefresh)
  nmap <buffer> y     <Plug>(V9FilerYankPath)
  nmap <buffer> x     <Plug>(V9FilerRemoveWorkingFile)
  nmap <buffer> ?     <Plug>(V9FilerToggleHelp)
  nmap <buffer> q     <Plug>(V9FilerClose)
enddef

def Reveal(silent: bool): void
  var filer_win = bufwinnr(tab_state.Buf())
  if filer_win == -1
    return
  endif

  var target = expand('%:p')
  if empty(target)
    return
  endif
  target = fs.Normalize(target)

  var current_win = win_getid()
  win_gotoid(win_getid(filer_win))
  var root = tab_state.Root()
  if !tab_state.HasState() || !fs.IsUnder(target, root)
    win_gotoid(current_win)
    return
  endif

  tab_state.ExpandPaths(fs.Ancestors(target, root))
  render.Refresh()
  MoveCursorToPath(target)
  if !silent
    redraw
  endif
  win_gotoid(current_win)
enddef

def MoveCursorToPath(path: string): void
  var line_count = line('$')
  for line_number in range(1, line_count)
    if buf_state.TreePathForLine(line_number) ==# path
      cursor(line_number, 1)
      return
    endif
  endfor
enddef
