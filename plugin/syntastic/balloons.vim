if exists("g:loaded_syntastic_notifier_balloons")
    finish
endif
let g:loaded_syntastic_notifier_balloons = 1

if !exists("g:syntastic_enable_balloons")
    let g:syntastic_enable_balloons = 1
endif

if !has('balloon_eval')
    let g:syntastic_enable_balloons = 0
endif

let g:SyntasticBalloonsNotifier = {}

" Public methods {{{1

function! g:SyntasticBalloonsNotifier.New()
    let newObj = copy(self)
    return newObj
endfunction

function! g:SyntasticBalloonsNotifier.enabled()
    return exists('b:syntastic_enable_balloons') ? b:syntastic_enable_balloons : g:syntastic_enable_balloons
endfunction

" Update the error balloons
function! g:SyntasticBalloonsNotifier.refresh(loclist)
    let balloons = {}
    if !a:loclist.isEmpty()
        for i in a:loclist.filterByQuietFlagCached()
            let b = i['bufnr']
            let l = i['lnum']
            if !has_key(balloons, b)
                let balloons[b] = {}
            endif

            if has_key(balloons[b], l)
                let balloons[b][l] .= "\n" . i['text']
            else
                let balloons[b][l] = i['text']
            endif
        endfor
    endif

    for buf in a:loclist.getBuffers()
        call setbufvar(str2nr(buf), 'syntastic_balloons', has_key(balloons, buf) ? copy(balloons[buf]) : {})
    endfor

    if !a:loclist.isEmpty()
        set beval bexpr=SyntasticBalloonsExprNotifier()
    endif
endfunction

" Update the error balloons
function! g:SyntasticBalloonsNotifier.reset(loclist)
    for buf in a:loclist.getBuffers()
        call setbufvar(str2nr(buf), 'syntastic_balloons', {})
    endfor

    set nobeval
endfunction

" Private functions {{{1

function! SyntasticBalloonsExprNotifier()
    if !exists('b:syntastic_balloons')
        return ''
    endif
    return get(b:syntastic_balloons, v:beval_lnum, '')
endfunction

" vim: set sw=4 sts=4 et fdm=marker:
