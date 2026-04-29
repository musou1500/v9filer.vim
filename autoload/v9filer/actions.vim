vim9script

import './state.vim' as state
import './fs.vim' as fs
import './render.vim' as render

export def OpenOrToggle(): void
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  if fs.IsDir(path)
    ToggleDir(path)
  else
    OpenFile(path, 'edit')
  endif
enddef

export def ChangeRootUnderCursor(): void
  var path = PathUnderCursor()
  if !empty(path) && fs.IsDir(path)
    ChangeRoot(path)
  endif
enddef

export def GoParent(): void
  ChangeRoot(fs.Parent(state.Get().root))
enddef

export def OpenVertical(): void
  OpenPath('vertical')
enddef

export def OpenHorizontal(): void
  OpenPath('horizontal')
enddef

export def DeleteUnderCursor(): void
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  if confirm('Delete ' .. path .. '?', "&Yes\n&No", 2) == 1
    fs.Delete(path)
    render.Refresh()
  endif
enddef

export def RenameUnderCursor(): void
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  var new_name = input('Rename to: ', fnamemodify(path, ':t'))
  if !empty(new_name)
    fs.Rename(path, new_name)
    render.Refresh()
  endif
enddef

export def CreateInRoot(): void
  var name = input('New file or directory: ')
  if !empty(name)
    fs.Create(state.Get().root, name)
    render.Refresh()
  endif
enddef

export def ToggleHidden(): void
  var st = state.Get()
  st.show_hidden = !st.show_hidden
  state.Set(st)
  render.Refresh()
enddef

export def Refresh(): void
  render.Refresh()
enddef

export def LcdRoot(): void
  execute 'lcd ' .. fnameescape(state.Get().root)
enddef

export def YankPath(): void
  var path = PathUnderCursor()
  if empty(path)
    path = state.Get().root
  endif
  setreg('"', path)
  try
    setreg('+', path)
  catch
  endtry
  echo path
enddef

export def ToggleHelp(): void
  var st = state.Get()
  st.help = !st.help
  state.Set(st)
  render.Refresh()
enddef

export def Close(): void
  var st = state.Get()
  if get(st, 'mode', '') ==# 'toggle'
    if exists('t:v9filer_toggle_buf') && t:v9filer_toggle_buf == bufnr('%')
      unlet! t:v9filer_toggle_buf
    endif
    close
    return
  endif

  var prev_buf = get(st, 'prev_buf', 0)
  render.ClearHighlights()
  if prev_buf > 0 && bufexists(prev_buf)
    execute 'buffer ' .. prev_buf
  else
    enew
  endif
enddef

def OpenPath(kind: string): void
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  if fs.IsDir(path)
    ChangeRoot(path)
  else
    OpenFile(path, kind)
  endif
enddef

def ToggleDir(path: string): void
  var st = state.Get()
  var expanded = get(st, 'expanded', {})
  if get(expanded, path, false)
    remove(expanded, path)
  else
    expanded[path] = true
  endif
  st.expanded = expanded
  state.Set(st)
  render.Refresh()
enddef

def ChangeRoot(path: string): void
  var st = state.Get()
  st.root = fs.Normalize(path)
  st.expanded = {}
  state.Set(st)
  execute 'file ' .. fnameescape('v9filer-' .. st.mode .. '://' .. st.root)
  render.Refresh()
enddef

def OpenFile(path: string, kind: string): void
  var st = state.Get()
  if get(st, 'mode', '') ==# 'toggle'
    MoveToTargetWindow()
  elseif kind ==# 'edit'
    render.ClearHighlights()
  endif

  if kind ==# 'vertical'
    execute 'vertical split ' .. fnameescape(path)
  elseif kind ==# 'horizontal'
    execute 'split ' .. fnameescape(path)
  else
    execute 'edit ' .. fnameescape(path)
  endif
enddef

def MoveToTargetWindow(): void
  var filer_win = win_getid()
  var target_win = get(t:, 'v9filer_last_focus_winid', 0)

  if target_win > 0 && target_win != filer_win && !IsFilerWindow(target_win)
    if win_gotoid(target_win)
      return
    endif
  endif

  win_gotoid(filer_win)
  rightbelow vertical new
enddef

def IsFilerWindow(winid: number): bool
  var win = win_id2win(winid)
  return win > 0 && !empty(getbufvar(winbufnr(win), 'v9filer_state', {}))
enddef

def PathUnderCursor(): string
  var st = state.Get()
  return get(get(st, 'line_paths', {}), string(line('.')), '')
enddef
