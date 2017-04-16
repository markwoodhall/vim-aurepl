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
  let clean_data = []
  for d in a:data
    for line in split(d, '\n')
      let clean = substitute(line, '\s\/\/=\s.*', '', 'g')
      let clean_data = clean_data + [clean]
    endfor
  endfor
  call writefile(clean_data, 'scratch.temp.cs')
  let out = system(g:csrepl_use_command . ' scratch.temp.cs')
  call delete('scratch.temp.cs')
  let out = split(out, '\n')
  return out
endfunction

function! s:NotForOutput(line_number)
  let line = split(getline(a:line_number), ' //=')
  let prev_line = split(getline(a:line_number-1), ' //=')
  let next_line =  split(getline(a:line_number+1), ' //=')

  let line = len(line) == 0 ? '' : line[0]
  let prev_line = len(prev_line) == 0 ? '' : prev_line[0]
  let next_line = len(next_line) == 0 ? '' : next_line[0]

  let result = line !~ 'var.*$'
  let result = result && line !~ 'foreach.*(.*$'
  let result = result && line !~ 'while.*(.*$'
  let result = result && line !~ 'switch.*(.*$'
  let result = result && line !~ 'do.*$'
  let result = result && line !~ 'for.*(.*$'
  let result = result && line !~ 'public.*$'
  let result = result && line !~ 'private.*$'
  let result = result && line !~ 'Func<.*$'
  let result = result && line !~ '{.*$'
  let result = result && line !~ '}.*$'
  let result = result && prev_line !~ '{.*$' && next_line !~ '}.*'
  let result = result && next_line !~ '{.*'
  return result
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
  let firstline = getpos("'<")[1]
  let lastline = getpos("'>")[1]
  let counter = firstline
  for m in out
    if g:csrepl_eval_inline
      while counter < lastline && (substitute(getline(counter), '\w', '', 'g') == '' || !s:NotForOutput(counter))
        let counter = counter + 1
      endwhile
      call setline(counter, split(getline(counter), ' //=')[0] .' //= '.m)
    else
      echomsg m
    endif
    let counter = (counter < lastline) ? counter + 1 : counter
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
  let firstline = 0
  let lastline = line('$')
  let counter = firstline
  for m in out
    if g:csrepl_eval_inline
      while counter < lastline && (substitute(getline(counter), '\w', '', 'g') == '' || !s:NotForOutput(counter))
        let counter = counter + 1
      endwhile
      call setline(counter, split(getline(counter), ' //=')[0] .' //= '.m)
    else
       echomsg m
    endif
    let counter = (counter < lastline) ? counter + 1 : counter
  endfor
endfunction

function! s:CsRepl()
  vsplit __cs_repl
    setlocal filetype=cs
    setlocal readonly
endfunction

autocmd filetype cs command! -buffer CsRepl :exe s:CsRepl()
autocmd filetype cs command! -buffer FileToRepl :call s:FileToRepl()
autocmd filetype cs command! -buffer LineToRepl :call s:LineToRepl()
autocmd filetype cs command! -buffer -range SelectionToRepl let b:winview = winsaveview() | call s:SelectionToRepl() | call winrestview(b:winview)

autocmd BufWritePre *.cs silent! %s/\s\/\/=\s.*//g
autocmd BufLeave *.cs silent! %s/\s\/\/=\s.*//g

autocmd filetype cs nnoremap <silent> csr :CsRepl<CR>
autocmd filetype cs nnoremap <silent> cpf :FileToRepl<CR>
autocmd filetype cs nnoremap <silent> cpp :LineToRepl<CR>
autocmd filetype cs vnoremap <silent> cpp :SelectionToRepl<CR>
