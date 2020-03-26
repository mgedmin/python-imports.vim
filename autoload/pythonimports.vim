function! pythonimports#filename2module(filename)
  " Figure out the dotted module name of the given filename

  " Look at the file name of the module that contains this tag.  Find the
  " nearest parent directory that does not have __init__.py.  Assume it is
  " directly included in PYTHONPATH.
  let pkg = fnamemodify(a:filename, ":p")
  let root = fnamemodify(pkg, ":h")

  let found = 0
  if exists("g:python_paths")
    for path in g:python_paths
      if root =~ path
        let root = path
        let found = 1
        break
      endif
    endfor
  endif

  if !found
    while strlen(root)
      if !filereadable(root . "/__init__.py")
        break
      endif
      let root = fnamemodify(root, ":h")
    endwhile
  endif
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
