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

function! s:suppress_eval(line_number)
  let line = getline(a:line_number)

  " Evaling with open quotes really hurts the underlying F# repl, so
  " always check for that first when deciding if we should suppress eval
  let in_quotes = (len(substitute(line, '\v[^"]', '', 'g')) % 2) == 1
  if in_quotes
    return 1
  endif

  let parts = split(line, b:aurepl_comment_format) 
  if len(parts) > 0
    if matchstr(parts[0], '=$\|=\s*$') != ''
      return 1
    endif
  endif

  if matchstr(line, '^open\s\w.*') != ''
    return 0
  endif

  let next_line = getline(a:line_number+1)
  let prev_line = getline(a:line_number-1)

  let indented = matchstr(line, '^\s\s\s\s*.*') != ''
  let next_indented = matchstr(next_line, '^\s\s\s\s*.*') != ''

  if !indented && !next_indented
    return 0
  endif

  let next_piped = matchstr(next_line, '^\s*|>.*\||>.*') != ''
  let prev_piped = matchstr(prev_line, '^\s*|>.*\||>.*') != ''
  return next_indented || next_piped || prev_piped
endfunction

if g:aurepl_eval_on_type == 1
  autocmd InsertEnter * if s:should_bind_as_you_type() | call aurepl#clean_line(0) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type() | call aurepl#clean_line(1) | endif
  autocmd CursorMoved,CursorMovedI,InsertLeave * if s:should_bind_as_you_type()  && !s:suppress_eval(line('.')) | silent! call aurepl#expression_to_repl(1) | endif
endif

autocmd filetype fsharp command! -buffer ExpressionToRepl :call aurepl#expression_to_repl(0)

autocmd BufEnter * if !exists('b:aurepl_comment_format') && s:should_bind() | let b:aurepl_comment_format = g:aurepl_comment_format_fs | endif
autocmd BufEnter * if !exists('b:aurepl_expression_start') && s:should_bind() | let b:aurepl_expression_start = g:aurepl_expression_start_fs | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && s:should_bind() | let b:aurepl_comment_regex = g:aurepl_comment_regex_fs | endif

autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEval	"//> .*$"  | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalWarn "//> warning: .*$" | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalWarn "//> no-out: .*$" | endif
autocmd InsertLeave,BufEnter * if s:should_bind() | syn match csEvalError "//> .*: error.*$\|//> .*Exception.*" | endif
