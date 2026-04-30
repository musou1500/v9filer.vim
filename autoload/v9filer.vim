vim9script

import './v9filer/state.vim' as state
import './v9filer/fs.vim' as fs
import './v9filer/render.vim' as render
import './v9filer/actions.vim' as actions

export def CurrentFileDir(): string
  var path = expand('%:p:h')
  return empty(path) ? getcwd() : path
enddef

export def Open(args: string = ''): void
  var parsed = ParseArgs(args)
  var root = fs.Normalize(parsed.root)
  if parsed.toggle
    Toggle(root)
  else
    OpenEmbedded(root)
  endif
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
  if !get(t:, 'v9filer_opening_toggle', false) && !IsFilerBuffer()
    t:v9filer_last_focus_winid = win_getid()
  endif
enddef

def IsFilerBuffer(): bool
  return state.Has()
enddef

# ParsedArgs is the internal result of :V9Filer argument parsing.
# {
#   toggle: bool,  # true when "-toggle" was present
#   root: string,  # raw directory argument before fs.Normalize()
# }
def ParseArgs(args: string): dict<any>
  var parts = empty(args) ? [] : split(args)
  var toggle = false
  var dir_parts: list<string> = []

  for part in parts
    if part ==# '-toggle'
      toggle = true
    else
      add(dir_parts, part)
    endif
  endfor

  return {
    toggle: toggle,
    root: empty(dir_parts) ? getcwd() : join(dir_parts, ' '),
  }
enddef

def OpenEmbedded(root: string): void
  var prev_buf = bufnr('%')
  enew
  SetupBuffer(root, 'embedded', prev_buf)
enddef

def Toggle(root: string): void
  RememberFocusWindow()

  if exists('t:v9filer_toggle_buf') && bufexists(t:v9filer_toggle_buf)
    var win = bufwinnr(t:v9filer_toggle_buf)
    if win != -1
      win_gotoid(win_getid(win))
      close
      return
    endif
  endif

  var width = get(g:, 'v9filer_width', 30)
  t:v9filer_opening_toggle = true
  try
    topleft vertical new
  finally
    unlet! t:v9filer_opening_toggle
  endtry
  execute 'vertical resize ' .. width
  setlocal winfixwidth
  t:v9filer_toggle_buf = bufnr('%')
  SetupBuffer(root, 'toggle', 0)
enddef

def SetupBuffer(root: string, mode: string, prev_buf: number): void
  execute 'file ' .. fnameescape('v9filer-' .. mode .. '://' .. root)
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nowrap
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal foldcolumn=0
  setlocal nomodifiable

  state.Set(state.New(root, mode, prev_buf))
  DefineBufferMappings()
  render.Refresh()
enddef

def DefineBufferMappings(): void
  nnoremap <buffer><silent> <CR> <ScriptCmd>actions.OpenOrToggle()<CR>
  nnoremap <buffer><silent> l <ScriptCmd>actions.ChangeRootUnderCursor()<CR>
  nnoremap <buffer><silent> - <ScriptCmd>actions.GoParent()<CR>
  nnoremap <buffer><silent> <BS> <ScriptCmd>actions.GoParent()<CR>
  nnoremap <buffer><silent> v <ScriptCmd>actions.OpenVertical()<CR>
  nnoremap <buffer><silent> s <ScriptCmd>actions.OpenHorizontal()<CR>
  nnoremap <buffer><silent> D <ScriptCmd>actions.DeleteUnderCursor()<CR>
  nnoremap <buffer><silent> r <ScriptCmd>actions.RenameUnderCursor()<CR>
  nnoremap <buffer><silent> % <ScriptCmd>actions.CreateInRoot()<CR>
  nnoremap <buffer><silent> . <ScriptCmd>actions.ToggleHidden()<CR>
  nnoremap <buffer><silent> R <ScriptCmd>actions.Refresh()<CR>
  nnoremap <buffer><silent> C <ScriptCmd>actions.LcdRoot()<CR>
  nnoremap <buffer><silent> y <ScriptCmd>actions.YankPath()<CR>
  nnoremap <buffer><silent> ? <ScriptCmd>actions.ToggleHelp()<CR>
  nnoremap <buffer><silent> q <ScriptCmd>actions.Close()<CR>
enddef

def Reveal(silent: bool): void
  if !exists('t:v9filer_toggle_buf') || !bufexists(t:v9filer_toggle_buf)
    return
  endif

  var target = expand('%:p')
  if empty(target)
    return
  endif
  target = fs.Normalize(target)

  var filer_win = bufwinnr(t:v9filer_toggle_buf)
  if filer_win == -1
    return
  endif

  var current_win = win_getid()
  win_gotoid(win_getid(filer_win))
  var root = state.Root()
  if !state.Has() || !fs.IsUnder(target, root)
    win_gotoid(current_win)
    return
  endif

  state.ExpandPaths(fs.Ancestors(target, root))
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
    if state.PathForLine(line_number) ==# path
      cursor(line_number, 1)
      return
    endif
  endfor
enddef
