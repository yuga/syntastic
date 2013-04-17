if exists("g:loaded_syntastic_notifier_signs")
    finish
endif
let g:loaded_syntastic_notifier_signs = 1

if !exists("g:syntastic_enable_signs")
    let g:syntastic_enable_signs = 1
endif

if !exists("g:syntastic_error_symbol")
    let g:syntastic_error_symbol = '>>'
endif

if !exists("g:syntastic_warning_symbol")
    let g:syntastic_warning_symbol = '>>'
endif

if !exists("g:syntastic_style_error_symbol")
    let g:syntastic_style_error_symbol = 'S>'
endif

if !exists("g:syntastic_style_warning_symbol")
    let g:syntastic_style_warning_symbol = 'S>'
endif

if !has('signs')
    let g:syntastic_enable_signs = 0
endif


" start counting sign ids at 5000, start here to hopefully avoid conflicting
" with any other code that places signs (not sure if this precaution is
" actually needed)
let s:first_sign_id = 5000
let s:next_sign_id = s:first_sign_id

let g:SyntasticSignsNotifier = {}

let s:setup_done = 0

" Public methods {{{1

function! g:SyntasticSignsNotifier.New()
    let newObj = copy(self)

    if !s:setup_done
        call self._setup()
        let s:setup_done = 1
    endif

    return newObj
endfunction

function! g:SyntasticSignsNotifier.enabled()
    return exists('b:syntastic_enable_signs') ? b:syntastic_enable_signs : g:syntastic_enable_signs
endfunction

" Update the error signs
function! g:SyntasticSignsNotifier.refresh(loclist)
    let old_signs = self._getSignsList(a:loclist)
    call self._signErrors(a:loclist)
    call self._removeSigns(a:loclist, old_signs)

    let s:first_sign_id = s:next_sign_id
endfunction

" Private methods {{{1

" One time setup: define our own sign types and highlighting
function! g:SyntasticSignsNotifier._setup()
    if has('signs')
        if !hlexists('SyntasticErrorSign')
            highlight link SyntasticErrorSign error
        endif
        if !hlexists('SyntasticWarningSign')
            highlight link SyntasticWarningSign todo
        endif
        if !hlexists('SyntasticStyleErrorSign')
            highlight link SyntasticStyleErrorSign SyntasticErrorSign
        endif
        if !hlexists('SyntasticStyleWarningSign')
            highlight link SyntasticStyleWarningSign SyntasticWarningSign
        endif
        if !hlexists('SyntasticStyleErrorLine')
            highlight link SyntasticStyleErrorLine SyntasticErrorLine
        endif
        if !hlexists('SyntasticStyleWarningLine')
            highlight link SyntasticStyleWarningLine SyntasticWarningLine
        endif

        " define the signs used to display syntax and style errors/warns
        exe 'sign define SyntasticError text=' . g:syntastic_error_symbol .
            \ ' texthl=SyntasticErrorSign linehl=SyntasticErrorLine'
        exe 'sign define SyntasticWarning text=' . g:syntastic_warning_symbol .
            \ ' texthl=SyntasticWarningSign linehl=SyntasticWarningLine'
        exe 'sign define SyntasticStyleError text=' . g:syntastic_style_error_symbol .
            \ ' texthl=SyntasticStyleErrorSign linehl=SyntasticStyleErrorLine'
        exe 'sign define SyntasticStyleWarning text=' . g:syntastic_style_warning_symbol .
            \ ' texthl=SyntasticStyleWarningSign linehl=SyntasticStyleWarningLine'
    endif
endfunction

" Returns the current list of signs indexed by buffer
function! g:SyntasticSignsNotifier._getSignsList(loclist)
    let signs = {}

    for buf in a:loclist.getBuffers()
        let b = str2nr(buf)
        let signs[b] = copy(getbufvar(b, 'syntastic_signs', []))
    endfor

    return signs
endfunction

" Place signs by all syntax errors in all buffers
function! g:SyntasticSignsNotifier._signErrors(loclist)
    for buf in a:loclist.getBuffers()
        let b = str2nr(buf)
        let slist = getbufvar(b, 'syntastic_signs', [])

        " make sure the errors come after the warnings, so that errors mask
        " the warnings on the same line, not the other way around
        let issues = a:loclist.getQuietWarnings() ? [] : a:loclist.warnings(b)
        call extend(issues, a:loclist.errors(b))

        for i in issues
            let sign_severity = i['type'] ==? 'W' ? 'Warning' : 'Error'
            let sign_subtype = get(i, 'subtype', '')
            let sign_type = 'Syntastic' . sign_subtype . sign_severity

            exec "sign place " . s:next_sign_id . " line=" . i['lnum'] . " name=" . sign_type . " buffer=" . i['bufnr']
            call add(slist, s:next_sign_id)
            let s:next_sign_id += 1
        endfor

        call setbufvar(b, 'syntastic_signs', slist)
    endfor
endfunction

" Remove the signs with the given ids from all buffers
function! g:SyntasticSignsNotifier._removeSigns(loclist, signs)
    for buf in a:loclist.getBuffers()
        let b = str2nr(buf)
        let slist = getbufvar(b, 'syntastic_signs', [])

        for i in reverse(copy(a:signs[b]))
            exec "sign unplace " . i
            call remove(slist, index(slist, i))
        endfor

        call setbufvar(b, 'syntastic_signs', slist)
    endfor
endfunction

" vim: set sw=4 sts=4 et fdm=marker:
