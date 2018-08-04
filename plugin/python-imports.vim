" File: python-imports.vim
" Author: Marius Gedminas <marius@gedmin.as>
" Version: 1.2
" Last Modified: 2018-05-14
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
" 1. Copy this file to $HOME/.vim/plugin directory
" 2. Run Vim and open any python file.
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
"    import module1, module2
"    from package.module import name1, name2
" Continuation lines and parenthesized name lists are not supported

if v:version < 700
    finish
endif

" Hardcoded names and locations
" g:pythonImports[module] = '' for module imports
" g:pythonImports[name] = 'module' for other imports
let g:pythonImports = {'print': '__future__'}

if has("python") || has("python3")
    let s:python = has("python3") ? "python3" : "python"
    exec s:python "import sys, vim"
    exec s:python "vim.command(\"let g:pythonStdlibPath = '/usr/lib/python%d.%d'\" % sys.version_info[:2])"
    exec s:python "for m in sys.builtin_module_names: vim.command(\"let g:pythonImports['%s'] = ''\" % m)"
else
    let _py_versions = glob('/usr/lib/python?.*', 1, 1)
    if _py_versions != []
        " use latest version (assuming glob sorts the list)
        let g:pythonStdlibPath = _py_versions[-1]
    else
        " what, you don't have Python installed on this machine?
        let g:pythonStdlibPath = ""
    endif
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
    if !has('python') && !has('python3')
        echoer "Need Python support: I'm not implementing a config file parser in vimscript!"
        return
    endif
    exec s:python "<< END"
def parse_python_imports_cfg(filename, verbose=False):
    import re
    DOTTEDNAME = '[a-zA-Z_.][a-zA-Z_0-9.]*'
    NAME = '[a-zA-Z_][a-zA-Z_0-9]*'
    NAMES = NAME + r'(\s*,\s*' + NAME + ')*'
    for line in open(filename):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m = re.match(r'^import\s*(' + NAMES + ')$', line)
        if m:
            names = m.group(1).split(',')
            for name in names:
                if verbose:
                    print(name.strip())
                vim.command("let g:pythonImports['%s'] = ''" % name.strip())
            continue
        m = re.match(r'^from\s*(' + DOTTEDNAME + ')\s*import\s*(' + NAMES + ')$', line)
        if m:
            modname = m.group(1)
            names = m.group(2).split(',')
            for name in names:
                if verbose:
                    print('%s from %s' % (name.strip(), modname))
                vim.command("let g:pythonImports['%s'] = '%s'" % (name.strip(), modname))
            continue

parse_python_imports_cfg(vim.eval('filename'), int(vim.eval('&verbose')))
END
endf

if has('python') || has('python3')
    call LoadPythonImports()
endif

function! IsStdlibModule(name)
" Does a:name refer to a standard library module?
    if g:pythonStdlibPath == ""
        return 0
    endif
    if filereadable(g:pythonStdlibPath . "/" . a:name . ".py")
        return 1
    endif
    if filereadable(g:pythonStdlibPath . "/" . a:name . "/__init__.py")
        return 1
    endif
    if filereadable(g:pythonStdlibPath . "/lib-dynload/" . a:name . ".so")
        return 1
    endif
    return 0
endf

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
    let pkg = substitute(pkg, "[.]py$", "", "")
    let pkg = substitute(pkg, ".__init__$", "", "")
    let pkg = substitute(pkg, "^/", "", "")
    let pkg = substitute(pkg, "^site-packages/", "", "")
    let pkg = substitute(pkg, "/", ".", "g")
    " Get rid of the last module name if it starts with an underscore, e.g.
    " zope.schema._builtinfields -> zope.schema
    let pkg = substitute(pkg, "[.]_[a-zA-Z0-9_]*$", "", "")
    " Convert top-level zc_foo/zope_foo names into zc.foo/zope.foo
    " XXX: where have I found those???
""  let pkg = substitute(pkg, '^\([a-z]\+\)_\([a-z]\+\)', '\1.\2', "")
    " HAAAACK: when src/ivija is a symlink to trunk, I get trunk.foo.bar
    "          instead of ivija.foo.bar
""  let hack = fnamemodify('src/ivija/', ':p:h:t')
""  let pkg = substitute(pkg, '^' . hack . '[.]', 'ivija.', "")
    return pkg
endfunction

function! CurrentPythonPackage()
    let pkg = CurrentPythonModule()
    let pkg = substitute(pkg, '[.]\=[^.]\+$', '', '')
    return pkg
endfunction

function! FindPlaceForImport(pkg, name)
" Find the appropriate place to insert a "from pkg import name" line.

    " Go to the top (use 'normal gg' because I want to set the ' mark)
    normal gg
    keepjumps silent! 0/^"""/;/^"""/           " Skip docstring, if it exists
    keepjumps silent! /^import\|^from.*import/ " Find the first import statement
    nohlsearch
    if a:pkg == '__future__'
        return
    endif
    " Find the first empty line after that.  NOTE: DO NOT put any comments
    " on the line that says `normal`, or you'll get 24 extra spaces here
    keepjumps normal }
    " Try to find an existing import from the same module, and move to
    " the last one of these
    let pkg = a:pkg
    while pkg != ""
        let stmt = "from ".pkg." "      " look for an exact match first
        if search('^' . stmt, 'cnw')
            exec "keepjumps silent! /^".stmt."/;/^\\(".stmt."\\)\\@!/"
            nohlsearch
            break
        endif
        let stmt = "from ".pkg."."      " try siblings or subpackages
        if search('^' . stmt, 'cnw')
            exec "keepjumps silent! /^".stmt."/;/^\\(".stmt."\\)\\@!/"
            nohlsearch
            break
        endif
        " If not found, look for imports coming from containing packages
        if pkg =~ '[.]'
            let pkg = substitute(pkg, '[.][^.]*$', '', '')
        else
            break
        endif
    endwhile
endfunction

function! ImportName(name, here, stay)
" Add an import statement for 'name'.  If 'here' is true, adds the statement
" on the line above the cursor, if 'here' is false, adds the line to the top
" of the current file.  If 'stay' is true, keeps cursor position, otherwise
" jumps to the line containing the newly added import statement.

    " If name is empty, pick up the word under cursor
    if a:name == ""
        let l:name = expand("<cword>")
    else
        let l:name = a:name
    endif

    " Look for hardcoded names
    if has_key(g:pythonImports, l:name)
        let pkg = g:pythonImports[l:name]
    elseif IsStdlibModule(l:name)
        let pkg = ''
    else
        " Let's see if we have one tag, or multiple tags (in which case we'll
        " let the user decide)
        let tag_rx = "^\\C" . l:name . "\\([.]py\\)\\=$"
        let found = taglist(tag_rx)
        if found == []
            " Give up and bail out
           echohl Error | echomsg "Tag not found:" l:name | echohl None
           return
        endif
        " Try to jump to the tag in a new window
        let v:errmsg = ""
        let l:oldfile = expand('%')
        let l:oldswb = &switchbuf
        set switchbuf=split
        let l:oldwinnr = winnr()
        try
            exec "stjump /" . tag_rx
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
        if expand('%:t') == l:name . ".py"
            let pkg = CurrentPythonPackage()
        else
            let pkg = CurrentPythonModule()
        endif
        " Close the window containing the tag
        close
        " Return to the right window
        exec l:oldwinnr "wincmd w"
    endif

    if pkg == ""
        let line_to_insert = 'import ' . l:name
    elseif pkg == "__future__" && l:name == "print"
        let line_to_insert = 'from __future__ import print_function'
    else
        let line_to_insert = 'from ' . pkg . ' import ' . l:name
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
    if indent != "" && getline(line(".")-1) == 'from ' . pkg . ' import ('
        let line_to_insert = l:name . ','
    endif
    let line_to_insert = indent . line_to_insert
    " Double check with indent / parenthesized form
    if search('^' . line_to_insert . '$', 'cnw')
        " import already exists
        redraw
        echomsg l:name . " is already imported"
        return
    endif
    " Add the import statement
    put! =line_to_insert
    " Jump back if possible
    if a:stay
        normal ``
    endif
    " Refresh ALE because otherwise it gets all confused for a bit
    if exists("*ALELint")
        ALEResetBuffer
        ALELint
    endif
endf

command! -nargs=? -bang -complete=tag ImportName	call ImportName(<q-args>, 0, <q-bang> == "!")
command! -nargs=? -bang -complete=tag ImportNameHere	call ImportName(<q-args>, 1, <q-bang> == "!")
