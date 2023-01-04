"""
" HACK to make it possible to reload this by sourcing it in vim
py3 import importlib; importlib.reload(python_imports)
finish
"""
import re
import os
from typing import NamedTuple, Iterable

import vim


DEFAULT_CONFIG_FILE = os.path.expanduser('~/.vim/python-imports.cfg')

DOTTEDNAME = '[a-zA-Z_.][a-zA-Z_0-9.]*'
NAME = r'[a-zA-Z_][a-zA-Z_0-9]*(\s+as\s+[a-zA-Z_][a-zA-Z_0-9]*)?'
NAMES = NAME + r'(\s*,\s*' + NAME + ')*'

IMPORT_RX = re.compile(r'^import\s*(' + NAMES + ')$')
FROM_IMPORT_RX = re.compile(
    r'^from\s*(' + DOTTEDNAME + r')\s*import\s*(' + NAMES + ')$')


class ImportedName(NamedTuple):
    modname: str
    name: str
    alias: str

    @property
    def has_alias(self) -> bool:
        return self.alias and self.alias != self.name

    def __str__(self) -> str:
        bits = [self.name]
        if self.has_alias:
            bits.append(f"as {self.alias}")
        if self.modname:
            bits.append(f"from {self.modname}")
        return " ".join(bits)


def parse_names(names: str, modname: str = '') -> Iterable[ImportedName]:
    for name in names.split(','):
        bits = name.split()
        # it's either [name] or [name, 'as', alias], and the following works for both
        yield ImportedName(modname, bits[0], bits[-1])


def parse_line(line: str) -> Iterable[ImportedName]:
    m = IMPORT_RX.match(line)
    if m:
        return parse_names(m.group(1))
    m = FROM_IMPORT_RX.match(line)
    if m:
        modname = m.group(1)
        return parse_names(m.group(2), modname)


def parse_python_imports_cfg(filename: str = DEFAULT_CONFIG_FILE, verbose: bool = False) -> None:
    try:
        with open(filename) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                for name in parse_line(line):
                    if verbose:
                        print(name)
                    vim.command("let g:pythonImports['%s'] = '%s'" % (name.name, name.modname))
                    if name.has_alias:
                        vim.command("let g:pythonImportAliases['%s'] = '%s'"
                                    % (name.alias, name.name))
                    continue
    except IOError as e:
        if verbose:
            print("Failed to load %s: %s" % (filename, e))
