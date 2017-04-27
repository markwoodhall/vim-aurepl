let g:aurepl_comment_format_clojure = ';;='
let g:aurepl_comment_regex_clojure = ';;=\s.*'
let g:aurepl_expression_start_clojure = '^(\|^\['

autocmd filetype clojurep command! -buffer ExpressionToRepl :call aurepl#expression_to_repl()

function! s:should_bind()
  return &ft ==# 'clojure'
endfunction

function! s:should_bind_as_you_type()
  let should_bind = s:should_bind()
  let should_bind = should_bind && (expand('%') == g:aurepl_repl_buffer_name . '.clj' || g:aurepl_eval_on_type_in_all_buffers)
  return should_bind
endfunction

if g:aurepl_eval_on_type == 1
  autocmd InsertEnter * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(1) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | silent! call aurepl#expression_to_repl() | endif
endif

autocmd BufWritePre,BufLeave *.clj,*.cljs,*.cljc execute "silent! %s/".g:aurepl_comment_regex_clojure."//g"

autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format_clojure | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind()  | let b:aurepl_comment_regex = g:aurepl_comment_regex_clojure   | endif
autocmd BufEnter * if !exists('b:aurepl_expression_start') && s:should_bind() | let b:aurepl_expression_start = g:aurepl_expression_start_clojure | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval ";;= .*$" | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalWarn ";;= warning: .*$" | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError	";;= error.*$" | endif
