" Python filetype plugin for matching with % key
" Language:     Python (ft=python)
" Last Change:  2002 August 15
" Maintainer:   Benji Fisher, Ph.D. <benji@member.AMS.org>
" Version:	0.4, for Vim 6.1

" allow user to prevent loading and prevent duplicate loading
if exists("b:loaded_py_match") || &cp
  finish
endif
let b:loaded_py_match = 1

let s:save_cpo = &cpo
set cpo&vim

" % for if -> elif -> else -> if, g% for else -> elif -> if -> else
nnoremap <buffer> <silent> %  :<C-U>call <SID>PyMatch('%','n') <CR>
vnoremap <buffer> <silent> %  :<C-U>call <SID>PyMatch('%','v') <CR>m'gv``
onoremap <buffer> <silent> %  v:<C-U>call <SID>PyMatch('%','o') <CR>
nnoremap <buffer> <silent> g% :<C-U>call <SID>PyMatch('g%','n') <CR>
vnoremap <buffer> <silent> g% :<C-U>call <SID>PyMatch('g%','v') <CR>m'gv``
onoremap <buffer> <silent> g% v:<C-U>call <SID>PyMatch('g%','o') <CR>
" Move to the start ([%) or end (]%) of the current block.
nnoremap <buffer> <silent> [% :<C-U>call <SID>PyMatch('[%', 'n') <CR>
vmap <buffer> [% <Esc>[%m'gv``
onoremap <buffer> <silent> [% v:<C-U>call <SID>PyMatch('[%', 'o') <CR>
nnoremap <buffer> <silent> ]% :<C-U>call <SID>PyMatch(']%',  'n') <CR>
vmap <buffer> ]% <Esc>]%m'gv``
onoremap <buffer> <silent> ]% v:<C-U>call <SID>PyMatch(']%',  'o') <CR>

" The rest of the file needs to be :sourced only once per session.
if exists("s:loaded_functions") || &cp
  finish
endif
let s:loaded_functions = 1

" One problem with matching in Python is that so many parts are optional.
" I deal with this by matching on any known key words at the start of the
" line, if they have the same indent.
"
" Recognize try, except, finally and if, elif, else .
" keywords that start a block:
let s:ini = 'try\|if'
" keywords that continue or end a block:
let s:tail = 'except\|finally'
let s:tail = s:tail . '\|elif\|else'
" all keywords:
let s:all = s:ini . '\|' . s:tail

function! s:PyMatch(type, mode) range
  " If this function was called from Visual mode, make sure that the cursor
  " is at the correct end of the Visual range:
  if a:mode == "v"
    execute "normal! gv\<Esc>"
  endif

  let startline = line(".") " Do not change these:  needed for s:CleanUp()
  let startcol = col(".")
  " In case we start on a comment line, ...
  if a:type[0] =~ '[][]'
    let currline = s:NonComment(+1, startline-1)
  else
    let currline = startline
  endif
  let startindent = indent(currline)

  " Use default behavior if called as % with a count.
  if a:type == "%" && v:count
    exe "normal! " . v:count . "%"
    return s:CleanUp('', a:mode, startline, startcol)
  endif

  " If called as % or g%, decide whether to bail out.
  if a:type == '%' || a:type == 'g%'
    let text = getline(".")
    if strpart(text, 0, col(".")) =~ '\S\s' || text !~ '^\s*\%('. s:all .'\)'
    " cursor not on the first WORD or no keyword so bail out
      normal! %
      return s:CleanUp('', a:mode, startline, startcol)
    endif
  endif

  " If called as %, look down for "elif" or "else" or up for "if".
  if a:type == '%'
    let next = s:NonComment(+1, currline)
    while next != 0 && indent(next) > startindent
      let next = s:NonComment(+1, next)
    endwhile
    if indent(next) == startindent && getline(next) =~ '^\s*\%('.s:tail.'\)'
      execute next
      return s:CleanUp('', a:mode, startline, startcol, '$')
    endif
    " If we are still here, then there are no "tail" keywords below us in this
    " block.  Search upwards for the start of the block.
    let next = currline
    while next != 0 && indent(next) >= startindent
      if indent(next) == startindent && getline(next) =~ '^\s*\%('.s:ini.'\)'
	execute next
	return s:CleanUp('', a:mode, startline, startcol, '$')
      endif
      let next = s:NonComment(-1, next)
    endwhile
    " If we are still here, there is an error in the file.  Let's do nothing.
  endif

  " If called as g%, look up for "if" or "elif" or "else" or down for any.
  if a:type == 'g%'
    if getline(currline) =~ '^\s*\(' . s:tail . '\)'
      let next = s:NonComment(-1, currline)
      while next != 0 && indent(next) > startindent
	let next = s:NonComment(-1, next)
      endwhile
      if indent(next) == startindent && getline(next) =~ '^\s*\%('.s:all.'\)'
	execute next
	return s:CleanUp('', a:mode, startline, startcol, '$')
      endif
    else
      " We started at the top of the block.
      " Search down for the end of the block.
      let next = s:NonComment(+1, currline)
      while next != 0 && indent(next) >= startindent
	if indent(next) == startindent
	  if getline(next) =~ '^\s*\('.s:tail.'\)'
	    let currline = next
	  else
	    break
	  endif
	endif
	let next = s:NonComment(+1, next)
      endwhile
      execute currline
      return s:CleanUp('', a:mode, startline, startcol, '$')
    endif
  endif

  " If called as [%, find the start of the current block.
  if a:type == '[%'
    let tailflag = (getline(currline) =~ '^\s*\(' . s:tail . '\)')
    let prevline = s:NonComment(-1, currline)
    while prevline > 0
      if indent(prevline) < startindent ||
	    \ tailflag && indent(prevline) == startindent &&
	    \ getline(prevline) =~ '^\s*\(' . s:ini . '\)'
	  " Found the start of block, so go there!
	  execute prevline
	  return s:CleanUp('', a:mode, startline, startcol, '$')
      endif
      let prevline = s:NonComment(-1, prevline)
    endwhile
  endif

  " If called as ]%, find the end of the current block.
  if a:type == ']%'
    let nextline = s:NonComment(+1, currline)
    let startofblock = (indent(nextline) > startindent)
    while  nextline > 0
      if indent(nextline) < startindent ||
	  \ startofblock && indent(nextline) == startindent &&
	    \ getline(nextline) !~ '^\s*\(' . s:tail . '\)'
	break
      endif
      let currline = nextline
      let nextline = s:NonComment(+1, currline)
    endwhile
    " nextline is in the next block or after EOF, so go to currline:
    execute currline
    return s:CleanUp('', a:mode, startline, startcol, '$')
  endif
endfun

" Return the line number of the next non-comment, or 0 if there is none.
" Start at the current line unless the optional second argument is given.
" The direction is specified by a:inc (normally +1 or -1 ;
" no test for a:inc == 0, which may lead to an infinite loop).
fun! s:NonComment(inc, ...)
  if a:0 > 0
    let next = a:1 + a:inc
  else
    let next = line(".") + a:inc
  endif
  while 0 < next && next <= line("$")
    if getline(next) !~ '^\s*\(#\|$\)'
      return next
    endif
    let next = next + a:inc
  endwhile
  return 0  " If the while loop finishes, we fell off the end of the file.
endfun

" Restore options and do some special handling for Operator-pending mode.
" The optional argument is the tail of the matching group.
fun! s:CleanUp(options, mode, startline, startcol, ...)
  if strlen(a:options)
    execute "set" a:options
  endif
  " Open folds, if appropriate.
  if a:mode != "o"
    if &foldopen =~ "percent"
      normal! zv
    endif
  " In Operator-pending mode, we want to include the whole match
  " (for example, d%).
  " This is only a problem if we end up moving in the forward direction.
  elseif a:startline < line(".") ||
        \ a:startline == line(".") && a:startcol < col(".")
    if a:0
      " If we want to include the whole line then a:1 should be '$' .
      silent! call search(a:1)
    endif
  endif " a:mode != "o" && etc.
  return 0
endfun

let &cpo = s:save_cpo

" vim:sts=2:sw=2:ff=unix:
