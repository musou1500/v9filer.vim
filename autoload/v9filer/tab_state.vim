vim9script

# Tab-local variables for v9filer.
# All access to t:v9filer_* should go through this module.
#
# t:v9filer_buf              — buffer number of the active filer in this tab.
#                              System bookkeeping (pointer to a Vim resource);
#                              not part of the persistent UI state because the
#                              buffer is ephemeral (bufhidden=wipe).
# t:v9filer_id               — monotonically increasing identifier allocated on
#                              the first Open() in this tab. Used to give the
#                              ephemeral filer buffer a unique name across
#                              tabs (`v9filer #<id>`), so that no two tabs can
#                              ever collide on buffer name (E95).
# t:v9filer_root             — sidebar root (normalized absolute path).
# t:v9filer_expanded         — dict<bool>; abs dir path -> true if expanded.
# t:v9filer_show_hidden      — bool; whether dotfiles are listed.
# t:v9filer_help             — bool; whether the quick-help row is shown.
#                              The four variables above form the persistent
#                              UI state for this tab. They survive the
#                              ephemeral buffer being wiped (`q` then
#                              `:V9Filer` restores the previous view).
#                              `t:v9filer_root` is the canonical "this tab is
#                              a filer-using tab" marker (see HasState).
# t:v9filer_opening          — guard flag set while creating the filer window,
#                              so that RememberFocusWindow does not record the
#                              filer itself as the last-focused window.
# t:v9filer_last_focus_winid — winid to return to when opening a file from
#                              the filer.
# t:v9filer_working_files    — list of normalized absolute paths shown in the
#                              Working Files section (insertion order). Kept
#                              separate from the UI state above because
#                              tracking starts on any normal-file BufWinEnter
#                              (even before :V9Filer is invoked in this tab).

var next_id: number = 1

export def Buf(): number
  return get(t:, 'v9filer_buf', -1)
enddef

export def SetBuf(bufnr: number): void
  t:v9filer_buf = bufnr
enddef

export def UnsetBuf(): void
  unlet! t:v9filer_buf
enddef

export def Id(): number
  return get(t:, 'v9filer_id', 0)
enddef

export def HasId(): bool
  return exists('t:v9filer_id')
enddef

export def AllocateId(): number
  if !exists('t:v9filer_id')
    t:v9filer_id = next_id
    next_id += 1
  endif
  return t:v9filer_id
enddef

export def InitState(root: string): void
  t:v9filer_root = root
  t:v9filer_expanded = {}
  t:v9filer_show_hidden = get(g:, 'v9filer_show_hidden', true)
  t:v9filer_help = false
enddef

export def HasState(): bool
  return exists('t:v9filer_root')
enddef

export def ClearState(): void
  unlet! t:v9filer_root
  unlet! t:v9filer_expanded
  unlet! t:v9filer_show_hidden
  unlet! t:v9filer_help
enddef

export def Root(): string
  return get(t:, 'v9filer_root', '')
enddef

export def Expanded(): dict<any>
  return get(t:, 'v9filer_expanded', {})
enddef

export def ShowHidden(): bool
  return get(t:, 'v9filer_show_hidden', false)
enddef

export def HelpEnabled(): bool
  return get(t:, 'v9filer_help', false)
enddef

export def SetRoot(root: string): void
  t:v9filer_root = root
enddef

export def ToggleHidden(): void
  t:v9filer_show_hidden = !ShowHidden()
enddef

export def ToggleHelp(): void
  t:v9filer_help = !HelpEnabled()
enddef

export def ToggleExpanded(path: string): void
  var expanded = Expanded()
  if get(expanded, path, false)
    remove(expanded, path)
  else
    expanded[path] = true
  endif
  t:v9filer_expanded = expanded
enddef

export def ExpandPaths(paths: list<string>): void
  var expanded = Expanded()
  for path in paths
    expanded[path] = true
  endfor
  t:v9filer_expanded = expanded
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
