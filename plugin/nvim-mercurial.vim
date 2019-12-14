" Search help for 'Writing a filetype plugin' for more information.

" I'm not sure if I want to do this at all. Maybe for the deployed plugin.
" Only do this when not done yet for this buffer
"if exists("b:did_mercurial_plugin")
"  finish
"endif
"let b:did_mercurial_plugin = 1

lua nvimmercurial = require("nvimmercurial")

command! Hstatus lua nvimmercurial.status.open()
command! Hlog lua nvimmercurial.graphlog.open()

nmap <silent> <Space>hst :Hstatus<CR>
nmap <silent> <Space>hl  :Hlog<CR>
nmap <silent> <Space>hrm :call mercurial#Resolve()<CR>
nmap <silent> <Space>hhec :silent !hg histedit --continue<CR>
nmap <silent> <Space>ham :call mercurial#Amend()<CR>
nmap <silent> <Space>hsu :call mercurial#SyncUpload()<CR>
nmap <silent> <Space>huc :silent !hg uploadchain<CR>

augroup nvimmercurial_hgstatus
  au!
  autocmd FileType hgstatus nnoremap <silent> <buffer> <Space> :lua nvimmercurial.status.toggle_file_select()<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> a :lua nvimmercurial.status.add_file()<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> r :lua nvimmercurial.status.revert_file()<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> h? :help mercurial-maps<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> gf :lua nvimmercurial.status.go_status_file()<CR>

  " The different kinds of ways to quit the hgstatus window.
  autocmd FileType hgstatus nnoremap <silent> <buffer> <ESC> :bd<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> <C-C> :bd<CR>
  autocmd FileType hgstatus nnoremap <silent> <buffer> q :bd<CR>
augroup END

augroup nvimmercurial_hglog
  au!
  autocmd FileType hglog nnoremap <buffer> <silent> <ESC> :bd<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> <C-c> :bd<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> q :bd<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> u :lua nvimmercurial.graphlog.update()<CR>
  autocmd FileType hglog nnoremap <buffer> h gg/\v[@ox]  [0-9a-f]* .*p4head<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> { :lua nvimmercurial.graphlog.move_backward()<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> [[ :lua nvimmercurial.graphlog.move_backward()<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> } :lua nvimmercurial.graphlog.move_forward()<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> ]] :lua nvimmercurial.graphlog.move_forward()<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> zo :lua nvimmercurial.graphlog.fold_open()<CR>
  autocmd FileType hglog nnoremap <buffer> <silent> zc :lua nvimmercurial.graphlog.fold_close()<CR>
augroup END

" Special behavior when editing hgcommit messages.
augroup nvimmercurial_hgcommit
  au!
  autocmd FileType hgcommit nnoremap <buffer> <silent> <C-c>  ggdG:wq<CR>
  autocmd FileType hgcommit nnoremap <buffer> <silent> gr  /^R=<CR>:nohlsearch<CR>$T=
  autocmd FileType hgcommit nnoremap <buffer> <silent> cir  /^R=<CR>f=:nohlsearch<CR>C=
  autocmd FileType hgcommit nnoremap <buffer> <silent> dir  /^R=<CR>f=:nohlsearch<CR>C=<ESC>
  autocmd FileType hgcommit nnoremap <buffer> <silent> gb  /^BUG=<CR>:nohlsearch<CR>$T=
  autocmd FileType hgcommit nnoremap <buffer> <silent> cib  /^BUG=<CR>f=:nohlsearch<CR>C=
  autocmd FileType hgcommit nnoremap <buffer> <silent> dib  /^BUG=<CR>f=:nohlsearch<CR>C=<ESC>
  autocmd FileType hgcommit nnoremap <buffer> <silent> gt  /^TESTED=<CR>:nohlsearch<CR>$T=
  autocmd FileType hgcommit nnoremap <buffer> <silent> cit  /^TESTED=<CR>f=:nohlsearch<CR>C=
  autocmd FileType hgcommit nnoremap <buffer> <silent> dit  /^TESTED=<CR>f=:nohlsearch<CR>C=<ESC>
  autocmd FileType hgcommit nnoremap <buffer> <silent> gc  /^CC=<CR>:nohlsearch<CR>$T=
  autocmd FileType hgcommit nnoremap <buffer> <silent> cic  /^CC=<CR>f=:nohlsearch<CR>C=
  autocmd FileType hgcommit nnoremap <buffer> <silent> dic  /^CC=<CR>f=:nohlsearch<CR>C=<ESC>
augroup END


" Used as a callback for setting the fold text for hglog buffers.
function! MercurialFoldText()
  let line = getline(v:foldstart)
  let sub = substitute(line, '/\*\|\*/\|{{{\d\=', '', 'g')
  return sub
endfunction

