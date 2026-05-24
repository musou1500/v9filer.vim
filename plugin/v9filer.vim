vim9script

if exists('g:loaded_v9filer')
  finish
endif
g:loaded_v9filer = true

import '../autoload/v9filer.vim' as v9filer
import '../autoload/v9filer/actions.vim' as actions
import '../autoload/v9filer/home.vim' as home

command! -nargs=* -complete=dir V9Filer v9filer.Open(<q-args>)
command! -nargs=* -complete=dir Filer v9filer.Open(<q-args>)
command! V9FilerReveal v9filer.RevealCurrentFile()
command! V9FilerHome v9filer.OpenHome()

# <Plug> mappings — the stable surface for users to remap. The global default
# mappings below and the buffer-local mappings inside the sidebar / Home
# buffers all delegate to these names.

# Global
nnoremap <silent> <Plug>(V9FilerToggle)            <ScriptCmd>v9filer.Toggle('')<CR>
nnoremap <silent> <Plug>(V9FilerToggleHere)        <ScriptCmd>v9filer.Toggle(v9filer.CurrentFileDir())<CR>
nnoremap <silent> <Plug>(V9FilerReveal)            <ScriptCmd>v9filer.RevealCurrentFile()<CR>
nnoremap <silent> <Plug>(V9FilerOpenHome)          <ScriptCmd>v9filer.OpenHome()<CR>

# Sidebar buffer actions
nnoremap <silent> <Plug>(V9FilerOpenOrExpand)      <ScriptCmd>actions.OpenOrExpand()<CR>
nnoremap <silent> <Plug>(V9FilerChangeRoot)        <ScriptCmd>actions.ChangeRootUnderCursor()<CR>
nnoremap <silent> <Plug>(V9FilerGoParent)          <ScriptCmd>actions.GoParent()<CR>
nnoremap <silent> <Plug>(V9FilerOpenVertical)      <ScriptCmd>actions.OpenVertical()<CR>
nnoremap <silent> <Plug>(V9FilerOpenHorizontal)    <ScriptCmd>actions.OpenHorizontal()<CR>
nnoremap <silent> <Plug>(V9FilerOpenInNewTab)      <ScriptCmd>v9filer.OpenInNewTab()<CR>
nnoremap <silent> <Plug>(V9FilerDelete)            <ScriptCmd>actions.DeleteUnderCursor()<CR>
nnoremap <silent> <Plug>(V9FilerRename)            <ScriptCmd>actions.RenameUnderCursor()<CR>
nnoremap <silent> <Plug>(V9FilerCreate)            <ScriptCmd>actions.CreateUnderCursor()<CR>
nnoremap <silent> <Plug>(V9FilerToggleHidden)      <ScriptCmd>actions.ToggleHidden()<CR>
nnoremap <silent> <Plug>(V9FilerRefresh)           <ScriptCmd>actions.Refresh()<CR>
nnoremap <silent> <Plug>(V9FilerYankPath)          <ScriptCmd>actions.YankPath()<CR>
nnoremap <silent> <Plug>(V9FilerRemoveWorkingFile) <ScriptCmd>actions.RemoveWorkingFile()<CR>
nnoremap <silent> <Plug>(V9FilerToggleHelp)        <ScriptCmd>actions.ToggleHelp()<CR>
nnoremap <silent> <Plug>(V9FilerClose)             <ScriptCmd>actions.Close()<CR>

# Home buffer actions
nnoremap <silent> <Plug>(V9FilerHomeOpen)           <ScriptCmd>home.JumpFromCursor('edit')<CR>
nnoremap <silent> <Plug>(V9FilerHomeOpenHorizontal) <ScriptCmd>home.JumpFromCursor('horizontal')<CR>
nnoremap <silent> <Plug>(V9FilerHomeOpenVertical)   <ScriptCmd>home.JumpFromCursor('vertical')<CR>
nnoremap <silent> <Plug>(V9FilerHomeOpenInNewTab)   <ScriptCmd>home.JumpFromCursor('tab')<CR>
nnoremap <silent> <Plug>(V9FilerHomeRefresh)        <ScriptCmd>home.Refresh()<CR>
nnoremap <silent> <Plug>(V9FilerHomeClose)          <ScriptCmd>home.Close()<CR>

if !get(g:, 'v9filer_no_default_mappings', false)
  silent! nmap <unique> <Leader>ee <Plug>(V9FilerToggle)
  silent! nmap <unique> <Leader>et <Plug>(V9FilerToggleHere)
  silent! nmap <unique> <Leader>ef <Plug>(V9FilerReveal)
endif

augroup v9filer_auto_reveal
  autocmd!
  autocmd BufEnter * v9filer.AutoReveal()
augroup END

augroup v9filer_buf_win_enter
  autocmd!
  autocmd BufWinEnter * v9filer.OnBufWinEnter()
augroup END

augroup v9filer_focus
  autocmd!
  autocmd WinEnter * v9filer.RememberFocusWindow()
augroup END

augroup v9filer_buf_wipe
  autocmd!
  autocmd BufWipeout * v9filer.OnBufWipeout(str2nr(expand('<abuf>')))
augroup END

augroup v9filer_buf_win_leave
  autocmd!
  autocmd BufWinLeave * v9filer.OnBufWinLeave(str2nr(expand('<abuf>')))
augroup END

augroup v9filer_startup
  autocmd!
  autocmd VimEnter * ++nested v9filer.OpenHomeOnStartup()
augroup END
