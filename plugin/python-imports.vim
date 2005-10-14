" File: python-imports.vim
" Author: Marius Gedminas <mgedmin@b4net.lt>
" Version: 0.1
" Last Modified: 2005-02-18
"
" Overview
" --------
" Vim script to help adding import statements in Python modules.
"
" You need to have a tags file built.
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

    " Try to jump to a tag in a new window
    let v:errmsg = ""
    exec "stjump" l:name
    if v:errmsg != ""
        " Tag not found, bail out
        return
    endif
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
    " Close the window containing the tag
    close
    " Find the place for adding the import statement
    if !a:here
        1                               " Go to the top
        silent! /^"""/;/^"""/           " Skip docstring, if it exists
        silent! /^import\|^from/        " Find the first import statement
        normal }                        " Find the first empty line after that
    endif
    " Find out the indentation of the current line
    let indent = matchstr(getline("."), "^[ \t]*\\%(>>> \\)\\=")
    " Add an import statement
    put! = indent . 'from ' . pkg . ' import ' . l:name
endf

command! -nargs=? -complete=tag ImportName	call ImportName(<q-args>, 0)
command! -nargs=? -complete=tag ImportNameHere	call ImportName(<q-args>, 1)
