if !exists('g:aurepl_eval_inline_cs_experimental')
  let g:aurepl_eval_inline_cs_experimental = 1
endif

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
  let out = aurepl#send_to_repl(0, ['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Select(t => t.Namespace).Where(n => !string.IsNullOrEmpty(n)).Distinct()'])
  let namespaces = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# Namespaces', '', 'This is a current list of loaded namespaces, follow a namespace by pressing F on it.', '']
  for n in namespaces
    let lines = lines + ['## '.n]
  endfor
  let command = expand('%b') =~ '__Namespaces.cs' ? 'e' : 'split'
  let use_command = b:aurepl_use_command
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:aurepl_use_command = use_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :NamespaceUnderCursor<CR>
endfunction

function! s:Types(namespace)
  let out = aurepl#send_to_repl(0, ['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.Namespace == "'.a:namespace.'").Select(t => t.FullName).Distinct()'])
  let types = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# '.a:namespace, '', 'This is a list of types within the '.a:namespace.' namespace, follow a type by pressing F on it.', '']
  for t in types
    let lines = lines + ['## '.t]
  endfor
  let command = expand('%b') =~ '__Namespaces.cs' ? 'e' : 'split'
  let use_command = b:aurepl_use_command
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:aurepl_use_command = use_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :TypeUnderCursor<CR>
endfunction

function! s:Functions(typename)
  let out = aurepl#send_to_repl(0, [
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
  let command = expand('%b') =~ '__Namespaces.cs' ? 'e' : 'split'
  let use_command = b:aurepl_use_command
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:aurepl_use_command = use_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
endfunction

function! s:should_bind()
  return &ft ==# 'cs'
endfunction

function! s:should_bind_as_you_type()
  let should_bind = s:should_bind()
  let should_bind = should_bind && (expand('%') == g:aurepl_repl_buffer_name . '.cs' || g:aurepl_eval_on_type_in_all_buffers)
  return should_bind
endfunction

autocmd filetype cs command! -buffer Namespaces :exe s:Namespaces()
autocmd filetype markdown command! -buffer NamespaceUnderCursor :exe s:TagUnderCursor('namespace')
autocmd filetype markdown command! -buffer TypeUnderCursor :exe s:TagUnderCursor('type')

if g:aurepl_eval_on_type == 1
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() && getline('.')[-1:-1] == ';' | silent! call aurepl#file_to_repl() | endif
endif

autocmd BufWritePre,BufLeave *.cs execute "silent! %s/".g:aurepl_comment_regex."//g"

autocmd BufEnter * if s:should_bind() | let g:aurepl_eval_inline_position = 'inline' | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval	"//= .*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalIf	"//= →.*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalSwitch	"//= ⊃.*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalEvaluation	"//= ≡.*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError		"//= (\d,\d): error.*$" | endif

autocmd BufEnter * if !exists('b:aurepl_use_command') && s:should_bind()  | let b:aurepl_use_command = 'csharp ./scratch.temp.cs -warn:0' | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind()  | let b:aurepl_comment_regex = g:aurepl_comment_regex   | endif
autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format | endif
