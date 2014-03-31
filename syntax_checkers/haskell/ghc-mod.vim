"============================================================================
"File:        ghc-mod.vim
"Description: Syntax checking plugin for syntastic.vim
"Maintainer:  Anthony Carapetis <anthony.carapetis at gmail dot com>
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================

if exists('g:loaded_syntastic_haskell_ghc_mod_checker')
    finish
endif
let g:loaded_syntastic_haskell_ghc_mod_checker = 1
let g:ghc_modi_maxnum = 3

let s:ghc_mod_new = -1
let s:ghc_modi_cmd = 'ghc-modi'
let s:syntastic_haskell_ghc_modi_procs = []

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_haskell_ghc_mod_IsAvailable() dict
    " We need either a Vim version that can handle NULs in system() output,
    " or a ghc-mod version that has the --boundary option.
    let exe = self.getExec()
    let s:ghc_mod_new = executable(exe) ? s:GhcModNew(exe) : -1
    if !exists('s:exists_vimproc')
        try
            call vimproc#version()
            let s:exists_vimproc = 1
            "echomsg 'vimproc standby'
        catch
            let s:exists_vimproc = 0
        endtry
    endif
    return (s:ghc_mod_new >= 0) && (v:version >= 704 || s:ghc_mod_new)
endfunction

function! SyntaxCheckers_haskell_ghc_mod_GetLocList() dict
    let errorformat =
        \ '%-G%\s%#,' .
        \ '%f:%l:%c:%trror: %m,' .
        \ '%f:%l:%c:%tarning: %m,'.
        \ '%f:%l:%c: %trror: %m,' .
        \ '%f:%l:%c: %tarning: %m,' .
        \ '%f:%l:%c:%m,' .
        \ '%E%f:%l:%c:,' .
        \ '%Z%m'

    if executable(s:ghc_modi_cmd) && s:exists_vimproc
        "echomsg 'use ghc-modi'
        let hsfile = self.makeprgBuild({ 'exe': '' })
        "echomsg 'hsfile: ' . makeprg

        return SyntasticMake({
            \ 'err_lines': GhcModiMakeErrLines(hsfile),
            \ 'errorformat': errorformat,
            \ 'postfunc': 'SyntaxCheckers_haskell_ghc_mod_Popstprocess',
            \ 'postprocess': ['compressWhitespace']})
    else
        "echomsg 'use ghc-mod'
        let makeprg = self.makeprgBuild({
            \ 'exe': self.getExecEscaped() . ' check' . (s:ghc_mod_new ? " --boundary='" . nr2char(11) . "'" : ' ') })

        return SyntasticMake({
            \ 'makeprg': makeprg,
            \ 'errorformat': errorformat,
            \ 'postfunc': 'SyntaxCheckers_haskell_ghc_mod_Popstprocess',
            \ 'postprocess': ['compressWhitespace'],
            \ 'returns': [0] })
    endif

endfunction

function! GhcModiMakeErrLines(hsfile)
    let cwd = getcwd()

    let l:num_procs = len(s:syntastic_haskell_ghc_modi_procs)

    for i in range(l:num_procs - 1, 0, -1)
        let l:proc_tmp = s:syntastic_haskell_ghc_modi_procs[i]
        if l:proc_tmp.cwd == cwd
            if l:proc_tmp.is_valid
                let l:proc = l:proc_tmp
                let l:proc.last_access = localtime() "for debugging
            endif
            call remove(s:syntastic_haskell_ghc_modi_procs, i)
            break
        endif
    endfor

    if !exists('l:proc')
        if l:num_procs >= g:ghc_modi_maxnum
            let l:proc_old = s:syntastic_haskell_ghc_modi_procs[0]
            call remove(s:syntastic_haskell_ghc_modi_procs, 0)
            call l:proc_old.stdin.close()
            call l:proc_old.waitpid()
        endif

        let cmds = [s:ghc_modi_cmd, "-b", nr2char(11)]
        let l:proc = vimproc#popen2(cmds)
        call extend(l:proc, { 'cwd': cwd, 'last_access': localtime() })
    endif

    "call syntastic#log#debug(g:SyntasticDebugNotifications, 'ghc-modi: l:proc=' . string(l:proc))
    call l:proc.stdin.write('check ' . a:hsfile . "\n")
    let l:res = l:proc.stdout.read_lines(100, 10000)
    let l:out = []

    while (empty(l:res) || (l:res[-1] != 'OK' && l:res[-1] != 'NG')) && !l:proc.stdout.eof
        let l:out = l:proc.stdout.read_lines()
        let l:res += l:out
    endwhile

    let l:syntastic_one_lines = []
    for line in l:res
        if line != 'OK' && line != 'NG'
            let l:syntastic_one_lines += [line]
        endif
    endfor

    if !empty(l:res) && l:res[-1] == 'OK'
        call add(s:syntastic_haskell_ghc_modi_procs, l:proc)
    else
        call l:proc.stdin.close()
        call l:proc.waitpid()
    endif

    return l:syntastic_one_lines
endfunction

function! SyntaxCheckers_haskell_ghc_mod_Popstprocess(errors)
    let out = []
    "echomsg "in : " . string(a:errors)
    for e in a:errors
        if has_key(e, 'text') && !empty(e['text'])
            let lines = split(e['text'], nr2char(11))
            let e['text'] = lines[0]
            call add(out, e)
            for l in lines[1:]
               call add(out, {'text': l, 'valid':1, 'type': 'T', 'bufnr': '', 'lnum': '' })
            endfor
        endif
    endfor
    "echomsg "out: " . string(out)
    return out
endfunction

function! s:GhcModNew(exe)
    let exe = syntastic#util#shescape(a:exe)
    try
        let ghc_mod_version = filter(split(system(exe), '\n'), 'v:val =~# ''\m^ghc-mod version''')[0]
        let ret = syntastic#util#versionIsAtLeast(syntastic#util#parseVersion(ghc_mod_version), [2, 1, 2])
    catch /\m^Vim\%((\a\+)\)\=:E684/
        call syntastic#log#error("checker haskell/ghc_mod: can't parse version string (abnormal termination?)")
        let ret = -1
    endtry
    return ret
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'haskell',
    \ 'name': 'ghc_mod',
    \ 'exec': 'ghc-mod' })

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set et sts=4 sw=4:
