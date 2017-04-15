if exists('g:loaded_csrepl') || &cp
  finish
endif

let g:loaded_csrepl = 1

if !exists('g:csrepl_eval_inline')
  let g:csrepl_eval_inline = 1
endif

if !exists('g:csrepl_use_commmand')
  let g:csrepl_use_command = 'csharp'
endif

function! s:SendToRepl(data)
  call writefile(a:data, 'scratch.temp.cs')
  let out = system(g:csrepl_use_command . ' scratch.temp.cs')
  call delete('scratch.temp.cs')
  let out = split(out, '\n')
  return out
endfunction

function! s:SelectionToRepl() range
  let old_reg = getreg('"')
  let old_regtype = getregtype('"')
  let old_clipboard = &clipboard
  set clipboard&
  normal! ""gvy
  let selection = getreg('"')
  call setreg('"', old_reg, old_regtype)
  let &clipboard = old_clipboard
  let out = s:SendToRepl([selection])
  for m in out
      echomsg m
  endfor
endfunction

function! s:LineToRepl()
  "let line = split(getline('.'), ' // $csr ')[0]
  "let out = s:SendToRepl([line])
  "for m in out
  "    if g:csrepl_eval_inline
  "        call setline('.', line .' // $csr '.m)
  "    else
  "        echomsg m
  "    endif
  "endfor
endfunction

function! s:FileToRepl()
  let lines = getline(0, '$')
  call writefile(lines, 'scratch.temp.cs')
  let out = s:SendToRepl(lines)
  for m in out
      echomsg m
  endfor
endfunction

function! s:CsRepl()
  vsplit __cs_repl.cs
    setlocal filetype=cs
    call append(getline('$'), ['//~~~~~~~~ csharp repl buffer ~~~~~~~~//'])
endfunction

autocmd filetype cs command! -buffer CsRepl :exe s:CsRepl()
autocmd filetype cs command! -buffer FileToRepl :exe s:FileToRepl()
autocmd filetype cs command! -buffer LineToRepl :exe s:LineToRepl()
autocmd filetype cs command! -buffer -range SelectionToRepl :exe s:SelectionToRepl()

"autocmd BufWritePre *.cs silent! %s/\/\/\s\$csr.*//g

autocmd filetype cs nnoremap <buffer> <silent> csr :CsRepl<CR>
autocmd filetype cs nnoremap <buffer> <silent> cpf :FileToRepl<CR>
autocmd filetype cs nnoremap <buffer> <silent> cpp :LineToRepl<CR>
autocmd filetype cs vnoremap <buffer> <silent> cpp :SelectionToRepl<CR>
