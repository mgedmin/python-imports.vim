" File: python-imports.vim
" Author: Marius Gedminas <marius@gedmin.as>
" Version: 0.2
" Last Modified: 2007-01-05
"
" Overview
" --------
" Vim script to help adding import statements in Python modules.
"
" You need to have a tags file built (:!ctags -R .).
"
" Type :ImportName <name> to add an import statement at the top.
" Type :ImportNameHere <name> to add an import statement above the current
" line.
"
" I use mappings like the following one to import the name under cursor with a
" single keystroke
"   map <buffer> <F5>    :ImportName <C-R><C-W><CR>
"   map <buffer> <C-F5>  :ImportNameHere <C-R><C-W><CR>
"
" Installation
" ------------
" 1. Copy this file to $HOME/.vim/plugin directory
" 2. Run Vim and open any python file.
"
" Needs Vim 7.0

" Hardcoded names and locations
let g:pythonImports = {'removeSecurityProxy': 'zope.security.proxy'}

function! CurrentPythonModule()
" Figure out the dotted module name of the current buffer

    " Look at the file name of the module that contains this tag.  Find the
    " nearest parent directory that does not have __init__.py.  Assume it is
    " directly included in PYTHONPATH.
    let pkg = expand("%:p")
    let root = fnamemodify(pkg, ":h")
    while strlen(root)
        if !filereadable(root . "/__init__.py")
            break
        endif
        let root = fnamemodify(root, ":h")
    endwhile
    let pkg = strpart(pkg, strlen(root))
    " Convert the relative path into a Python dotted module name
    let pkg = substitute(pkg, ".py$", "", "")
    let pkg = substitute(pkg, ".__init__$", "", "")
    let pkg = substitute(pkg, "^/", "", "g")
    let pkg = substitute(pkg, "/", ".", "g")
    " Get rid of the last module name if it starts with an underscore, e.g.
    " zope.schema._builtinfields -> zope.schema
    let pkg = substitute(pkg, "[.]_[a-zA-Z0-9_]*$", "", "")
    " Convert top-level zc_foo/zope_foo names into zc.foo/zope.foo
    let pkg = substitute(pkg, '^\([a-z]\+\)_\([a-z]\+\)', '\1.\2', "")
    " Close the window containing the tag
    return pkg
endfunction

function! FindPlaceForImport(pkg, name)
" Find the appropriate place to insert a "from pkg import name" line.

    1                               " Go to the top
    silent! 0/^"""/;/^"""/          " Skip docstring, if it exists
    silent! /^import\|^from/        " Find the first import statement
    " Find the first empty line after that.  NOTE: DO NOT put any comments
    " on the line that says `normal`, or you'll get 24 extra spaces here
    normal }
    " Try to find an existing import from the same package, and move to
    " the last one of these
    let stmt = "from ".a:pkg." import"
    exec "silent! /^".stmt."/;/^\\(".stmt."\\)\\@!/"
endfunction

function! ImportName(name, here)
" Add an import statement for 'name'.  If 'here' is true, adds the statement
" on the line above the cursor, if 'here' is false, adds the line to the top
" of the current file.

    " If name is empty, pick up the word under cursor
    if a:name == ""
        let l:name = expand("<cword>")
    else
        let l:name = a:name
    endif

    " Look for hardcoded names
    if has_key(g:pythonImports, l:name)
        let pkg = g:pythonImports[l:name]
    else
        " Try to jump to a tag in a new window
        let v:errmsg = ""
        let l:oldfile = expand('%')
        exec "stjump" l:name
        if v:errmsg != ""
            " Give up and bail out
            return
        else
            if l:oldfile == expand('%')
                " Either the user aborted the tag jump, or the tag exists in
                " the same file, and therefore import is pointless
                return
            endif 
            " Look at the file name of the module that contains this tag.  Find the
            " nearest parent directory that does not have __init__.py.  Assume it is
            " directly included in PYTHONPATH.
            let pkg = CurrentPythonModule()
            " Close the window containing the tag
            close
        endif
    endif

    " Find the place for adding the import statement
    if !a:here
        if search('^from ' . pkg . ' import ' . l:name . '$', 'bcw')
            " import already exists
            return
        endif
        call FindPlaceForImport(pkg, l:name)
    endif
    " Find out the indentation of the current line
    let indent = matchstr(getline("."), "^[ \t]*\\%(>>> \\)\\=")
    " Add an import statement
    put! = indent . 'from ' . pkg . ' import ' . l:name
endf

command! -nargs=? -complete=tag ImportName	call ImportName(<q-args>, 0)
command! -nargs=? -complete=tag ImportNameHere	call ImportName(<q-args>, 1)
