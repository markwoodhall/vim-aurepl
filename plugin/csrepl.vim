if exists('g:loaded_csrepl') || &cp
  finish
endif

let g:loaded_csrepl = 1

if !exists('g:csrepl_eval_inline')
  let g:csrepl_eval_inline = 1
endif

if !exists('g:csrepl_use_command')
  let g:csrepl_use_command = 'csharp'
endif

if !executable(g:csrepl_use_command)
  echoerr g:csrepl_use_command . ' is required but is not available.'
  finish
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
  silent normal! ""gvy
  let selection = getreg('"')
  call setreg('"', old_reg, old_regtype)
  let &clipboard = old_clipboard
  let out = s:SendToRepl([selection])
  for m in out
    echomsg m
  endfor
endfunction

function! s:LineToRepl()
  let line = split(getline('.'), ' //=')[0]
  let out = s:SendToRepl([line])
  for m in out
    if g:csrepl_eval_inline
       call setline('.', line .' //= '.m)
    else
       echomsg m
    endif
  endfor
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
autocmd filetype cs command! -buffer FileToRepl :call s:FileToRepl()
autocmd filetype cs command! -buffer LineToRepl :call s:LineToRepl()
autocmd filetype cs command! -buffer -range SelectionToRepl let b:winview = winsaveview() | call s:SelectionToRepl() | call winrestview(b:winview)

autocmd BufWritePre *.cs silent! %s/\/\/=\s.*//g

autocmd filetype cs nnoremap <silent> csr :CsRepl<CR>
autocmd filetype cs nnoremap <silent> cpf :FileToRepl<CR>
autocmd filetype cs nnoremap <silent> cpp :LineToRepl<CR>
autocmd filetype cs vnoremap <silent> cpp :SelectionToRepl<CR>
