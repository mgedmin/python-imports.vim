function! pythonimports#filename2module(filename)
  " Figure out the dotted module name of the given filename

  " Look at the file name of the module that contains this tag.  Find the
  " nearest parent directory that does not have __init__.py.  Assume it is
  " directly included in PYTHONPATH.
  let pkg = fnamemodify(a:filename, ":p")
  let root = fnamemodify(pkg, ":h")

  " normalize paths
  let pythonPathsNorm = []
  for path in g:pythonPaths
    let path_without_slash = substitute(expand(path), "/$", "", "")
    call add(pythonPathsNorm, path_without_slash)
  endfor

  let found_dir = ""
  let found_path = ""
  while 1
    if index(pythonPathsNorm, root) != -1
      let found_path = root
      break
    endif
    if found_dir == "" && !filereadable(root . "/__init__.py")
      let found_dir = root
      " note: can't break here!  PEP 420 implicit namespace packages don't have __init__.py,
      " so we might find the actual package root in a parent directory beyond this one, via pythonPathsNorm
    endif
    let newroot = fnamemodify(root, ":h")
    if newroot == root
      break
    endif
    let root = newroot
  endwhile
  if found_path != ""
    let root = found_path
  else
    let root = found_dir
  endif

  let pkg = strpart(pkg, strlen(root))
  " Convert the relative path into a Python dotted module name
  let pkg = substitute(pkg, "\\", "/", "g") " Handle Windows paths
  let pkg = substitute(pkg, "[.]py$", "", "")
  let pkg = substitute(pkg, ".__init__$", "", "")
  let pkg = substitute(pkg, "^/", "", "")
  let pkg = substitute(pkg, "^site-packages/", "", "")
  let pkg = substitute(pkg, "/", ".", "g")
  " Get rid of the last module name if it starts with an underscore, e.g.
  " zope.schema._builtinfields -> zope.schema
  let pkg = substitute(pkg, "[.]_[a-zA-Z0-9_]*$", "", "")
  return pkg
endfunction

function! pythonimports#filename2package(filename)
  let module = pythonimports#filename2module(a:filename)
  let pkg = pythonimports#package_of(module)
  return pkg
endfunction

function! pythonimports#package_of(module)
  let pkg = substitute(a:module, '[.]\=[^.]\+$', '', '')
  return pkg
endfunction

function! pythonimports#is_stdlib_module(name)
  " Does a:name refer to a standard library module?

  if has_key(g:pythonBuiltinModules, a:name)
    return 1
  elseif g:pythonStdlibPath == ""
    return 0
  elseif filereadable(g:pythonStdlibPath . "/" . a:name . ".py")
    return 1
  elseif filereadable(g:pythonStdlibPath . "/" . a:name . "/__init__.py")
    return 1
  elseif filereadable(g:pythonStdlibPath . "/lib-dynload/" . a:name . ".so")
    return 1
  elseif filereadable(g:pythonStdlibPath . "/lib-dynload/" . a:name . g:pythonExtModuleSuffix)
    return 1
  else
    return 0
  endif
endfunction

function! pythonimports#maybe_reload_config()
  if has('python') || has('python3')
    " XXX: wasteful -- I should check if the file's timestamp has changed
    " instead of parsing it every time
    pyx import python_imports
    pyx python_imports.parse_python_imports_cfg()
  endif
endfunction

function! pythonimports#find_place_for_import(pkg, name)
  " Find the appropriate place to insert a "from pkg import name" line.
  " Moves the actual cursor in the actual Vim buffer.

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
endf
