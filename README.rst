Overview
--------
Vim script to help adding import statements in Python modules.

You need to have a tags file built (``:!ctags -R .``, be sure to use
`exuberant-ctags <http://ctags.sourceforge.net/>`_ or `Universal
Ctags <https://ctags.io/>`_). You can use `Gutentags
<https://github.com/ludovicchabant/vim-gutentags>`__ plugin for
automatic tags management.

Type ``:ImportName [<name>]`` to add an import statement at the top of the file.

Type ``:ImportNameHere [<name>]`` to add an import statement above the current
line.

I use the following mappings to import the name under cursor with a single
keystroke::

  map <F5>    :ImportName<CR>
  map <C-F5>  :ImportNameHere<CR>

Needs Vim 7.0, preferably built with Python support.

Tested on Linux only.


Installation
------------

I recommend `Vundle <https://github.com/gmarik/vundle>`_, `pathogen
<https://github.com/tpope/vim-pathogen>`_ or `Vim Addon Manager
<https://github.com/MarcWeber/vim-addon-manager>`_.  E.g. with Vundle do ::

  :BundleInstall "mgedmin/python-imports.vim"

Manual installation: copy ``plugin/python-imports.vim`` to ``~/.vim/plugin/``.


Configuration
-------------

In addition to the ``tags`` file (and builtin logic for recognizing standard
library modules), you can define your favourite imports in a file called
``~/.vim/python-imports.cfg``.  That file should contain Python import
statements like ::

    import module1, module2
    from package.module import name1, name2

Continuation lines are not supported.  Parenthesized name lists are partially
supported, if you use one name per line, i.e. ::

    from package.module import (
        name1,
        name2,
    )


Special Paths
-------------

Aside from the project root path, some projects auto-import its sub-folders also
in the Python path (e.g. ``apps`` or ``conf`` folders) which is usually done to
avoid repetitive or lengthy import names. For instance,
a project that is located in ``~/my_project`` could have an ``apps`` folder
which has this logical structure ::

    from apps.alpha import bravo
    from apps.charlie import delta

But, the project team might decide to auto-import the ``apps`` folder
in the environment setup, so that the code will have this import format
for convenience ::

    from alpha import bravo
    from charlie import delta

To resolve these special imports correctly, the ``pythonPaths`` global variable
could be used ::

    let g:pythonPaths = [
        \ expand('~/my_project/apps'),
        \ expand('~/my_project/conf'),
        \ ]

Note that the ``expand()`` is used here so that the Home directory (``~``)
will be interpreted correctly.


Copyright
---------

``python-imports.vim`` was written by Marius Gedminas <marius@gedmin.as>.
Licence: MIT.
