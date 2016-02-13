"============================================================================
"File:        hlint.vim
"Description: Syntax checking plugin for syntastic.vim
"Maintainer:  Nicolas Wu <nicolas.wu at gmail dot com>
"License:     BSD
"============================================================================

if exists('g:loaded_syntastic_haskell_hlint_checker')
    finish
endif
let g:loaded_syntastic_haskell_hlint_checker = 1

if exists('g:syntastic_haskell_hlint_hint_file')
    let s:hlint_option = ' --hint=' . g:syntastic_haskell_hlint_hint_file
else
    let s:hlint_option = ''
endif

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_haskell_hlint_GetLocList() dict
    let makeprg = self.makeprgBuild({
        \ 'fname': syntastic#util#shexpand('%:p')})

    let errorformat =
        \ '%E%f:%l:%v: Error while reading hint file\, %m,' .
        \ '%E%f:%l:%v: Error: %m,' .
        \ '%W%f:%l:%v: Warning: %m,' .
        \ '%C%m'

    return SyntasticMake({
        \ 'makeprg': makeprg . s:hlint_option,
        \ 'errorformat': errorformat,
        \ 'defaults': {'vcol': 1},
        \ 'postprocess': ['compressWhitespace'] })
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'haskell',
    \ 'name': 'hlint' })

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set sw=4 sts=4 et fdm=marker:
