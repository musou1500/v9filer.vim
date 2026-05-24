vim9script

import './tab_state.vim' as tab_state

# Move from the current (filer / Home) window to the window where files and
# Home should be opened. Falls back to opening a fresh vertical split to the
# right of the filer if no previously focused window is available.
export def MoveTo(): void
  var current_win = win_getid()
  var target_win = tab_state.LastFocusWinid()

  if target_win > 0 && target_win != current_win && !IsManaged(target_win)
    if win_gotoid(target_win)
      return
    endif
  endif

  win_gotoid(current_win)
  rightbelow vertical new
enddef

# A "managed" window is one v9filer renders into: the sidebar filer or the
# Home scratch buffer. MoveTo skips these when picking a target so files do
# not land inside them.
export def IsManaged(winid: number): bool
  var win = win_id2win(winid)
  if win <= 0
    return false
  endif
  var bufnr = winbufnr(win)
  if !empty(getbufvar(bufnr, 'v9filer_state', {}))
    return true
  endif
  if getbufvar(bufnr, 'v9filer_home', false)
    return true
  endif
  return false
enddef
