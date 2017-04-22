if exists('g:loaded_csrepl') || &cp
  finish
endif

let g:loaded_csrepl = 1
let g:csrepl_node_command = 'node --eval "$(cat ./scratch.temp.js)" --print'
let g:csrepl_cs_command = 'csharp ./scratch.temp.cs -warn:0'

let g:csrepl_comment_format = ' //='
let g:csrepl_comment_format_fs = ' //>'
let g:csrepl_comment_format_vim = ' "@='
let g:csrepl_comment_format_clojure = ' ;;='
let g:csrepl_comment_regex = '\s\/\/=\s.*'
let g:csrepl_comment_regex_fs = '\s\/\/>\s.*'
let g:csrepl_comment_regex_vim = '\s"@=\s.*'
let g:csrepl_comment_regex_clojure = '\s;;=\s.*'

let s:range_added = []

if !exists('g:csrepl_eval_inline')
  let g:csrepl_eval_inline = 1
endif

if !exists('g:csrepl_eval_inline_position')
  let g:csrepl_eval_inline_position = 'inline'
endif

if !exists('g:csrepl_eval_inline_cs_experimental')
  let g:csrepl_eval_inline_cs_experimental = 1
endif

function! s:VimEval(data)
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

function! s:SendToRepl(line_offset, data)
  let counter = 1 + a:line_offset
  let clean_data = []
  if &ft ==# 'cs'
    let clean_data = ['LoadAssembly("System.Web.Extensions");', 'using System.Web.Script.Serialization;', 'var csrepl_json_serializer = new JavaScriptSerializer();']
  endif
  for d in a:data
    for line in split(d, '\n')
      if exists('b:csrepl_comment_regex')
        let line = substitute(line, b:csrepl_comment_regex, '', 'g')
      endif
      if matchstr(line, '^\s*$')
        let counter += 1
      endif
      if &ft ==# 'cs' && g:csrepl_eval_inline_position == 'inline' && g:csrepl_eval_inline_cs_experimental == 1
       if line =~ '^\s*\w*\s*\w*\s*=\s*'
         let the_var = substitute(line, '^\s*\w*\s*\w*\s*=\s*', '', '')
         let the_var = the_var[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:{0}", csrepl_json_serializer.Serialize(' . the_var .  '), '. counter . ');']
       elseif line =~ '^\s*var\s*\w*\s*=\s*'
         let the_var = substitute(line, '^\s*var\s*\w*\s*=\s*', '', '')
         let the_var = the_var[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:{0}", csrepl_json_serializer.Serialize(' . the_var .  '), '. counter . ');']
       elseif line =~ 'if (.*' && line !~ 'else if (.*'
         let the_if = substitute(line, 'if (', '', '')
         let the_if = the_if[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:→ {0}", ' . the_if . ', '. counter . ');']
       elseif line =~ 'switch (.*'
         let the_switch = substitute(line, 'switch (', '', '')
         let the_switch = the_switch[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:⊃ {0}", ' . the_switch . ', '. counter . ');']
       elseif line =~ '^\s*Console.WriteLine('
         let the_evaluation = substitute(line, '^\s*Console.WriteLine(', '', '')
         let the_evaluation = substitute(the_evaluation, '\s\+$', '', '')
         let the_evaluation = the_evaluation[0:-3]
         if the_evaluation =~ '{0}'
           let clean_data = clean_data + ['Console.WriteLine(":{1}:{0}", csrepl_json_serializer.Serialize(string.Format(' . the_evaluation . ')), '. counter . ');']
         else
           let clean_data = clean_data + ['Console.WriteLine(":{1}:{0}", ' . (the_evaluation) . '.ToString(), '. counter . ');']
         endif
       elseif line =~ '^\w*.;$'
         let the_evaluation = line[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:≡ {0}", csrepl_json_serializer.Serialize(' . the_evaluation . '), '. counter . ');']
       elseif line =~ '^\s*\w*\.\w*.*;' || line =~ '^s*\w*(.*;'
         let the_evaluation = line[0:-2]
         let clean_data = clean_data + ['Console.WriteLine(":{1}:≡ {0}", csrepl_json_serializer.Serialize(' . the_evaluation . '), '. counter . ');']
       endif
     endif
     let clean_data = clean_data + [line]
     if a:line_offset > 0
       let counter += 1
     endif
    endfor
    let counter += 1
  endfor
  if exists('b:csrepl_use_command') && executable(split(b:csrepl_use_command, ' ')[0])
    call writefile(clean_data, 'scratch.temp.'.expand('%:e'))
    let out = system(b:csrepl_use_command)
    call delete('scratch.temp.'.expand('%:e'))
  else
    if &ft ==# 'vim'
      let out = s:VimEval(clean_data)
    endif
    if &ft ==# 'clojure'
      try
        let expressions = []
        let out_array = []
        for d in clean_data
          if d =~ '^('
            let expressions = expressions + [[d]]
          else
            let last_expression = expressions[-1]
            let last_expression = last_expression + [d]
            let expressions[-1] = last_expression
          endif
        endfor
        for e in expressions
          let out_array = out_array + [fireplace#session_eval(join(e, ''), {"ns": "user"})]
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
        if d =~ '^\w'
          let expressions = expressions + [[d]]
        else
          let last_expression = expressions[-1]
          let last_expression = last_expression + [d]
          let expressions[-1] = last_expression
        endif
      endfor
      for e in expressions
        redir => s:out
          silent call fsharpbinding#python#FsiPurge()
          silent call fsharpbinding#python#FsiSend(join(e, "\n"))
          silent call fsharpbinding#python#FsiRead(5)
        redir END
        let out_array = out_array + [substitute(substitute(s:out, "\n", '', 'g'), ';\s*', '; ', '')]
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

function! s:CleanUp()
  if g:csrepl_eval_inline_position == 'bottom' && len(s:range_added) >= 1
    for r in reverse(s:range_added)
      let [fromline, toline] = r
      execute fromline . "," . toline . "delete" 
    endfor
    let s:range_added = []
  endif
endfunction

function! s:SelectionToRepl() range
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
  call s:LinesToRepl(firstline, lastline)
endfunction

function! s:FileToRepl()
  call s:LinesToRepl(1, line('$'))
endfunction

function! s:LineToRepl()
  call s:LinesToRepl(line('.'), line('.'))
endfunction

function! s:LinesToRepl(start_line, end_line)
  let lines = getline(a:start_line, a:end_line)
  let start_offset = a:start_line
  if &ft ==# 'cs' && g:csrepl_eval_inline_cs_experimental == 1
    let start_offset -= 1
  endif
  let out = s:SendToRepl(start_offset, lines)
  let commented = []
  for m in out
    let commented = commented + [b:csrepl_comment_format .' '.m]
  endfor
  if g:csrepl_eval_inline
    if g:csrepl_eval_inline_position == 'bottom'
      if len(commented) > 0
        let s:range_added = s:range_added + [[a:end_line+1, a:end_line+len(out)]]
        call append(a:end_line, commented)
      endif
    elseif g:csrepl_eval_inline_position == 'lastline'
      let outputs = []
      for m in out
        if m !~ ':\d*:'
          let outputs = outputs + [m]
        endif
      endfor
      let m = join(outputs, b:csrepl_comment_format . ' ')
      call setline(a:end_line, split(getline(a:end_line), b:csrepl_comment_format)[0] . b:csrepl_comment_format .' '.m)
    elseif g:csrepl_eval_inline_position == 'inline'
      if &ft ==# 'cs' && g:csrepl_eval_inline_cs_experimental == 1
        let outputs = []
        let conditions = []
        for m in out
          if m =~ ':\d*:'
            let conditions = conditions + [m]
          else
            let outputs = outputs + [m]
          endif
        endfor
        for c in conditions
          let linenumber = matchstr(c, ':\d*:')[1:-2]
          let parts = split(getline(linenumber), b:csrepl_comment_format)
          if len(parts) > 0
            call setline(linenumber, parts[0] . b:csrepl_comment_format .' '.substitute(substitute(c, ':\d*:', '', ''), '^\s*', '', ''))
          endif
        endfor
      else
        let counter = a:end_line
        for m in reverse(out)
          while counter > a:start_line && ((substitute(getline(counter), '\s', '', 'g') == '') || (&ft ==# 'clojure' && (matchstr(getline(counter), ')\s*$') == '' || substitute(getline(counter+1), '\s', '', 'g') != '')))
            let counter = counter - 1
          endwhile
          let parts = split(getline(counter), b:csrepl_comment_format)
          if len(parts) > 0
            call setline(counter, parts[0] . b:csrepl_comment_format .' '.m)
          endif
          let counter = (counter > a:start_line) ? counter - 1 : counter
        endfor
      endif
    endif
  else
    let m = join(outputs, b:csrepl_comment_format . ' ')
    echomsg m
  endif
endfunction

function! s:Repl(repl_type)
  execute 'vsplit __REPL__.'.a:repl_type
  setlocal readonly
endfunction

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
  let out = s:SendToRepl(0, ['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Select(t => t.Namespace).Where(n => !string.IsNullOrEmpty(n)).Distinct()'])
  let namespaces = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# Namespaces', '', 'This is a current list of loaded namespaces, follow a namespace by pressing F on it.', '']
  for n in namespaces
    let lines = lines + ['## '.n]
  endfor
  let command = expand('%b') =~ '__Namespaces.cs' ? 'e' : 'split'
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:csrepl_use_command = g:csrepl_cs_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :NamespaceUnderCursor<CR>
endfunction

function! s:Types(namespace)
  let out = s:SendToRepl(0, ['using System.Reflection;', 'AppDomain.CurrentDomain.GetAssemblies().SelectMany(a => a.GetTypes()).Where(t => t.Namespace == "'.a:namespace.'").Select(t => t.FullName).Distinct()'])
  let types = eval(substitute(substitute(out[-1], '{', '[', 'g'), '}', ']', 'g'))
  let lines = ['# '.a:namespace, '', 'This is a list of types within the '.a:namespace.' namespace, follow a type by pressing F on it.', '']
  for t in types
    let lines = lines + ['## '.t]
  endfor
  let command = expand('%b') =~ '__Namespaces.cs' ? 'e' : 'split'
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:csrepl_use_command = g:csrepl_cs_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
  nnoremap <silent> <buffer> F :TypeUnderCursor<CR>
endfunction

function! s:Functions(typename)
  let out = s:SendToRepl(0, [
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
  execute command '__Namespaces.cs'
    setlocal filetype=markdown
    setlocal buftype=nofile
    let b:csrepl_use_command = g:csrepl_cs_command
  call append(0, lines)
  normal! gg
  nnoremap <buffer> <ESC> :q<CR>
endfunction

autocmd filetype * command! -buffer CsRepl :exe s:Repl('cs')
autocmd filetype * command! -buffer ClojureRepl :exe s:Repl('clj')
autocmd filetype * command! -buffer FsRepl :exe s:Repl('fsx')
autocmd filetype * command! -buffer JsRepl :exe s:Repl('js')
autocmd filetype * command! -buffer FileToRepl :call s:FileToRepl()
autocmd filetype * command! -buffer LineToRepl :call s:LineToRepl()
autocmd filetype * command! -buffer -range SelectionToRepl let b:winview = winsaveview() | call s:SelectionToRepl() | call winrestview(b:winview)

autocmd filetype cs command! -buffer Namespaces :exe s:Namespaces()
autocmd filetype markdown command! -buffer NamespaceUnderCursor :exe s:TagUnderCursor('namespace')
autocmd filetype markdown command! -buffer TypeUnderCursor :exe s:TagUnderCursor('type')

autocmd BufWritePre * silent call s:CleanUp()
autocmd BufLeave * silent call s:CleanUp()

autocmd BufWritePre *.cs,*.js silent! %s/\s\/\/=\s.*//g
autocmd BufLeave *.cs,*.js silent! %s/\s\/\/=\s.*//g

autocmd BufWritePre *.fs,*.fsx silent! %s/\s\/\/>\s.*//g
autocmd BufLeave *.fs,*.fsx silent! %s/\s\/\/>\s.*//g

autocmd BufWritePre *.vim silent! %s/\s"@=\s.*//g
autocmd BufLeave *.vim silent! %s/\s"@=\s.*//g

autocmd BufWritePre *.clj,*.cljs,*.cljc silent! %s/\s;;=\s.*//g
autocmd BufLeave *.clj,*.cljs,*.cljc silent! %s/\s;;=\s.*//g

autocmd filetype * nnoremap <silent> csr :CsRepl<CR>
autocmd filetype * nnoremap <silent> cpf :FileToRepl<CR>
autocmd filetype * nnoremap <silent> cpl :LineToRepl<CR>
autocmd filetype * vnoremap <silent> cps :SelectionToRepl<CR>

autocmd BufEnter * if !exists('b:csrepl_use_command') && &ft ==# 'javascript' | let b:csrepl_use_command = g:csrepl_node_command | endif
autocmd BufEnter * if !exists('b:csrepl_use_command') && &ft ==# 'cs'         | let b:csrepl_use_command = g:csrepl_cs_command   | endif

autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'javascript' | let b:csrepl_comment_format = g:csrepl_comment_format         | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'cs'         | let b:csrepl_comment_format = g:csrepl_comment_format         | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'fsharp'     | let b:csrepl_comment_format = g:csrepl_comment_format_fs      | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'vim'        | let b:csrepl_comment_format = g:csrepl_comment_format_vim     | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'clojure'    | let b:csrepl_comment_format = g:csrepl_comment_format_clojure | endif

autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'javascript' | let b:csrepl_comment_regex = g:csrepl_comment_regex         | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'cs'         | let b:csrepl_comment_regex = g:csrepl_comment_regex         | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'fsharp'     | let b:csrepl_comment_regex = g:csrepl_comment_regex_fs      | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'vim'        | let b:csrepl_comment_regex = g:csrepl_comment_regex_vim     | endif
autocmd BufEnter * if !exists('b:csrepl_comment_regex') && &ft ==# 'clojure'    | let b:csrepl_comment_regex = g:csrepl_comment_regex_clojure | endif

autocmd BufEnter * if &ft ==# 'cs'         | let g:csrepl_eval_inline_position = 'inline' | endif
autocmd BufEnter * if &ft ==# 'javascript' | let g:csrepl_eval_inline_position = 'lastline' | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEval	"//= .*$"  | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEvalIf	"//= →.*$"  | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEvalSwitch	"//= ⊃.*$"  | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'cs' || &ft ==# 'javascript' | syn match csEvalEvaluation	"//= ≡.*$"  | endif


autocmd InsertLeave,BufEnter * if &ft ==# 'vim'                        | syn match csEval	"\"@= .*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure'                    | syn match csEval	";;= .*$"  | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp'                     | syn match csEval	"//> .*$"  | endif

autocmd InsertLeave,BufEnter * if &ft ==# 'cs'         | syn match csEvalError		"//= (\d,\d): error.*$" | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'javascript' | syn match csEvalError		"//= .*: .*$"           | endif


autocmd InsertLeave,BufEnter * if &ft ==# 'vim'        | syn match csEvalError		"\"@= error.*$"         | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'clojure'    | syn match csEvalError		";;= error.*$"          | endif
autocmd InsertLeave,BufEnter * if &ft ==# 'fsharp'     | syn match csEvalError		"//> .*: error.*$"      | endif
autocmd InsertLeave,BufEnter * syn match csZshError		  "//= zsh:\d: .*$"
autocmd InsertLeave,BufEnter * syn match csBashError		"//= bash:\d: .*$"

autocmd BufEnter * hi csEval guifg=#fff guibg=#03525F
autocmd BufEnter * hi csEvalIf guifg=#fff guibg=#5D0089
autocmd BufEnter * hi csEvalSwitch guifg=#fff guibg=#5F9181
autocmd BufEnter * hi csEvalEvaluation guifg=#fff guibg=#3F3591
autocmd BufEnter * hi csEvalError guifg=#fff guibg=#8B1A37
autocmd BufEnter * hi csZshError guibg=#fff guibg=#8B1A37
autocmd BufEnter * hi csBashError guibg=#fff guibg=#8B1A37

autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'cs'         | let b:csrepl_comment_format = g:csrepl_comment_format         | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'fsharp'     | let b:csrepl_comment_format = g:csrepl_comment_format_fs      | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'vim'        | let b:csrepl_comment_format = g:csrepl_comment_format_vim     | endif
autocmd BufEnter * if !exists('b:csrepl_comment_format') && &ft ==# 'clojure'    | let b:csrepl_comment_format = g:csrepl_comment_format_clojure | endif
