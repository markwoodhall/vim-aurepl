let g:aurepl_comment_format_clojure = ';;='
let g:aurepl_comment_regex_clojure = ';;=\s.*'
let g:aurepl_expression_start_clojure = '^(\|^\['

autocmd filetype clojurep command! -buffer ExpressionToRepl :call aurepl#expression_to_repl()

if g:aurepl_eval_on_type == 1
  autocmd InsertEnter * if &ft ==# 'clojure' | call aurepl#clean_line(0) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if &ft ==# 'clojure' | call aurepl#clean_line(1) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if &ft ==# 'clojure' | silent! call aurepl#expression_to_repl() | endif
endif

autocmd BufWritePre,BufLeave *.clj,*.cljs,*.cljc execute "silent! %s/".g:aurepl_comment_regex_clojure."//g"

autocmd BufEnter * if !exists('b:aurepl_comment_format') && &ft ==# 'clojure' | let b:aurepl_comment_format = g:aurepl_comment_format_clojure | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && &ft ==# 'clojure'  | let b:aurepl_comment_regex = g:aurepl_comment_regex_clojure   | endif
autocmd BufEnter * if !exists('b:aurepl_expression_start') && &ft ==# 'clojure' | let b:aurepl_expression_start = g:aurepl_expression_start_clojure | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'clojure' | syn match csEval ";;= .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure' | syn match csEvalWarn ";;= warning: .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure' | syn match csEvalError	";;= error.*$" | endif
