vim9script

# Tab-local variables for v9filer.
# All access to t:v9filer_* should go through this module.
#
# t:v9filer_buf              — buffer number of the active filer in this tab
# t:v9filer_opening          — guard flag set while creating the filer window,
#                              so that RememberFocusWindow does not record the
#                              filer itself as the last-focused window
# t:v9filer_last_focus_winid — winid to return to when opening a file from
#                              the filer
# t:v9filer_working_files    — list of normalized absolute paths shown in the
#                              Working Files section (insertion order)

export def Buf(): number
  return get(t:, 'v9filer_buf', -1)
enddef

export def HasBuf(): bool
  return exists('t:v9filer_buf') && bufexists(t:v9filer_buf)
enddef

export def SetBuf(bufnr: number): void
  t:v9filer_buf = bufnr
enddef

export def UnsetBuf(): void
  unlet! t:v9filer_buf
enddef

export def IsOpening(): bool
  return get(t:, 'v9filer_opening', false)
enddef

export def SetOpening(opening: bool): void
  if opening
    t:v9filer_opening = true
  else
    unlet! t:v9filer_opening
  endif
enddef

export def LastFocusWinid(): number
  return get(t:, 'v9filer_last_focus_winid', 0)
enddef

export def SetLastFocusWinid(winid: number): void
  t:v9filer_last_focus_winid = winid
enddef

export def WorkingFiles(): list<string>
  return get(t:, 'v9filer_working_files', [])
enddef

export def SetWorkingFiles(files: list<string>): void
  t:v9filer_working_files = files
enddef
