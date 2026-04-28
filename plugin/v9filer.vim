vim9script

if exists('g:loaded_v9filer')
  finish
endif
g:loaded_v9filer = true

import '../autoload/v9filer.vim' as v9filer

command! -nargs=* -complete=dir V9Filer v9filer.Open(<q-args>)
command! -nargs=* -complete=dir Filer v9filer.Open(<q-args>)
command! V9FilerReveal v9filer.RevealCurrentFile()

if !get(g:, 'v9filer_no_default_mappings', false)
  nnoremap <silent> <Leader>ee <ScriptCmd>v9filer.Open('-toggle')<CR>
  nnoremap <silent> <Leader>eE <ScriptCmd>v9filer.Open('')<CR>
  nnoremap <silent> <Leader>et <ScriptCmd>v9filer.Open('-toggle ' .. v9filer.CurrentFileDir())<CR>
  nnoremap <silent> <Leader>eT <ScriptCmd>v9filer.Open(v9filer.CurrentFileDir())<CR>
  nnoremap <silent> <Leader>ef <ScriptCmd>v9filer.RevealCurrentFile()<CR>
endif

augroup v9filer_auto_reveal
  autocmd!
  autocmd BufEnter * v9filer.AutoReveal()
augroup END
