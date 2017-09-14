if exists('g:loaded_aurepl') || &cp
  finish
endif

let g:loaded_aurepl = 1
let g:aurepl_repl_buffer_name = '__REPL__'

let g:aurepl_comment_format = '//='
let g:aurepl_comment_format_vim = '"@='
let g:aurepl_comment_regex = '\/\/=\s.*'
let g:aurepl_comment_regex_vim = '"@=\s.*'

let g:aurepl_warn_on_slow_expressions_regex = '^\s(range)\|^(range)\|^(range\s*)'

let s:range_added = []

if !exists('g:aurepl_eval_inline')
  let g:aurepl_eval_inline = 1
endif

if !exists('g:aurepl_eval_inline_position')
  let g:aurepl_eval_inline_position = 'inline'
endif

if !exists('g:aurepl_eval_inline_collapse')
  let g:aurepl_eval_inline_collapse = 1
endif

if !exists('g:aurepl_eval_inline_max')
  let g:aurepl_eval_inline_max = 75
endif

if !exists('g:aurepl_eval_on_type')
  let g:aurepl_eval_on_type = 1
endif

if !exists('g:aurepl_eval_on_type_in_all_buffers')
  let g:aurepl_eval_on_type_in_all_buffers = 0
endif

function! s:vim_eval(data)
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

function! aurepl#send_to_repl(line_offset, data)
  let counter = 1 + a:line_offset
  let clean_data = []
  if &ft ==# 'cs'
    let clean_data = ['LoadAssembly("System.Web.Extensions");', 'using System.Web.Script.Serialization;', 'var aurepl_json_serializer = new JavaScriptSerializer();']
  endif
  for d in a:data
    for line in split(d, '\n')
      if exists('b:aurepl_comment_regex')
        let line = substitute(line, b:aurepl_comment_regex, '', 'g')
      endif
      if matchstr(line, '^\s*$')
        let counter += 1
      endif
     let clean_data = clean_data + [line]
     if a:line_offset > 0
       let counter += 1
     endif
    endfor
    let counter += 1
  endfor
  if exists('b:aurepl_use_command') && executable(split(b:aurepl_use_command, ' ')[0])
    call writefile(clean_data, 'scratch.temp.'.expand('%:e'))
    let out = system(b:aurepl_use_command)
    call delete('scratch.temp.'.expand('%:e'))
  else
    if &ft ==# 'vim'
      let out = s:vim_eval(clean_data)
    endif
    if &ft ==# 'clojure'
      try
        let expressions = []
        let out_array = []
        for d in clean_data
          if d =~ b:aurepl_expression_start
            let expressions = expressions + [[d]]
          else
            let last_expression = expressions[-1]
            let last_expression = last_expression + [d]
            let expressions[-1] = last_expression
          endif
        endfor
        for e in expressions
          if join(e, '') =~ g:aurepl_warn_on_slow_expressions_regex
            let out_array = out_array + ['warning: Ignoring infinite expression']
          else
            let out_array = out_array + [fireplace#session_eval(join(e, ''), {"ns": "user"})]
          endif
        endfor
        let out = join(out_array, "\n")
      catch
        let out = 'error: ' . v:exception
      endtry
    endif
    if &ft ==# 'fsharp'
      let g:fsharp_echo_all_fsi_output=1
      let out_array = []
      let expressions = []
      for d in clean_data
        if d =~ b:aurepl_expression_start
          let expressions = expressions + [[d]]
        else
          let last_expression = expressions[-1]
          let last_expression = last_expression + [d]
          let expressions[-1] = last_expression
        endif
      endfor
      for e in expressions
        try
          redir => s:out
            silent call fsharpbinding#python#FsiPurge()
            silent call fsharpbinding#python#FsiSend(join(e, "\n"))
            silent call fsharpbinding#python#FsiRead(5)
          redir END
          if empty(s:out)
            let out_array = out_array + ['no-out: Complete with no output']
          else
            let out_array = out_array + [substitute(substitute(s:out, "\n", '', 'g'), ';\s*', '; ', '')]
          endif
        catch
          let out_array = out_array + [v:exception]
        endtry
          let s:out = ''
          let out = join(out_array, "\n")
      endfor
      unlet g:fsharp_echo_all_fsi_output
    endif
  endif
  let out = split(out, "\n")
  let trimmed = []
  for o in out
    let trimmed = trimmed + [substitute(o, '^\s*', '', '')]
  endfor
  return trimmed
endfunction

function! s:clean_up()
  if g:aurepl_eval_inline_position == 'bottom' && len(s:range_added) >= 1
    for r in reverse(s:range_added)
      let [fromline, toline] = r
      execute fromline . "," . toline . "delete" 
    endfor
    let s:range_added = []
  else
    let b:winview = winsaveview() 
    execute "silent! %s/".b:aurepl_comment_regex."//g"
    call winrestview(b:winview)
  endif
endfunction

function! aurepl#clean_line(shuffle)
  let current_line = line('.')
  let comment = matchstr(getline(current_line), b:aurepl_comment_regex)
  let cleaned_line = substitute(getline(current_line), b:aurepl_comment_regex, 'CSREPL_PLACEHOLDER', '')
  let shuffle = a:shuffle
  if cleaned_line =~ 'CSREPL_PLACEHOLDER'
    let cleaned_line = substitute(cleaned_line, 'CSREPL_PLACEHOLDER', '', 'g')
    call setline(current_line, cleaned_line)
    if shuffle
      if substitute(cleaned_line, '\s', '', 'g') == ''
        if &ft ==# 'fsharp'
          if matchstr(getline(current_line-1), ';;$') != ''
            call setline(current_line-1, getline(current_line-1) .  comment)
          endif
        else
          call setline(current_line-1, getline(current_line-1) .  comment)
        endif
      endif
    endif
  endif
endfunction

function! aurepl#selection_to_repl() range
  let old_reg = getreg('"')
  let old_regtype = getregtype('"')
  let old_clipboard = &clipboard
  set clipboard&
  silent normal! ""gvy
  let selection = getreg('"')
  call setreg('"', old_reg, old_regtype)
  let &clipboard = old_clipboard
  let firstline = getpos("'<")[1]
  let lastline = getpos("'>")[1]
  call s:lines_to_repl(0, firstline, lastline)
endfunction

function! aurepl#file_to_repl()
  call s:lines_to_repl(0, 1, line('$'))
endfunction

function! aurepl#line_to_repl()
  call s:lines_to_repl(0, line('.'), line('.'))
endfunction

function! aurepl#expression_to_repl(triggered_by_as_you_type)
  if &ft ==# 'clojure'
    let open = '[[{(]'
    let close = '[]})]'
    let [start_line, start_col] = searchpairpos(open, '', close, 'Wrnb')
    let [end_line, end_col] = searchpairpos(open, '', close, 'Wrnc')
    if start_line != 0 && end_line != 0 && start_col != 0 && end_col != 0
      call s:lines_to_repl(a:triggered_by_as_you_type, start_line, end_line)
      return
    endif
    if getpos('.')[2:-1] == [1, 0]
      return
    endif
  endif
  let start_line = 1
  let end_line = line('.')
  if empty(substitute(getline(end_line), '\s', '', 'g'))
    return
  endif
  let counter = end_line
  if matchstr(getline(end_line), b:aurepl_expression_start) != ''
    call s:lines_to_repl(a:triggered_by_as_you_type ,end_line, line('.'))
    return
  endif
  while counter > start_line && matchstr(getline(counter), b:aurepl_expression_start) == ''
    let counter -= 1
  endwhile
  call s:lines_to_repl(a:triggered_by_as_you_type, counter, line('.'))
endfunction

function! s:suppress_line_output(triggered_by_as_you_type, line_number)
  if &ft ==# 'clojure'
    let non_empty_line = (substitute(getline(a:line_number), '\s', '', 'g') != '')
    let parts = split(getline(a:line_number), b:aurepl_comment_format)
    let end_of_expression = 0
    if len(parts) > 0
      let end_of_expression = (matchstr(parts[0], ')$\|)\s*$') != '')
    endif

    let next_parts = split(getline(a:line_number+1), b:aurepl_comment_format)
    let next_line_empty = 1
    if len(next_parts) > 0
      let next_line_empty = substitute(next_parts[0], '\s', '', 'g') == ''
    endif

    return (non_empty_line && (!end_of_expression || !next_line_empty))
  elseif &ft ==# 'fsharp'
    let next_line = getline(a:line_number+1)
    let parts = split(getline(a:line_number), b:aurepl_comment_format)
    let trailing_equals = 0
    let next_empty = 1
    let next_new_expression = 1
    let piped = 0
    if len(parts) > 0
      let trailing_equals = matchstr(parts[0], '=$\|=\s*$') != ''
      let next_empty = empty(next_line)
      let next_indented = matchstr(next_line, '^\s\s\s\s*.*') != ''
      let next_new_expression = !next_indented
      if !a:triggered_by_as_you_type
        let piped = matchstr(parts[0], '^\s*|>.*\||>.*') != ''
        let next_piped = matchstr(next_line, '^\s*|>.*\||>.*') != ''
      endif
    endif
    return trailing_equals || (!next_empty && piped) || next_piped || (!next_empty && !next_new_expression)
  else
    return 0
  endif
endfunction

function! aurepl#supress_eval(line_number)
  let line = getline(a:line_number)
  let next_line = getline(a:line_number+1)
  let prev_line = getline(a:line_number-1)
  if substitute(line, '\s', '', 'g') == ''
    return 1
  endif

  if &ft ==# 'clojure'
    return matchstr(line, '^\s*[(\|\[].*[)|\]]$\|^[(\|\[].*[)\|\]]$') == ''
  else
    return 0
  endif
endfunction

function! s:lines_to_repl(triggered_by_as_you_type, start_line, end_line)
  let lines = getline(a:start_line, a:end_line)
  let start_offset = a:start_line
  if &ft ==# 'cs'
    let start_offset -= 1
  endif
  let out = aurepl#send_to_repl(start_offset, lines)
  let commented = []
  for m in out
    let commented = commented + [b:aurepl_comment_format .' '.m]
  endfor
  if g:aurepl_eval_inline
    if g:aurepl_eval_inline_position == 'bottom'
      if len(commented) > 0
        let s:range_added = s:range_added + [[a:end_line+1, a:end_line+len(out)]]
        call append(a:end_line, commented)
      endif
    elseif g:aurepl_eval_inline_position == 'lastline'
      let outputs = []
      for m in out
        if m !~ ':\d*:'
          let outputs = outputs + [m . ' ']
        endif
      endfor
      let m = join(outputs, b:aurepl_comment_format . ' ')
      call setline(a:end_line, split(getline(a:end_line), b:aurepl_comment_format)[0] . b:aurepl_comment_format .' '.m)
    elseif g:aurepl_eval_inline_position == 'inline'
      let counter = a:end_line
      for m in reverse(out)
        while counter > a:start_line && ((substitute(getline(counter), '\s', '', 'g') == '') || s:suppress_line_output(a:triggered_by_as_you_type, counter))
          let counter = counter - 1
        endwhile
        let b:aurepl_last_out[counter] = m
        let parts = split(getline(counter), b:aurepl_comment_format)
        if len(parts) > 0
          if g:aurepl_eval_inline_collapse
            if index(b:aurepl_expanded, counter) < 0
              let m = m[0:g:aurepl_eval_inline_max]
              let no_space = substitute(m, '\s', '', 'g')
              if no_space[0] == '(' && no_space[-1:-1] != ')'
                let m = m .' ...)'
              elseif no_space[0] == '{' && no_space[-1:-1] != '}'
                let m = m .' ...}'
              elseif no_space[0] == '[' && no_space[-1:-1] != ']'
                let m = m .' ...]'
              endif
            endif
          endif
          call setline(counter, parts[0] . b:aurepl_comment_format .' '.m)
        endif
        let counter = (counter > a:start_line) ? counter - 1 : counter
      endfor
    endif
  else
    let m = join(outputs, b:aurepl_comment_format . ' ')
    echomsg m
  endif
endfunction

function! aurepl#repl(repl_type)
  execute 'vsplit ' g:aurepl_repl_buffer_name . '.' . a:repl_type
endfunction

function! s:expand_output()
  if g:aurepl_eval_inline_position == 'inline' && g:aurepl_eval_inline_collapse
    let line_number = line('.')
    let parts = split(getline(line_number), b:aurepl_comment_format)
    if len(parts) > 0
      let m = b:aurepl_last_out[line_number]
      let b:aurepl_expanded += [line_number]
      call setline(line_number, parts[0] . b:aurepl_comment_format .' '.m)
    endif
  endif
endfunction

autocmd filetype * command! -buffer CsRepl :exe aurepl#repl('cs')
autocmd filetype * command! -buffer ClojureRepl :exe aurepl#repl('clj')
autocmd filetype * command! -buffer FsRepl :exe aurepl#repl('fsx')
autocmd filetype * command! -buffer JsRepl :exe aurepl#repl('js')
autocmd filetype * command! -buffer FileToRepl :call aurepl#file_to_repl()
autocmd filetype * command! -buffer LineToRepl :call aurepl#line_to_repl()
autocmd filetype * command! -buffer HideOutput :call s:clean_up()
autocmd filetype * command! -buffer -range SelectionToRepl let b:winview = winsaveview() | call aurepl#selection_to_repl() | call winrestview(b:winview)

if g:aurepl_eval_inline_collapse
  autocmd filetype * command! -buffer ExpandOutput :call s:expand_output()
  autocmd filetype * nnoremap <silent> cpa :ExpandOutput<CR>
endif

autocmd BufWritePre,BufLeave *.cs,*.js,*.vim,*.clj,*.cljs,*.cljc,*.fsx,*.fs,*.fsi silent call s:clean_up()

autocmd filetype * nnoremap <silent> cpf :FileToRepl<CR>
autocmd filetype * nnoremap <silent> cpe :ExpressionToRepl<CR>
autocmd filetype * nnoremap <silent> cpl :LineToRepl<CR>
autocmd filetype * nnoremap <silent> cpo :HideOutput<CR>
autocmd filetype * vnoremap <silent> cps :SelectionToRepl<CR>

autocmd BufEnter *  let b:aurepl_last_out = {}
autocmd BufEnter *  let b:aurepl_expanded = []

autocmd BufEnter * if !exists('b:aurepl_comment_format') && &ft ==# 'vim' | let b:aurepl_comment_format = g:aurepl_comment_format_vim | endif
autocmd BufEnter * if !exists('b:aurepl_comment_regex') && &ft ==# 'vim' | let b:aurepl_comment_regex = g:aurepl_comment_regex_vim | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'vim' | syn match csEval	"\"\"= .*$"| endif
autocmd InsertLeave,BufEnter * if &ft ==# 'vim' | syn match csEvalError		"\"\"= .*$" | endif

autocmd InsertLeave,BufEnter * syn match csZshError "//= zsh:\d: .*$"
autocmd InsertLeave,BufEnter * syn match csBashError "//= bash:\d: .*$"

autocmd BufEnter * hi csEval guifg=#fff guibg=#03525F
autocmd BufEnter * hi csEvalIf guifg=#fff guibg=#5D0089
autocmd BufEnter * hi csEvalSwitch guifg=#fff guibg=#5F9181
autocmd BufEnter * hi csEvalEvaluation guifg=#fff guibg=#3F3591
autocmd BufEnter * hi csEvalError guifg=#fff guibg=#8B1A37
autocmd BufEnter * hi csEvalWarn guifg=#fff guibg=#8C7A37
autocmd BufEnter * hi csZshError guibg=#fff guibg=#8B1A37
autocmd BufEnter * hi csBashError guibg=#fff guibg=#8B1A37
