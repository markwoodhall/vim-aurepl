function! s:should_bind()
  return &ft ==# 'javascript'
endfunction

function! s:should_bind_as_you_type()
  let should_bind = s:should_bind()
  let should_bind = should_bind && (expand('%') == g:aurepl_repl_buffer_name . '.js' || g:aurepl_eval_on_type_in_all_buffers)
  return should_bind
endfunction

autocmd filetype cs command! -buffer Namespaces :exe s:Namespaces()
autocmd filetype markdown command! -buffer NamespaceUnderCursor :exe s:TagUnderCursor('namespace')
autocmd filetype markdown command! -buffer TypeUnderCursor :exe s:TagUnderCursor('type')

if g:aurepl_eval_on_type == 1
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() && getline('.')[-1:-1] == ';' | silent! call aurepl#file_to_repl() | endif
endif

autocmd BufWritePre,BufLeave *.js execute "silent! %s/".g:aurepl_comment_regex."//g"

autocmd BufEnter * if s:should_bind() | let g:aurepl_eval_inline_position = 'lastline' | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval	"//= .*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError		"//= .*: .*$" | endif

autocmd BufEnter * if !exists('b:aurepl_use_command') && s:should_bind() | let b:aurepl_use_command = 'node --eval "$(cat ./scratch.temp.js)" --print' | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind() | let b:aurepl_comment_regex = g:aurepl_comment_regex   | endif
autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format | endif
