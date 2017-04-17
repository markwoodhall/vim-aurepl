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

  let result = line !~ 'var\s.*$'
  let result = result && line !~ '\w.\s=\s.*$'
  let result = result && (line !~ 'foreach.*(.*$' || (line =~ 'do.*$' && next_line !~ '{.*'))
  let result = result && (line !~ 'while.*(.*$' || (line =~ 'do.*$' && next_line !~ '{.*'))
  let result = result && (line !~ 'switch.*(.*$' || (line =~ 'do.*$' && next_line !~ '{.*'))
  let result = result && (line !~ 'do.*$' || (line =~ 'do.*$' && next_line !~ '{.*'))
  let result = result && line !~ 'for.*(.*$'
  let result = result && line !~ 'public.*$'
  let result = result && line !~ 'private.*$'
  let result = result && line !~ 'using.*$'
  let result = result && line !~ 'Func<.*$'
  let result = result && line !~ '{.*$'
  let result = result && line !~ '}.*$'
  let result = result && line !~ '^\..*$'
  let result = result && prev_line !~ '{.*$' && next_line !~ '}.*'
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

function! s:TagUnderCursor(tagtype)
  let line = getline('.')
  let line = substitute(line, '##\s', '', 'g')
  if a:tagtype == 'namespace'
    call s:Types(line)
  endif

  if a:tagtype == 'type'
    call s:Functions(line)
  endif
endfunction

function! s:Namespaces()
  let out = s:SendToRepl(['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Select(t => t.Namespace).Where(n => !string.IsNullOrEmpty(n)).Distinct()'])
  let namespaces = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# Namespaces', '', 'This is a current list of loaded namespaces, follow a namespace by pressing F on it.', '']
  for n in namespaces
    let lines = lines + ['## '.n]
  endfor
  let command = expand('%b') =~ '__Namespaces' ? 'e' : 'split'
  execute command '__Namespaces'
    setlocal filetype=markdown
    setlocal buftype=nofile
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :NamespaceUnderCursor<CR>
endfunction

function! s:Types(namespace)
  let out = s:SendToRepl(['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.Namespace == "'.a:namespace.'").Select(t => t.FullName).Distinct()'])
  let types = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# '.a:namespace, '', 'This is a list of types within the '.a:namespace.' namespace, follow a type by pressing F on it.', '']
  for t in types
    let lines = lines + ['## '.t]
  endfor
  let command = expand('%b') =~ '__Namespaces' ? 'e' : 'split'
  execute command '__Namespaces'
    setlocal filetype=markdown
    setlocal buftype=nofile
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :TypeUnderCursor<CR>
endfunction

function! s:Functions(typename)
  let out = s:SendToRepl([
        \ 'using System.Reflection;', 
        \ 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.FullName == "'.a:typename.'").SelectMany(t => t.GetConstructors()).Where(m => m.IsPublic).Select(m => m.ToString()).Distinct()',
        \ 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.FullName == "'.a:typename.'").SelectMany(t => t.GetMethods()).Where(m => m.IsPublic).Select(m => m.ToString()).Distinct()',
        \ 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.FullName == "'.a:typename.'").SelectMany(t => t.GetProperties()).Where(m => m.CanRead || m.CanWrite).Select(m => m.ToString()).Distinct()'])
  let constructors = eval(substitute(substitute(out[-3], '{', '[', 'g'), '}', ']', 'g'))
  let functions = eval(substitute(substitute(out[-2], '{', '[', 'g'), '}', ']', 'g'))
  let properties = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# '.a:typename, '', '## Constructors', '']
  for con in constructors
    let lines = lines + ['  > '.con]
  endfor
  let lines = lines + ['', '## Functions', '']
  for f in functions
    let lines = lines + ['  > '.f]
  endfor
  let lines = lines + ['', '## Properties', '']
  for p in properties
    let lines = lines + ['  > '.p]
  endfor
  let command = expand('%b') =~ '__Namespaces' ? 'e' : 'split'
  execute command '__Namespaces'
    setlocal filetype=markdown
    setlocal buftype=nofile
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
endfunction

autocmd filetype cs command! -buffer Namespaces :exe s:Namespaces()
autocmd filetype markdown command! -buffer NamespaceUnderCursor :exe s:TagUnderCursor('namespace')
autocmd filetype markdown command! -buffer TypeUnderCursor :exe s:TagUnderCursor('type')
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
