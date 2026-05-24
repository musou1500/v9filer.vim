vim9script

import './buf_state.vim' as buf_state
import './tab_state.vim' as tab_state
import './fs.vim' as fs
import './render.vim' as render
import './working_files.vim' as working_files
import './target_window.vim' as target_window
import './home.vim' as home

export def OpenOrExpand(): void
  if buf_state.IsHomeLine(line('.'))
    home.Open('edit')
    return
  endif
  var path = PathUnderCursor()
  if empty(path)
    return
  endif
  if fs.IsDir(path)
    ExpandDir(path)
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
  ChangeRoot(fs.Parent(tab_state.Root()))
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

  # Directories use Vim's `delete(_, 'rf')` which recursively removes
  # everything underneath, so warn the user before they confirm.
  var warning_text = 'Delete ' .. path .. '?'
  if isdirectory(path) && getftype(path) !=# 'link'
    warning_text = 'WARNING: recursively delete ' .. path .. ' and all its contents?'
  endif

  if confirm(warning_text, "&Yes\n&No", 2) == 1
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

export def CreateUnderCursor(): void
  var name: string
  try
    name = input('New file or directory: ')
  catch /^Vim:Interrupt$/
    return
  endtry
  if empty(name)
    return
  endif

  var dest = PathUnderCursor()
  if empty(dest)
    dest = tab_state.Root()
  endif
  if !isdirectory(dest)
    dest = fs.Parent(dest)
  endif

  var target = fs.CreateTarget(dest, name)
  if isdirectory(target)
    echo target .. ' already exists'
    return
  endif
  if fs.Exists(target) && !ConfirmOverwrite(target)
    return
  endif
  try
    fs.Create(dest, name)
  catch
    echoerr v:exception
    return
  endtry
  render.Refresh()
enddef

export def ToggleHidden(): void
  tab_state.ToggleHidden()
  render.Refresh()
enddef

export def Refresh(): void
  render.Refresh()
enddef

export def YankPath(): void
  var path = PathUnderCursor()
  if empty(path)
    path = tab_state.Root()
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
  tab_state.ToggleHelp()
  render.Refresh()
enddef

export def Close(): void
  close
enddef

export def RemoveWorkingFile(): void
  var path = buf_state.WorkingFilePathForLine(line('.'))
  if empty(path)
    return
  endif
  working_files.Remove(path)
  render.Refresh()
enddef

def OpenPath(kind: string): void
  if buf_state.IsHomeLine(line('.'))
    home.Open(kind)
    return
  endif
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

def ExpandDir(path: string): void
  tab_state.ToggleExpanded(path)
  render.Refresh()
enddef

def ChangeRoot(path: string): void
  var root = fs.Normalize(path)
  tab_state.SetRoot(root)
  execute 'tcd ' .. fnameescape(root)
  render.Refresh()
enddef

def OpenFile(path: string, kind: string): void
  target_window.MoveTo()

  if kind ==# 'vertical'
    execute 'vertical split ' .. fnameescape(path)
  elseif kind ==# 'horizontal'
    execute 'split ' .. fnameescape(path)
  else
    execute 'edit ' .. fnameescape(path)
  endif
enddef

def PathUnderCursor(): string
  return buf_state.PathForLine(line('.'))
enddef

def ConfirmOverwrite(path: string): bool
  return confirm('Overwrite ' .. path .. '?', "&Yes\n&No", 2) == 1
enddef
