if exists("g:loaded_syntastic_loclist")
    finish
endif
let g:loaded_syntastic_loclist = 1

let g:SyntasticLoclist = {}

" Public methods {{{1

" constructor
function! g:SyntasticLoclist.New(rawLoclist)
    let newObj = copy(self)
    let newObj._quietWarnings = g:syntastic_quiet_warnings

    let llist = copy(a:rawLoclist)
    let llist = filter(llist, 'v:val["valid"] == 1')

    for e in llist
        if empty(e['type'])
            let e['type'] = 'E'
        endif
    endfor

    let newObj._rawLoclist = llist
    let newObj._owner = bufnr("")
    call newObj._resetCaches()

    return newObj
endfunction

" returns the raw loclist
function! g:SyntasticLoclist.toRaw()
    return copy(self._rawLoclist)
endfunction

" extends loclist
function! g:SyntasticLoclist.extend(other)
    call extend(self._rawLoclist, a:other.toRaw())
    call self._resetCaches()
endfunction

" returns true if there are issues to display in any buffer
" filtered by g:syntastic_quiet_warnings
function! g:SyntasticLoclist.isEmpty()
    return empty(self.filterByQuietFlagCached())
endfunction

" display the cached errors for this buf in the location list
function! g:SyntasticLoclist.show()
    call setloclist(0, self.filterByQuietFlagCached())
    if self.hasIssuesToDisplay()
        let num = winnr()
        exec "lopen " . g:syntastic_loc_list_height
        if num != winnr()
            wincmd p
        endif
    endif
endfunction

" returns the main buffer from which loclist was created
function! g:SyntasticLoclist.getOwner()
    return self._owner
endfunction

" returns g:syntastic_quiet_warnings at the time this instance was created
function! g:SyntasticLoclist.getQuietWarnings()
    return self._quietWarnings
endfunction

" returns the list of buffers referenced by loclist
" main buffer is included too, even if it doesn't have errors
function! g:SyntasticLoclist.getBuffers()
    let llist = copy(self.filterByQuietFlagCached())
    return syntastic#util#unique(map( llist, 'v:val["bufnr"]' ) + [self.getOwner()])
endfunction

" sets b:syntastic_loclist for all buffers referenced by loclist
function! g:SyntasticLoclist.updateBuffers()
    for buf in self.getBuffers()
        call setbufvar(str2nr(buf), 'syntastic_loclist', self)
    endfor
endfunction

" deletes b:syntastic_loclist from all buffers referenced by loclist
" TODO: there is no way to unlet variables in buffers,
" the best we can do is to set them to {}
function! g:SyntasticLoclist.resetBuffers()
    for buf in self.getBuffers()
        call setbufvar(str2nr(buf), 'syntastic_loclist', {})
    endfor
endfunction

" filter the list and return new native loclist e.g.
"
"  .filter({'bufnr': 10, 'type': 'e'})
"
" would return all errors for buffer 10.
"
" note that all comparisons are done with ==?
function! g:SyntasticLoclist.filter(filters)
    let rv = []

    for error in self._rawLoclist

        let passes_filters = 1
        for key in keys(a:filters)
            if error[key] !=? a:filters[key]
                let passes_filters = 0
                break
            endif
        endfor

        if passes_filters
            call add(rv, error)
        endif
    endfor
    return rv
endfunction

" returns loclist filtered according to g:syntastic_quiet_warnings
" caches results
function! g:SyntasticLoclist.filterByQuietFlagCached()
    if !exists("self._cachedFiltered")
        let self._cachedFiltered = copy(self._quietWarnings ? self.filter({'type': 'E'}) : self._rawLoclist)
    endif
    return self._cachedFiltered
endfunction

" Public methods localized to a buffer {{{1

" returns b:syntastic_loclist for a given buffer
" creates a new loclist if there is no b:syntastic_loclist yet
function! g:SyntasticLoclist.current(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    let llist = getbufvar(buf, 'syntastic_loclist', {})
    if empty(llist)
        let llist = g:SyntasticLoclist.New([])
        call setbufvar(buf, 'syntastic_loclist', llist)
    endif
    return llist
endfunction

" returns the errors or warnings to be displayed in a given buffer,
" filtered by g:syntastic_quiet_warnings
function! g:SyntasticLoclist.getIssuesToDisplay(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    return self._quietWarnings ? self.errors(buf) : self.filterByBufferCached(buf)
endfunction

" returns true if there are errors or warnings to be displayed
" in a given buffer, filtered by g:syntastic_quiet_warnings
function! g:SyntasticLoclist.hasIssuesToDisplay(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    if !has_key(self._hasIssuesToDisplay, buf)
        let self._hasIssuesToDisplay[buf] = len(self.getIssuesToDisplay(buf))
    endif
    return self._hasIssuesToDisplay[buf]
endfunction

" returns the list of errors in a given buffer
function! g:SyntasticLoclist.errors(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    if !has_key(self._cachedErrors, buf)
        let self._cachedErrors[buf] = self.filter({'type': 'E', 'bufnr': buf})
    endif
    return self._cachedErrors[buf]
endfunction

" returns the list of warnings in a given buffer
" g:syntastic_quiet_warnings is not consulted
function! g:SyntasticLoclist.warnings(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    if !has_key(self._cachedWarnings, buf)
        let self._cachedWarnings[buf] = self.filter({'type': 'W', 'bufnr': buf})
    endif
    return self._cachedWarnings[buf]
endfunction

" returns the list of messages in a given buffer, filtered by
" g:syntastic_quiet_warnings; caches results for g:SyntasticRefreshCursor()
function! g:SyntasticLoclist.messages(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    if !has_key(self._cachedMessages, buf)
        let self._cachedMessages[buf] = {}

        for e in self.errors(buf)
            if !has_key(self._cachedMessages[buf], e['lnum'])
                let self._cachedMessages[buf][e['lnum']] = e['text']
            endif
        endfor

        if !self._quietWarnings
            for e in self.warnings(buf)
                if !has_key(self._cachedMessages[buf], e['lnum'])
                    let self._cachedMessages[buf][e['lnum']] = e['text']
                endif
            endfor
        endif
    endif

    return self._cachedMessages[buf]
endfunction

" returns loclist filtered by a given buffer
" g:syntastic_quiet_warnings is not consulted
function! g:SyntasticLoclist.filterByBufferCached(...)
    let buf = a:0 ? str2nr(a:1) : bufnr("")
    if !has_key(self._cachedLoclist, buf)
        let self._cachedLoclist[buf] = self.filter({'bufnr': buf})
    endif
    return self._cachedLoclist[buf]
endfunction

" Private methods {{{1

" resets local caches
function! g:SyntasticLoclist._resetCaches()
    let self._hasIssuesToDisplay = {}
    let self._cachedLoclist = {}
    let self._cachedErrors = {}
    let self._cachedWarnings = {}
    let self._cachedMessages = {}
    if exists("self._cachedFiltered")
        unlet! self._cachedFiltered
    endif
endfunction

" Non-method functions {{{1

" hides the error window
function! g:SyntasticLoclistHide()
    silent! lclose
endfunction

" vim: set sw=4 sts=4 et fdm=marker:
