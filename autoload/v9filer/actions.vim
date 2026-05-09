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
  ChangeRoot(fs.Parent(state.Root()))
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
  if confirm(DeletePrompt(path), "&Yes\n&No", 2) == 1
    try
      fs.Delete(path)
    catch
      echoerr v:exception
      return
    endtry
    render.Refresh()
  endif
enddef

export def RenameUnderCursor(): void
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  var new_name: string
  try
    new_name = input('Rename to: ', fnamemodify(path, ':t'))
  catch /^Vim:Interrupt$/
    return
  endtry
  if empty(new_name)
    return
  endif
  var target = fs.RenameTarget(path, new_name)
  if path ==# target
    return
  endif
  if fs.Exists(target) && !ConfirmOverwrite(target)
    return
  endif
  try
    fs.Rename(path, target)
  catch
    echoerr v:exception
    return
  endtry
  render.Refresh()
enddef

export def CreateInRoot(): void
  var name: string
  try
    name = input('New file or directory: ')
  catch /^Vim:Interrupt$/
    return
  endtry
  if empty(name)
    return
  endif
  var target = fs.CreateTarget(state.Root(), name)
  if isdirectory(target)
    echo target .. ' already exists'
    return
  endif
  if fs.Exists(target) && !ConfirmOverwrite(target)
    return
  endif
  try
    fs.Create(state.Root(), name)
  catch
    echoerr v:exception
    return
  endtry
  render.Refresh()
enddef

export def ToggleHidden(): void
  state.ToggleHidden()
  render.Refresh()
enddef

export def Refresh(): void
  render.Refresh()
enddef

export def YankPath(): void
  var path = PathUnderCursor()
  if empty(path)
    path = state.Root()
  endif
  setreg('"', path)
  if has('clipboard_working')
    if &clipboard =~# '\<unnamedplus\>'
      setreg('+', path)
    endif
    if &clipboard =~# '\<unnamed\>'
      setreg('*', path)
    endif
  endif
  echo path
enddef

export def ToggleHelp(): void
  state.ToggleHelp()
  render.Refresh()
enddef

export def Close(): void
  if exists('t:v9filer_buf') && t:v9filer_buf == bufnr('%')
    unlet! t:v9filer_buf
  endif
  close
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
  state.ToggleExpanded(path)
  render.Refresh()
enddef

def ChangeRoot(path: string): void
  var root = fs.Normalize(path)
  state.SetRoot(root)
  execute 'file ' .. fnameescape('v9filer://' .. root)
  execute 'tcd ' .. fnameescape(root)
  render.Refresh()
enddef

def OpenFile(path: string, kind: string): void
  MoveToTargetWindow()

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
  return state.PathForLine(line('.'))
enddef

def DeletePrompt(path: string): string
  # Directories use Vim's `delete(_, 'rf')` which recursively removes
  # everything underneath, so warn the user before they confirm.
  if isdirectory(path) && getftype(path) !=# 'link'
    return 'WARNING: recursively delete ' .. path .. ' and all its contents?'
  endif
  return 'Delete ' .. path .. '?'
enddef

def ConfirmOverwrite(path: string): bool
  return confirm('Overwrite ' .. path .. '?', "&Yes\n&No", 2) == 1
enddef
