" quick-preview.vim:  Quickly preview quickfix results without opening files
" Maintainer:         Ronak Gandhi <https://github.com/ronakg>
" Version:            1.0
" Website:            https://github.com/ronakg/quickr-preview.vim

" OpenPreviewWindow() {{
"
" This function opens the specified buffer within the preview window
" while ensuring that the preview window maintains the correct size
" and position.
"
function! OpenPreviewWindow(bufname, linenr)
    let l:size = (g:quickr_preview_size > 0) ? g:quickr_preview_size :
               \ (g:quickr_preview_position =~? '\(left\|right\)') ? winwidth(0)/2 :
               \ (&lines-winheight(0))/2
    let l:orig_preview_height = &previewheight
    execute 'set previewheight='.l:size
    execute 'keepjumps '.g:quickr_preview_pedit_cmd.' +'.a:linenr.' '.a:bufname
    execute 'set previewheight='.l:orig_preview_height
endfunction
" }}

" ClosePreviewWindow() {{
"
" This function closes the preview window while ensuring that the
" qf/loc window maintains the correct size. This should be called
" while in the qf/loc window.
"
function! ClosePreviewWindow()
    let l:orig_win_height = winheight(0)
    pclose
    execute 'resize' l:orig_win_height
endfunction
" }}

" GetPreviewWindow() {{
"
" This function will return the window ID of the preview window;
" if no preview window is currently open it will return zero.
"
function! GetPreviewWindow()
    for l:winnr in range(1, winnr('$'))
        if getwinvar(l:winnr, '&previewwindow')
            return l:winnr
        endif
    endfor
    return 0
endfunction
" }}

" GetLatestQfLocList() {{
"
" This function updates the locally cached qf/loc list (b:qflist)
" if the qf/loc list has not yet been cached, or (for vim 8.1) if
" it detects the qf/loc list has changed since it was last cached.
"
if v:version >= 801
    function! GetLatestQfLocList()
        if !exists('b:qftick')
            let b:qftick = -1
        endif
        " Grab the info for current window
        let l:wininfo = getwininfo(win_getid())[0]
        " Process location list
        if l:wininfo.loclist
            let l:info = getloclist(0, {'changedtick':1, 'size':1})
            if l:info.changedtick != b:qftick
                let b:qflist = getloclist(0)
                let b:qfsize = l:info.size
                let b:qftick = l:info.changedtick
            endif
            return 1
        endif
        " Process quickfix list
        if l:wininfo.quickfix
            let l:info = getqflist({'changedtick':1, 'size':1})
            if l:info.changedtick != b:qftick
                let b:qflist = getqflist()
                let b:qfsize = l:info.size
                let b:qftick = l:info.changedtick
            endif
            return 1
        endif
        " No qf/loc list found
        return 0
    endfunction
else
    function! GetLatestQfLocList()
        if !exists('b:qflist') || !exists('b:qfsize')
            " Grab the location list
            let b:qflist = getloclist(0)
            let b:qfsize = len(b:qflist)
            " If the location list is empty,
            " then grab the qiuckfix list
            if b:qfsize == 0
                let b:qflist = getqflist()
                let b:qfsize = len(b:qflist)
            endif
        endif
        return 1
    endfunction
endif
" }}

" GetValidEntry() {{
"
" This function returns a dictionary containing a valid qf/loc entry
" for the specified line number; where the line number is the current
" line in the qf/loc window. If no valid entry is found, then an empty
" dictionary is returned.
"
function! GetValidEntry(linenr)
    " Ensure this function is run within a qf/loc list
    if &filetype !=# 'qf'
        return {}
    endif
    " Ensure the cached qf/loc list is up to date
    if !GetLatestQfLocList()
        return {}
    endif
    " Ensure the entry exist within the qf/loc list
    if a:linenr > b:qfsize
        return {}
    endif
    " Ensure the current entry is valid
    if !b:qflist[a:linenr-1].valid
        return {}
    endif
    " Ensure the file actually exists
    if !filereadable(bufname(b:qflist[a:linenr-1].bufnr))
        return {}
    endif
    " mck
    let g:qfid = win_getid()
    " mck
    " Return the valid entry
    return b:qflist[a:linenr-1]
endfunction
" }}

" QFMove() {{
"
" Detect when the cursor has moved to a new entry in the qf/loc window,
" and (if so) call QFList() to open the preview window with the buffer
" given by the specified line number; where the line number is the new
" line that the cursor has moved to within the qf/loc window.
"
if has('timers')
    function! QFMove(linenr)
        if a:linenr != b:prvlinenr
            if exists('b:quickr_preview_timer')
                call timer_stop(b:quickr_preview_timer)
            endif
            let b:quickr_preview_timer = timer_start(100, 'InvokeQFList')
        endif
    endfunction
    function! InvokeQFList(timer)
        unlet b:quickr_preview_timer
        call QFList(line('.'))
    endfunction
else
    function! QFMove(linenr)
        if a:linenr != b:prvlinenr
            call QFList(a:linenr)
        endif
    endfunction
endif
" }}

" mck
let g:qfid = 0
function s:QuitAndReturnToQF()
    quit
    "echom "QuitAndReturnToQF: qfid = " . g:qfid
    if g:qfid != 0
        call win_gotoid(g:qfid)
        let g:qfid = 0
    endif
endfunction
" mck

" QFList() {{
"
" Open the preview window and load the buffer given by the specified line
" number; where the line number is the current line in the qf/loc window.
" If no valid buffer exists at the specified line then no action is taken.
"
function! QFList(linenr)
    " Get the current entry and ensure it is valid
    let l:entry = GetValidEntry(a:linenr)
    if empty(l:entry)
        return
    endif
    " mck
    " Close the preview window if the user has selected a same entry again
    "if a:linenr == b:prvlinenr
    "    call ClosePreviewWindow()
    "    let b:prvlinenr = 0
    "    return
    "endif
    " mck
    let b:prvlinenr = a:linenr
    " Check if the buffer of interest is already opened in the preview window
    if GetPreviewWindow() && l:entry.bufnr == b:prvbufnr
        " Go to preview window
        set eventignore+=all
        keepjumps wincmd P
        " Jump to the line of interest
        execute 'keepjumps '.l:entry.lnum.' | normal! zz'
        " Highlight the line of interest
        execute 'match '.g:quickr_preview_line_hl.' /\%'.l:entry.lnum.'l^\s*\zs.\{-}\ze\s*$/'
        " Go back to qf/loc window
        keepjumps wincmd p
        set eventignore-=all
    else
        " Note if the buffer of interest is already listed
        let l:alreadylisted = buflisted(l:entry.bufnr)
        " Open the buffer in the preview window and jump to the line of interest
        call OpenPreviewWindow(bufname(l:entry.bufnr), l:entry.lnum)
        " Go to preview window
        set eventignore+=all
        keepjumps wincmd P
        " Settings for preview window
        " mck
        if !empty(g:quickr_preview_options)
            execute 'setlocal '.g:quickr_preview_options
        endif
        " mck
        " Setting for unlisted buffers
        if !l:alreadylisted
            setlocal nobuflisted        " don't list this buffer
            setlocal noswapfile         " don't create swap file for this buffer
            setlocal bufhidden=delete   " clear out settings when buffer is hidden
            " mck
            setlocal nomodifiable
            " mck
        endif
        " Highlight the line of interest
        execute 'match '.g:quickr_preview_line_hl.' /\%'.l:entry.lnum.'l^\s*\zs.\{-}\ze\s*$/'
        " Go back to qf/loc window
        " mck
        "keepjumps wincmd p
        " mck
        set eventignore-=all
        " mck
        nmap <buffer> <silent> qq              :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> Q               :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> <C-q>           :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> <Leader>qq      :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> <S-F27>         :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> <M-C-P>         :<C-u>call <SID>QuitAndReturnToQF()<CR>
        nmap <buffer> <silent> <Leader><Space> :<C-u>call <SID>QuitAndReturnToQF()<CR>
        "nmap <buffer> <silent> <Space>    <C-f>
        "nmap <buffer> <silent> <BS>       <C-b>
        if exists('g:vimade_loaded')
            call vimade#Enable()
        endif
        highlight NormalPreview ctermbg=237
        if has("nvim")
            setlocal winhighlight=Normal:NormalPreview
        else
            setlocal wincolor=NormalPreview
        endif
        " mck
    endif
    let b:prvbufnr = l:entry.bufnr
endfunction
" }}

" HandleEnterQuickfix() {{
"
" Close the preview window and open the buffer given by the specified
" line number; where where the line number is the current line in the
" qf/loc window. If no valid buffer exists at the specified line then
" no action is taken.
"
function! HandleEnterQuickfix(linenr)
    " Get the current entry and ensure it is valid
    let l:entry = GetValidEntry(a:linenr)
    if empty(l:entry)
        return
    endif
    " Close the preview window
    call ClosePreviewWindow()
    " Open the buffer of interest
    execute "normal! \<cr>"
    " Open any folds we may be in
    silent! foldopen!
    if g:quickr_preview_exit_on_enter
        cclose
    endif
endfunction
" }}

" InitializeQuickrPreview() {{
"
" This function initializes the local (buffer) variables required
" by quickr-preview. This should be called each time a new qf/loc
" buffer is created.
"
function! InitializeQuickrPreview()
    " Initialize default values
    let b:prvlinenr = 0
    let b:prvbufnr = 0
    " Grab the qf/loc list
    call GetLatestQfLocList()
endfunction
" }}

" Auto Commands {{
augroup QuickrPreviewQfAutoCmds
    autocmd! * <buffer>
    " Auto close preview window when closing/deleting the qf/loc list
    autocmd BufDelete <buffer> silent! pclose
    " Auto open preview window while scrolling through the qf/loc list
    if g:quickr_preview_on_cursor
        autocmd CursorMoved <buffer> nested silent call QFMove(line("."))
    endif
augroup END
" }}

" Mappings {{
nnoremap <silent> <buffer> <plug>(quickr_preview) :call QFList(line("."))<CR>
if g:quickr_preview_keymaps
    nmap <leader><space> <plug>(quickr_preview)
endif
nnoremap <buffer> <cr> :silent call HandleEnterQuickfix(line("."))<CR>
" }}

call InitializeQuickrPreview()

