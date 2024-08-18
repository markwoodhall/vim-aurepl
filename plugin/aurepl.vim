if exists('g:loaded_aurepl') || &cp
  finish
endif

let g:loaded_aurepl = 1
let g:aurepl_repl_buffer_name = '__REPL__'

if !exists('g:aurepl_eval_on_type')
  let g:aurepl_eval_on_type = 0
endif
if !exists('g:aurepl_clean_on_move')
let g:aurepl_clean_on_move = 0
endif

let g:aurepl_warn_on_slow_expressions_regex = '(range\s*)\|(range)\|(repeat)\|(repeat\s*)\|(repeat\s*)\|(repeat\s*\w*)\|(repeat\s*\w*\s*)'
let g:aurepl_namespace = nvim_create_namespace('aurepl')

function! s:send_to_repl(expression)
  let out = ''
  let out_array = []
  if &ft ==# 'clojure'
    try
      let expressions = [a:expression]
      let out_array = []
      for e in expressions
        if e =~ g:aurepl_warn_on_slow_expressions_regex
          let out_array = out_array + ['warning: Ignoring infinite expression']
        else
          let ns = g:aurepl_default_ns_clojure
          if exists("g:cljreloaded_dev_ns")
            let ns = g:cljreloaded_dev_ns
          endif
          if exists("b:cljreloaded_dev_ns")
            let ns = b:cljreloaded_dev_ns
          endif
          redir => s:out
           silent call fireplace#echo_session_eval(join(split(e, '\\n'), ' '), {"ns": ns})
          redir END
          let out_array = out_array + split(s:out, '\n')
        endif
      endfor
    catch
      let out_array = ['error: ' . string(v:exception)]
    endtry
  endif
  return out_array
endfunction

function! s:clean_up()
  let bnr = bufnr('%')
  let counter = 1
  for line in getline(0, '$')
    call nvim_buf_del_extmark(bnr, g:aurepl_namespace, counter)
    let counter = counter + 1
  endfor
  call nvim_win_close(g:aurepl_window, v:true)
endfunction

function! s:expression_to_repl()
  let original_clean = g:aurepl_clean_on_move
  let g:aurepl_clean_on_move = 0
  let sel_save = &selection
  let cb_save = &clipboard
  let reg_save = @@
  set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
  try
    let open = '[[{(]'
    let close = '[]})]'
    if getline('.')[col('.')-1] =~# close
      let [line1, col1] = searchpairpos(open, '', close, 'bn', g:fireplace#skip)
      let [line2, col2] = [line('.'), col('.')]
    else
      let [line1, col1] = searchpairpos(open, '', close, 'bcn', g:fireplace#skip)
      let [line2, col2] = searchpairpos(open, '', close, 'n', g:fireplace#skip)
    endif
    while col1 > 1 && getline(line1)[col1-2] =~# '[#''`~@]'
      let col1 -= 1
    endwhile
    call setpos("'[", [0, line1, col1, 0])
    call setpos("']", [0, line2, col2, 0])
    silent exe "normal! `[v`]y"
    call s:lines_to_repl(@@, line2)
  finally
    let @@ = reg_save
    let &selection = sel_save
    let &clipboard = cb_save
    let g:aurepl_clean_on_move = 0
  endtry
endfunction

function! s:root_to_repl(line1, line2)
  if a:line2 < 0
    let open = '[[{(]'
    let close = '[]})]'
    let [line1, col1] = searchpairpos(open, '', close, 'bcrn', g:fireplace#skip)
    let [line2, col2] = searchpairpos(open, '', close, 'rn', g:fireplace#skip)
    if !line1 && !line2
      let [line1, col1] = searchpairpos(open, '', close, 'brn', g:fireplace#skip)
      let [line2, col2] = searchpairpos(open, '', close, 'crn', g:fireplace#skip)
    endif
    while col1 > 1 && getline(line1)[col1-2] =~# '[#''`~@]'
      let col1 -= 1
    endwhile
  else
    let line1 = a:line1
    let line2 = a:line2
    let col1 = 1
    let col2 = strlen(getline(line2))
  endif
  if !line1 || !line2
    return ''
  endif
  if line1 == line2
    let expr = getline(line1)[col1-1 : col2-1]
    call s:lines_to_repl(expr, line2)
  else
    let expr = getline(line1)[col1-1 : -1] . "\n"
          \ . join(map(getline(line1+1, line2-1), 'v:val . "\n"'))
          \ . getline(line2)[0 : col2-1]
    call s:lines_to_repl(expr, line2)
  endif
endfunction

function! s:line_to_repl()
  call s:lines_to_repl(join(getline('.', '.'), '\n'), getpos('.')[1])
endfunction

function! s:buf_to_repl()
  call s:lines_to_repl(join(getline('^', '$'), '\n'), getpos('$')[1])
endfunction

function! s:lines_to_repl(expression, endline)
  let out = s:send_to_repl(a:expression)
  let buff = nvim_create_buf(v:false, v:true)
  let height = len(out)
  let width = 0

  for i in out
    let length = len(i)
    if length > width
      let width = length
    endif
  endfor

  if width > 180
    let width = 180
  else
    let width = width + 6
  endif

  if height > 30
    let height = 30
  endif

  let g:aurepl_window = nvim_open_win(buff, v:true, {'relative': 'cursor', 'row': -1, 'col': 1, 'width': width, 'height': height, 'border': 'none'})

  call nvim_buf_set_option(buff, 'filetype', 'clojure')
  call nvim_buf_set_lines(buff, 0, -1, v:false, out)
endfunction

autocmd FileType clojure command! -buffer ExpressionToRepl :call s:expression_to_repl()
autocmd FileType clojure command! -buffer RootToRepl :call s:root_to_repl(<line1>, <count>)
autocmd FileType clojure command! -buffer LineToRepl :call s:line_to_repl()
autocmd FileType clojure command! -buffer BufToRepl :call s:buf_to_repl()

autocmd FileType clojure command! -buffer ExpressionHide :call s:clean_up()

autocmd CursorMoved *.clj,*.clj[cs] if g:aurepl_clean_on_move == 1 | call s:clean_up() | endif
autocmd CursorMovedI *.clj,*.clj[cs] if g:aurepl_eval_on_type == 1 | call s:root_to_repl(0, -1) | endif

autocmd BufEnter *.clj,*.clj[cs] hi csEval guifg=#ccc guibg=#658168
autocmd BufEnter *.clj,*.clj[cs] hi csEvalError guifg=#ccc guibg=#895768
autocmd BufEnter *.clj,*.clj[cs] hi csEvalWarn guifg=#ccc guibg=#333
