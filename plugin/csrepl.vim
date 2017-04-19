if exists('g:loaded_csrepl') || &cp
  finish
endif

let g:loaded_csrepl = 1
let g:csrepl_node_command = 'node --eval "$(cat ./scratch.temp.js)" --print'
let g:csrepl_cs_command = 'csharp ./scratch.temp.cs'

let g:csrepl_comment_format = ' //='
let g:csrepl_comment_format_fs = ' //>'
let g:csrepl_comment_format_vim = ' "@='
let g:csrepl_comment_format_clojure = ' ;;='
let g:csrepl_comment_regex = '\s\/\/=\s.*'
let g:csrepl_comment_regex_fs = '\s\/\/>\s.*'
let g:csrepl_comment_regex_vim = '\s"@=\s.*'
let g:csrepl_comment_regex_clojure = '\s;;=\s.*'

if !exists('g:csrepl_eval_inline')
  let g:csrepl_eval_inline = 1
endif

function! s:VimEval(data)
  let out = ''
  for d in a:data
    try
      let d = eval(d)
      let out = out . string(d) . "\n"
    catch
      let out = out . 'error ' . v:exception . "\n"
    endtry  
  endfor
  return out
endfunction

function! s:SendToRepl(data)
  let clean_data = []
  for d in a:data
    for line in split(d, '\n')
      let clean = substitute(line, b:csrepl_comment_regex, '', 'g')
      let clean_data = clean_data + [clean]
    endfor
  endfor
  if exists('b:csrepl_use_command') && executable(split(b:csrepl_use_command, ' ')[0])
    call writefile(clean_data, 'scratch.temp.'.expand('%:e'))
    let out = system(b:csrepl_use_command)
    call delete('scratch.temp.'.expand('%:e'))
  else
    if &ft ==# 'vim'
      let out = s:VimEval(clean_data)
    endif
    if &ft ==# 'clojure'
      let out = fireplace#session_eval(join(clean_data, ''), {"ns": "user"})
    endif

    if &ft ==# 'fsharp'
      redir => s:out
      silent call fsharpbinding#python#FsiEval(join(clean_data, "\n"))
      redir END
      let out = s:out
    endif
  let out = split(out, '\n')
  return out
endfunction

function! s:NotForOutput(line_number)
  let line = split(getline(a:line_number), b:csrepl_comment_format)
  let prev_line = split(getline(a:line_number-1), b:csrepl_comment_format)
  let next_line =  split(getline(a:line_number+1), b:csrepl_comment_format)

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
      call setline(counter, split(getline(counter), b:csrepl_comment_format)[0] . b:csrepl_comment_format .' '.m)
    else
      echomsg m
    endif
    let counter = (counter < lastline) ? counter + 1 : counter
  endfor
endfunction

function! s:LineToRepl()
  let line = split(getline('.'), b:csrepl_comment_format)[0]
  let out = s:SendToRepl([line])
  for m in out
    if g:csrepl_eval_inline
      call setline('.', line . b:csrepl_comment_format .' '.m)
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
      call setline(counter, split(getline(counter), b:csrepl_comment_format)[0] . b:csrepl_comment_format .' '.m)
    else
       echomsg m
    endif
    let counter = (counter < lastline) ? counter + 1 : counter
  endfor
endfunction

function! s:Repl(repl_type)
  execute 'vsplit __REPL-'.a:repl_type
    setlocal filetype=cs
    let b:csrepl_use_command = g:csrepl_cs_command
    if a:repl_type == 'javascript'
      setlocal filetype=javascript
      let b:csrepl_use_command = g:csrepl_node_command
    endif
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
    let b:csrepl_use_command = g:csrepl_cs_command
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
    let b:csrepl_use_command = g:csrepl_cs_command
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
    let b:csrepl_use_command = g:csrepl_cs_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
endfunction

autocmd filetype * command! -buffer CsRepl :exe s:Repl('cs')
autocmd filetype * command! -buffer JsRepl :exe s:Repl('javascript')
autocmd filetype * command! -buffer FileToRepl :call s:FileToRepl()
autocmd filetype * command! -buffer LineToRepl :call s:LineToRepl()
autocmd filetype * command! -buffer -range SelectionToRepl let b:winview = winsaveview() | call s:SelectionToRepl() | call winrestview(b:winview)

autocmd filetype cs command! -buffer Namespaces :exe s:Namespaces()
autocmd filetype markdown command! -buffer NamespaceUnderCursor :exe s:TagUnderCursor('namespace')
autocmd filetype markdown command! -buffer TypeUnderCursor :exe s:TagUnderCursor('type')

autocmd BufWritePre *.cs,*.js silent! %s/\s\/\/=\s.*//g
autocmd BufLeave *.cs,*.js silent! %s/\s\/\/=\s.*//g

autocmd BufWritePre *.fs,*.fsx silent! %s/\s\/\/>\s.*//g
autocmd BufLeave *.fs,*.fsx silent! %s/\s\/\/>\s.*//g

autocmd BufWritePre *.vim silent! %s/\s"@=\s.*//g
autocmd BufLeave *.vim silent! %s/\s"@=\s.*//g

autocmd BufWritePre *.clj,*.cljs,*.cljc silent! %s/\s;;=\s.*//g
autocmd BufLeave *.clj,*.cljs,*.cljc silent! %s/\s;;=\s.*//g

autocmd filetype * nnoremap <silent> csr :CsRepl<CR>
autocmd filetype * nnoremap <silent> cpf :FileToRepl<CR>
autocmd filetype * nnoremap <silent> cpl :LineToRepl<CR>
autocmd filetype * vnoremap <silent> cps :SelectionToRepl<CR>

autocmd BufEnter * if !exists('b:csrepl_use_command') && &ft ==# 'javascript' | let b:csrepl_use_command = g:csrepl_node_command | endif
autocmd BufEnter * if !exists('b:csrepl_use_command') && &ft ==# 'cs' | let b:csrepl_use_command = g:csrepl_cs_command | endif

autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'javascript' | let b:csrepl_comment_format = g:csrepl_comment_format | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'cs' | let b:csrepl_comment_format = g:csrepl_comment_format | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'fsharp' | let b:csrepl_comment_format = g:csrepl_comment_format_fs | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'vim' | let b:csrepl_comment_format = g:csrepl_comment_format_vim | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'clojure' | let b:csrepl_comment_format = g:csrepl_comment_format_clojure | endif

autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'javascript' | let b:csrepl_comment_regex = g:csrepl_comment_regex | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'cs' | let b:csrepl_comment_regex = g:csrepl_comment_regex | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'fsharp' | let b:csrepl_comment_regex = g:csrepl_comment_regex_fs | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'vim' | let b:csrepl_comment_regex = g:csrepl_comment_regex_vim | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'clojure' | let b:csrepl_comment_regex = g:csrepl_comment_regex_clojure | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEval	"//= .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'vim' | syn match csEval	"\"@= .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure' | syn match csEval	";;= .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp' | syn match csEval	"//> .*$" | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEvalError		"//= (\d,\d): error.*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'vim' | syn match csEvalError		"\"@= error.*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure' | syn match csEvalError		";;= error.*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp' | syn match csEvalError		"//> .*: error.*$" | endif
autocmd InsertLeave,BufEnter * syn match csZshError		"//= zsh:\d: .*$"
autocmd InsertLeave,BufEnter * syn match csBashError		"//= bash:\d: .*$"

autocmd BufEnter * hi csEval guibg=#343d46 guifg=#99c794
autocmd BufEnter * hi csEvalError guibg=#343d46 guifg=#ec5f67
autocmd BufEnter * hi csZshError guibg=#343d46 guifg=#ec5f67
autocmd BufEnter * hi csBashError guibg=#343d46 guifg=#ec5f67
