let g:aurepl_comment_format_fs = '//>'
let g:aurepl_comment_regex_fs = '\/\/>\s.*'
let g:aurepl_expression_start_fs = '^\w\|^\['

function! s:should_bind()
  return &ft ==# 'fsharp'
endfunction

function! s:should_bind_as_you_type()
  let should_bind = s:should_bind()
  let should_bind = should_bind && (expand('%') == g:aurepl_repl_buffer_name . '.fsx' || g:aurepl_eval_on_type_in_all_buffers)
  return should_bind
endfunction

if g:aurepl_eval_on_type == 1
  autocmd InsertEnter * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(1) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type()  && !aurepl#supress_eval(line('.')) | silent! call aurepl#expression_to_repl() | endif
endif

autocmd filetype fsharp command! -buffer ExpressionToRepl :call aurepl#expression_to_repl()
autocmd BufWritePre,BufLeave *.fs,*.fsx execute "silent! %s/".g:aurepl_comment_regex_fs."//g"

autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format_fs | endif
autocmd BufEnter * if !exists('b:aurepl_expression_start') && s:should_bind() | let b:aurepl_expression_start = g:aurepl_expression_start_fs | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind() | let b:aurepl_comment_regex = g:aurepl_comment_regex_fs | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval	"//> .*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError "//> .*: error.*$" | endif
