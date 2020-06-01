import re
import os

import vim


DEFAULT_CONFIG_FILE = os.path.expanduser('~/.vim/python-imports.cfg')

DOTTEDNAME = '[a-zA-Z_.][a-zA-Z_0-9.]*'
NAME = '[a-zA-Z_][a-zA-Z_0-9]*'
NAMES = NAME + r'(\s*,\s*' + NAME + ')*'

IMPORT_RX = re.compile(r'^import\s*(' + NAMES + ')$')
FROM_IMPORT_RX = re.compile(
    r'^from\s*(' + DOTTEDNAME + r')\s*import\s*(' + NAMES + ')$')


def parse_python_imports_cfg(filename=DEFAULT_CONFIG_FILE, verbose=False):
    try:
        with open(filename) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                m = IMPORT_RX.match(line)
                if m:
                    names = m.group(1).split(',')
                    for name in names:
                        if verbose:
                            print(name.strip())
                        vim.command("let g:pythonImports['%s'] = ''" % name.strip())
                    continue
                m = FROM_IMPORT_RX.match(line)
                if m:
                    modname = m.group(1)
                    names = m.group(2).split(',')
                    for name in names:
                        if verbose:
                            print('%s from %s' % (name.strip(), modname))
                        vim.command("let g:pythonImports['%s'] = '%s'" % (name.strip(), modname))
                    continue
    except IOError as e:
        if verbose:
            print("Failed to load %s: %s" % (filename, e))
