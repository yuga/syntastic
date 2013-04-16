if exists("g:loaded_syntastic_notifier_cursor")
    finish
endif
let g:loaded_syntastic_notifier_cursor = 1

if !exists('g:syntastic_echo_current_error')
    let g:syntastic_echo_current_error = 1
endif

let g:SyntasticCursorNotifier = {}

" Public methods {{{1

function! g:SyntasticCursorNotifier.New()
    let newObj = copy(self)
    return newObj
endfunction

function! g:SyntasticCursorNotifier.refresh(loclist)
    autocmd! syntastic CursorMoved
    let enabled = exists('b:syntastic_echo_current_error') ? b:syntastic_echo_current_error : g:syntastic_echo_current_error
    if enabled && a:loclist.hasIssuesToDisplay()
        let b:syntastic_messages = a:loclist.messages()
        let b:oldLine = -1
        autocmd syntastic CursorMoved * call g:SyntasticRefreshCursor()
    endif
endfunction

function! g:SyntasticCursorNotifier.reset(loclist)
    for buf in a:loclist.getBuffers()
        " TODO: there is no way to unlet variables in buffers,
        " the best we can do is to set them to {}
        call setbufvar(str2nr(buf), 'syntastic_messages', {})
        call setbufvar(str2nr(buf), 'oldLine', -1)
    endfor
endfunction

" Private methods {{{1

" The following defensive nonsense is needed because of the nature of autocmd
function! g:SyntasticRefreshCursor()
    if !exists('b:syntastic_messages') || empty(b:syntastic_messages)
        " file not checked
        return
    endif

    if !exists('b:oldLine')
        let b:oldLine = -1
    endif
    let l = line('.')
    if l == b:oldLine
        return
    endif
    let b:oldLine = l

    if has_key(b:syntastic_messages, l)
        call syntastic#util#wideMsg(b:syntastic_messages[l])
    else
        echo
    endif
endfunction

" vim: set sw=4 sts=4 et fdm=marker:
