" File: python-imports.vim
" Author: Marius Gedminas <marius@gedmin.as>
" Version: 2.0
" Last Modified: 2023-01-04
"
" Overview
" --------
" Vim script to help adding import statements in Python modules.
"
" You need to have a tags file built (:!ctags -R .).
"
" Type :ImportName [<name>] to add an import statement at the top.
" Type :ImportNameHere [<name>] to add an import statement above the current
" line.
"
" I use mappings like the following one to import the name under cursor with a
" single keystroke
"   map <buffer> <F5>    :ImportName<CR>
"   map <buffer> <C-F5>  :ImportNameHere<CR>
"
" Installation
" ------------
" I like plugin managers like vim-plug.
"
" Needs Vim 7.0, preferably built with Python support.
"
" Tested on Linux only.
"
" Configuration
" -------------
" In addition to the tags file (and builtin + stdlib modules), you can define
" your favourite imports in a file called ~/.vim/python-imports.cfg.  That
" file should contain Python import statements like
"    import module1, module2 as alias1, module3
"    from package.module import name1, name2 as alias2, name3
" Continuation lines are not supported.
"
" Bugs
" ----
" The logic for detecting already imported names is not very clever.
" The logic for finding the right place to put an import is not very clever
" either.  Sometimes it might introduce syntax errors.
" This plugin expects your imports to look like
"    import module
"    from package.module import name
" Parenthesized name lists are partially supported, if you use one name per
" line, i.e.
"    from package.module import (
"        name1,
"        name2,
"    )
" Documentation is scant.
" Syntax errors in the config file are silently ignored.

if v:version < 700
    finish
endif

" Hardcoded names and locations
" g:pythonImports[module] = '' for module imports
" g:pythonImports[name] = 'module' for other imports
if !exists("g:pythonImports")
    let g:pythonImports = {'print': '__future__'}
endif

" g:pythonImportAliases[alias] = name for module imports using aliases, e.g.
" g:pythonImportAliases['sa'] = 'sqlalchemy' means that you want to 'import sqlalchemy as sa'
if !exists("g:pythonImportAliases")
    let g:pythonImportAliases = {}
endif

if has("python") || has("python3")
    let s:python = has("python3") ? "python3" : "python"
    exec s:python "import sys, vim"
    if !exists("g:pythonStdlibPath")
        exec s:python "vim.command(\"let g:pythonStdlibPath = '%s/lib/python%d.%d'\" % (getattr(sys, 'base_prefix', getattr(sys, 'real_prefix', sys.prefix)), sys.version_info[0], sys.version_info[1]))"
    endif
    if !exists("g:pythonBuiltinModules")
        let g:pythonBuiltinModules = {}
        exec s:python "for m in sys.builtin_module_names: vim.command(\"let g:pythonBuiltinModules['%s'] = ''\" % m)"
    endif
    if !exists("g:pythonExtModuleSuffix")
        exec s:python "import sysconfig"
        " grr neovim doesn't have pyxeval()
        let s:expr = "sysconfig.get_config_var('EXT_SUFFIX') or '.so'"
        let g:pythonExtModuleSuffix = has("python3") ? py3eval(s:expr) : pyeval(s:expr)
    endif
elseif !exists("g:pythonStdlibPath")
    let _py_versions = glob('/usr/lib/python?.*', 1, 1)
    if _py_versions != []
        " use latest version (assuming glob sorts the list)
        let g:pythonStdlibPath = _py_versions[-1]
    else
        " what, you don't have Python installed on this machine?
        let g:pythonStdlibPath = ""
    endif
endif

if !exists("g:pythonExtModuleSuffix")
    let g:pythonExtModuleSuffix = ".so"
endif

if !exists("g:pythonBuiltinModules")
    " based on python3.6 on linux, with all private ones removed
    let g:pythonBuiltinModules = {
          \ 'array': '',
          \ 'atexit': '',
          \ 'binascii': '',
          \ 'builtins': '',
          \ 'cmath': '',
          \ 'errno': '',
          \ 'faulthandler': '',
          \ 'fcntl': '',
          \ 'gc': '',
          \ 'grp': '',
          \ 'itertools': '',
          \ 'marshal': '',
          \ 'math': '',
          \ 'posix': '',
          \ 'pwd': '',
          \ 'pyexpat': '',
          \ 'select': '',
          \ 'spwd': '',
          \ 'sys': '',
          \ 'syslog': '',
          \ 'time': '',
          \ 'unicodedata': '',
          \ 'xxsubtype': '',
          \ 'zipimport': '',
          \ 'zlib': '',
          \ }
endif

if !exists("g:pythonPaths")
    let g:pythonPaths = []
endif

if !exists("g:pythonImportsUseAleFix")
    let g:pythonImportsUseAleFix = 1
endif

if v:version >= 801 || v:version == 800 && has("patch-499")
    function! s:taglist(tag, filename)
        return taglist(a:tag, a:filename)
    endf
else
    function! s:taglist(tag, filename)
        return taglist(a:tag)
    endf
endif

function! LoadPythonImports(...)
    if a:0 == 0
        let filename = expand('~/.vim/python-imports.cfg')
        if !filereadable(filename)
            if &verbose > 0
                echo "skipping" filename "because it does not exist or is not readable"
            endif
            return
        endif
    elseif a:0 == 1
        let filename = a:1
    else
        echoerr "too many arguments: expected one (filename)"
        return
    endif
    if &verbose > 0
        echo "python-imports.vim: loading" filename
    endif
    if !has('python3')
        echoer "Need Python 3 support: I'm not implementing a config file parser in vimscript!"
        return
    endif
    exec s:python "<< END"
import python_imports
python_imports.parse_python_imports_cfg(vim.eval('filename'), int(vim.eval('&verbose')))
END
endf

if has('python3')
    call LoadPythonImports()
endif

function! IsStdlibModule(name)
    return pythonimports#is_stdlib_module(name)
endf

function! CurrentPythonModule()
    return pythonimports#filename2module(expand("%"))
endfunction

function! CurrentPythonPackage()
    return pythonimports#filename2package(expand("%"))
endfunction

function! FindPlaceForImport(pkg, name)
    call pythonimports#find_place_for_import(a:pkg, a:name)
endfunction

function! ImportName(name, here, stay)
" Add an import statement for 'name'.  If 'here' is true, adds the statement
" on the line above the cursor, if 'here' is false, adds the line to the top
" of the current file.  If 'stay' is true, keeps cursor position, otherwise
" jumps to the line containing the newly added import statement.

    call pythonimports#maybe_reload_config()

    " If name is empty, pick up the word under cursor
    if a:name == ""
        let name = expand("<cword>")
    else
        let name = a:name
    endif

    let alias = l:name
    let l:name = get(g:pythonImportAliases, alias, alias)

    " Look for hardcoded names
    if has_key(g:pythonImports, l:name)
        let pkg = g:pythonImports[l:name]
    elseif pythonimports#is_stdlib_module(l:name)
        let pkg = ''
    else
        " Let's see if we have one tag, or multiple tags (in which case we'll
        " let the user decide)
        let tag_rx = "^\\C" . l:name . "\\([.]py\\)\\=$"
        let found = s:taglist(tag_rx, expand("%"))
        if found == []
            " Give up and bail out
            echohl Error | echomsg "Tag not found:" l:name | echohl None
            return
        elseif len(found) == 1
            " Only one name found, we can skip the selection menu and the
            " whole costly procedure of opening split windows.
            let pkg = pythonimports#filename2module(found[0].filename)
        else
            " Try to jump to the tag in a new window
            let v:errmsg = ""
            let l:oldfile = expand('%')
            let l:oldswb = &switchbuf
            set switchbuf=split
            let l:oldwinnr = winnr()
            try
                exec "noautocmd stjump /" . tag_rx
            finally
                let &switchbuf = l:oldswb
            endtry
            if v:errmsg != ""
                " Something bad happened (maybe the other file is opened in a
                " different vim instance and there's a swap file)
                if l:oldfile != expand('%')
                    close
                    exec l:oldwinnr "wincmd w"
                endif
                return
            endif
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
            " Return to the right window
            exec l:oldwinnr "wincmd w"
        endif
        if fnamemodify(pkg, 't') == l:name . ".py"
            let pkg = pythonimports#package_of(pkg)
        endif
    endif

    if pkg == ""
        let line_to_insert = 'import ' . l:name
    elseif pkg == "__future__" && l:name == "print"
        let line_to_insert = 'from __future__ import print_function'
    else
        let line_to_insert = 'from ' . pkg . ' import ' . l:name
    endif
    if l:alias != l:name
        let line_to_insert .= ' as ' . l:alias
    endif

    " Find the place for adding the import statement
    if !a:here
        if search('^' . line_to_insert . '$', 'bcnw')
            " import already exists
            redraw
            echomsg l:name . " is already imported"
            return
        endif
        call FindPlaceForImport(pkg, l:name)
    endif
    " Find out the indentation of the current line
    let indent = matchstr(getline("."), "^[ \t]*\\%(>>> \\)\\=")
    " Check if we're using parenthesized imports already
    let prev_line = getline(line(".")-1)
    if indent != "" && prev_line  == 'from ' . pkg . ' import ('
        if l:alias != l:name
            let line_to_insert = l:name . ' as ' . l:alias . ','
        else
            let line_to_insert = l:name . ','
        endif
    elseif indent != "" && prev_line =~ '^from .* import ('
        silent! /)/+1
        nohlsearch
        if line(".") == line("$") && getline(line(".")-1) !~ ')'
            put =''
        endif
        let indent = ""
    endif
    let line_to_insert = indent . line_to_insert
    " Double check with indent / parenthesized form
    if !a:here && search('^' . line_to_insert . '$', 'cnw')
        " import already exists
        redraw
        echomsg l:name . " is already imported"
        return
    endif
    " Add the import statement
    put! =line_to_insert
    " Adjust import location with isort if possible
    if !a:here && g:pythonImportsUseAleFix && exists(":ALEFix") == 2
      ALEFix isort
    endif
    " Jump back if possible
    if a:stay
        normal ``
    endif
    " Refresh ALE because otherwise it gets all confused for a bit
    if exists(":ALELint") == 2
        if exists(":ALEResetBuffer") == 2
            ALEResetBuffer
        endif
        ALELint
    endif
endf

command! -nargs=? -bang -complete=tag ImportName	call ImportName(<q-args>, 0, <q-bang> == "!")
command! -nargs=? -bang -complete=tag ImportNameHere	call ImportName(<q-args>, 1, <q-bang> == "!")
