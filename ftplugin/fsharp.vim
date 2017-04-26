let g:aurepl_comment_format_fs = '//>'
let g:aurepl_comment_regex_fs = '\/\/>\s.*'

let g:aurepl_expression_start_fs = '^\w\|^\['

if g:aurepl_eval_on_type == 1
  autocmd InsertEnter * if &ft ==# 'fsharp' | call aurepl#clean_line(0) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if &ft ==# 'fsharp' | call aurepl#clean_line(1) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if &ft ==# 'fsharp'  && !aurepl#supress_eval(line('.')) | silent! call aurepl#expression_to_repl() | endif
endif

autocmd filetype fsharp command! -buffer ExpressionToRepl :call aurepl#expression_to_repl()

autocmd BufWritePre,BufLeave *.fs,*.fsx execute "silent! %s/".g:aurepl_comment_regex_fs."//g"

autocmd BufEnter * if !exists('b:aurepl_comment_format') && &ft ==# 'fsharp'     | let b:aurepl_comment_format = g:aurepl_comment_format_fs      | endif
autocmd BufEnter * if !exists('b:aurepl_expression_start') && &ft ==# 'fsharp' | let b:aurepl_expression_start = g:aurepl_expression_start_fs | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && &ft ==# 'fsharp'     | let b:aurepl_comment_regex = g:aurepl_comment_regex_fs      | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp' | syn match csEval	"//> .*$"  | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp' | syn match csEvalError "//> .*: error.*$" | endif

autocmd BufEnter * if !exists('b:aurepl_comment_format') && &ft ==# 'fsharp' | let b:aurepl_comment_format = g:aurepl_comment_format_fs | endif
