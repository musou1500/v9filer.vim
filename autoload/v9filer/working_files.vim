vim9script

# Working files list (one per tab). Storage lives in tab_state as
# t:v9filer_working_files; this module owns the higher-level CRUD logic
# (normalization, dedup, window-closing on remove).
# Files are added on BufWinEnter for normal file buffers, and removed
# explicitly via the filer's `x` mapping.

import './buf_state.vim' as buf_state
import './tab_state.vim' as tab_state
import './fs.vim' as fs

export def List(): list<string>
  return tab_state.WorkingFiles()
enddef

export def Contains(path: string): bool
  return index(List(), path) >= 0
enddef

export def Add(path: string): void
  if empty(path)
    return
  endif
  var normalized = fs.Normalize(path)
  var current = List()
  if index(current, normalized) >= 0
    return
  endif
  current += [normalized]
  tab_state.SetWorkingFiles(current)
enddef

export def Remove(path: string): void
  if empty(path)
    return
  endif
  var normalized = fs.Normalize(path)
  var current = List()
  var idx = index(current, normalized)
  if idx < 0
    return
  endif
  remove(current, idx)
  tab_state.SetWorkingFiles(current)
  CloseWindowsForPath(normalized)
enddef

export def HandleBufWinEnter(): void
  if !IsTrackable()
    return
  endif
  var path = expand('%:p')
  if empty(path) || isdirectory(path) || !filereadable(path)
    return
  endif
  Add(path)
enddef

def IsTrackable(): bool
  if &buftype !=# ''
    return false
  endif
  if buf_state.Has()
    return false
  endif
  if empty(bufname('%'))
    return false
  endif
  return true
enddef

def CloseWindowsForPath(path: string): void
  var info = gettabinfo(tabpagenr())
  if empty(info)
    return
  endif
  for winid in info[0].windows
    var winnr = win_id2win(winid)
    if winnr <= 0
      continue
    endif
    var name = bufname(winbufnr(winnr))
    if empty(name)
      continue
    endif
    if fs.Normalize(fnamemodify(name, ':p')) ==# path
      try
        win_execute(winid, 'close')
      catch
      endtry
    endif
  endfor
enddef
