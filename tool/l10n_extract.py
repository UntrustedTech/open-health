"""Lists the app's user-visible strings as translation templates.

Each string literal in lib/ (adjacent literals joined) becomes a template,
with interpolations replaced by {0}, {1}, ... in order. Strings that look
like keys, paths, formats or code are left out.

  python3 tool/l10n_extract.py > assets/l10n/source.json
"""
import json
import pathlib
import re
import sys

SKIP_FILES = {
    'lib/screens/legal_screen.dart',  # The Terms stay in English.
}
# Shown in the app, though in a skipped folder.
KEEP_FILES = set()
SKIP_DIRS = (
    'lib/demo/',
    'lib/l10n/',  # Language names are shown in their own language.
    'lib/import/',  # Column names in other apps' files.
    'lib/export/csv_export.dart',
)
# A log line's "Area: message" prefix.
LOG_LINE = re.compile(r'^[A-Z][A-Za-z]*( [A-Za-z]+)?: [a-z{]')


def literals(src):
    """Yields (template, line) for each run of adjacent string literals."""
    i, n = 0, len(src)
    out = []

    def skip_ws(j):
        while j < n:
            if src[j].isspace():
                j += 1
            elif src.startswith('//', j):
                j = src.find('\n', j)
                j = n if j < 0 else j
            elif src.startswith('/*', j):
                j = src.find('*/', j)
                j = n if j < 0 else j + 2
            else:
                break
        return j

    def read(j):
        """Reads one literal at j; returns (parts, end) or None."""
        raw = False
        if src[j] == 'r' and j + 1 < n and src[j + 1] in '\'"':
            raw = True
            j += 1
        if src[j] not in '\'"':
            return None
        q = src[j]
        triple = src.startswith(q * 3, j)
        delim = q * 3 if triple else q
        j += len(delim)
        text, holes = [], 0
        while j < n and not src.startswith(delim, j):
            ch = src[j]
            if ch == '\\' and not raw:
                nxt = src[j + 1]
                if nxt == 'u' and src[j + 2] == '{':
                    end = src.index('}', j)
                    text.append(chr(int(src[j + 3:end], 16)))
                    j = end + 1
                elif nxt == 'u':
                    text.append(chr(int(src[j + 2:j + 6], 16)))
                    j += 6
                else:
                    text.append({'n': '\n', 't': '\t'}.get(nxt, nxt))
                    j += 2
            elif ch == '$' and not raw:
                if src[j + 1] == '{':
                    depth, k = 1, j + 2
                    while depth:
                        if src[k] == '{':
                            depth += 1
                        elif src[k] == '}':
                            depth -= 1
                        k += 1
                    j = k
                else:
                    m = re.match(r'\$[A-Za-z_][A-Za-z0-9_]*', src[j:])
                    j += len(m.group(0))
                text.append('\x00')
                holes += 1
            elif ch == '\n' and not triple:
                return None
            else:
                text.append(ch)
                j += 1
        return ''.join(text), j + len(delim)

    while i < n:
        if src.startswith('//', i):
            i = src.find('\n', i)
            i = n if i < 0 else i
            continue
        if src.startswith('/*', i):
            i = src.find('*/', i) + 2
            continue
        ch = src[i]
        prev = src[i - 1] if i else ' '
        if ch in '\'"' or (ch == 'r' and i + 1 < n and src[i + 1] in '\'"'
                            and not (prev.isalnum() or prev == '_')):
            start = i
            pieces = []
            j = i
            while True:
                r = read(j)
                if r is None:
                    break
                pieces.append(r[0])
                j = skip_ws(r[1])
                if j >= n or not (src[j] in '\'"' or
                                  (src[j] == 'r' and src[j + 1] in '\'"')):
                    i = r[1]
                    break
            if not pieces:
                i += 1
                continue
            joined = ''.join(pieces)
            out.append((joined, src.count('\n', 0, start) + 1,
                        src[max(0, start - 60):start]))
            continue
        i += 1
    return out


def template(s):
    k = 0
    out = []
    for ch in s:
        if ch == '\x00':
            out.append('{%d}' % k)
            k += 1
        else:
            out.append(ch)
    return ''.join(out)


CODEY = re.compile(
    r'^[a-z][A-Za-z0-9_]*$'          # keys and ids
    r'|^[a-z][a-z0-9]*(-[a-z0-9]+)+$'  # kebab-case ids
    r'|^[a-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$'  # dotted ids
    r'|^[A-Z_][A-Z0-9_]+$'           # CONSTANTS
    r'|[/\\]|\.dart|package:|https?:'  # paths, urls, regexes
    r'|^[#@]|^\.|\.json$|\.png$|\.txt$'
    r'|^[EMydHhmsaz:.,/ \'-]+$'      # date formats
    r'|^[\d\s\W]*$'                  # no words
)
NON_UI_CONTEXT = re.compile(
    r'(ErrorLog\.\w+|debugPrint|log\(|log[A-Z]\w*\(|throw \w*\(|[!=]= |\bid: |prefs\.\w+|getString|setString|'
    r'getBool|setBool|getInt|setInt|json\[|map\[|RegExp\(|DateFormat\(|'
    r'NumberFormat\(|import |export |part |key: |Key\(|ValueKey\(|'
    r'MethodChannel\(|nativeName: |\.read\(|\.write\(|startsWith\(|endsWith\(|'
    r'contains\(|split\(|replaceAll\(|Uri\.|assets?/)\s*$'
)


def wanted(t, before):
    if not re.search(r'[A-Za-z]', t):
        return False
    bare = re.sub(r'\{\d+\}', '', t)
    if not re.search(r'[A-Za-z]{2}', bare):
        return False
    if CODEY.search(t):
        return False
    if NON_UI_CONTEXT.search(before):
        return False
    return True


def main():
    root = pathlib.Path('lib')
    found = {}
    for p in sorted(root.rglob('*.dart')):
        rel = p.as_posix()
        if rel not in KEEP_FILES and (
                rel in SKIP_FILES or rel.startswith(SKIP_DIRS)):
            continue
        if rel.endswith('.g.dart'):
            continue
        for s, line, before in literals(p.read_text()):
            t = template(s)
            if wanted(t, before):
                found.setdefault(t, f'{rel}:{line}')
    json.dump(found, sys.stdout, ensure_ascii=False, indent=1, sort_keys=True)


main()
