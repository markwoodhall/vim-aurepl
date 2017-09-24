let g:aurepl_comment_format_elm = '--'
let g:aurepl_comment_regex_elm = '--\s.*'
let g:aurepl_expression_start_fs = '^\w\|^\['

function! s:should_bind()
  return &ft ==# 'elm'
endfunction

let g:aurepl_elm_started = 0
if g:aurepl_elm_started == 0
  let g:aurepl_elm_output_file = tempname()
  call jobstart('(while [ 1 ]; do sleep 1; done) |  elm-repl 2>&1 | tee -a ' . g:aurepl_elm_output_file . ' &')
  let g:aurepl_elm_pid = split(system('sleep 5; ps -ef | grep -i "/home/.*cabal-sandbox/bin/elm-repl$" | sort +4 | tail -n 1 | grep -o "[0-9]\{1,10\}" | head -n 1'), '\n')[0]
  let g:aurepl_elm_started = 1
endif

function! s:should_bind_as_you_type()
  let should_bind = s:should_bind()
  let should_bind = should_bind && (expand('%') == g:aurepl_repl_buffer_name . '.elm' || g:aurepl_eval_on_type_in_all_buffers)
  return should_bind
endfunction

autocmd filetype elm command! -buffer ExpressionToRepl :call aurepl#expression_to_repl(0)

if g:aurepl_eval_on_type == 1
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMovedI,InsertLeave * if s:should_bind_as_you_type() && getline('.')[-1:-1] == ';' | silent! call aurepl#file_to_repl() | endif
endif

autocmd BufWritePre,BufLeave *.elm execute "silent! %s/".g:aurepl_comment_regex."//g"

autocmd BufEnter * if s:should_bind() | let g:aurepl_eval_inline_position = 'lastline' | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval	"-- .*: .*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError		"-- --.*$" | endif

autocmd BufEnter * if !exists('b:aurepl_use_command') && s:should_bind() | let b:aurepl_use_command = 'echo ; outputfile=' . g:aurepl_elm_output_file . ';pid=' . g:aurepl_elm_pid . '; echo $(cat ./scratch.temp.elm) > /proc/$pid/fd/0 && sleep 1 && (while [ `tail -n 1 $outputfile | grep -o "\s:\s*"` ]; do sleep 1; done) && tail -n 2 $outputfile | head -n 1' | endif
autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format_elm | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind()  | let b:aurepl_comment_regex = g:aurepl_comment_regex_elm   | endif
