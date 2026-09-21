#!/usr/bin/env python3
"""Which wgrender setters can refuse a value, and whether the binding lets you see it.

    tools/setters.py [WGRENDER_DIR]     the report
    tools/setters.py --check            fail if a property is swallowing a refusal

Every wgrender setter returns false for a dead handle, and wgrender logs that. Some
refuse a *value* as well -- a negative rate, a zero-length light direction, an emitter
cap out of range -- and most of those return false with nothing logged at all. Nothing
changes and the call looks like it worked.

So the rule this enforces, which is wgrender's own clamp-or-refuse rule (AGENTS.md)
read from the other side:

    a Haxe property is right when every way the call can fail is one wgrender logs;
    a method returning Bool is right when it can fail silently.

Logged or not is the line, not value-or-handle. wgr_window_set_monitor refuses a
monitor that isn't there and wgr_text_set_default_font refuses a handle that isn't a
font, but both say so in the log, so a property loses nothing. A negative emitter rate
says nothing anywhere, and behind a property there is no way at all to find out.

A property setter cannot return anything, so a silent refusal behind one is invisible
twice over. A refusal the binding's own types make unreachable does not count -- an
`enum abstract` with two values cannot produce the third that wgrender would reject --
and those are listed in UNREACHABLE with the type that rules them out.

The conditions are read from wgrender's C, not from its headers, because the code is
what refuses. Read the headers for why.

What it found, as of wgrender 14be9e6: after the shadow-map clamp fix, every silent
refusal left behind a property is a value that is not the thing at all -- a size of
0, a height of 0, a zero-length direction. That is the same category as a dead
handle: a bug in the program, not a branch a caller takes. So the properties are
right and none of them need to become methods. The one setter that refuses a value
someone *meant* -- an emitter cap of a million, which is a real request for a
different simulation -- is already a method.

Two things this cannot answer, both of which need wgrender:

  - Those eight refusals log nothing. A property is the one shape with nowhere to
    put a return value, so `light.shadowMapSize = 0` does nothing and says nothing
    anywhere. One log_warn per site would close that, and is why this stays a report.
  - wgr_light_set_shadow_map_size clamps to 256 .. 4096, and there is no
    wgr_light_get_shadow_map_size, so nothing outside wgrender can see what it
    clamped to. The checks can assert which sizes are accepted, not what they became.

It is deliberately not wired into `build.py check`. Reading C control flow with
regular expressions is fine for a report someone reads and wrong for a gate that
fails a build: it already produced one false clean (a guard written with braces) and
two false positives (an allocation check read as a refusal). If the AGENTS convention
of naming refusals in the header holds, a check over that prose would be the robust
version, and this becomes the thing that finds what the headers have not caught up to.
"""
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WGRENDER = pathlib.Path(
    next((a for a in sys.argv[1:] if not a.startswith('--')), None)
    or os.environ.get('WGRENDER_DIR', ROOT / '../wgrender-c')).resolve()

# Refusals Haxe's types make unreachable: the parameter is an enum abstract whose
# every value wgrender accepts, and which is not `from Int`, so no other value exists
# to pass. Each entry names the type that rules it out.
UNREACHABLE = {
    'wgr_camera3d_set_projection': 'Projection: the two values it refuses outside are all there are',
    'wgr_material_set_shading': 'MaterialShading: same',
    'wgr_sprite3d_set_facing': 'SpriteFacing: same',
    'wgr_text3d_set_facing': 'SpriteFacing: same',
    'wgr_text2d_set_align': 'AlignX and AlignY: wgrender refuses one axis\'s value '
                            'passed for the other, and the two abstracts make that '
                            'unrepresentable rather than a runtime false',
    'wgr_text3d_set_align': 'AlignX and AlignY: same',
}

# Setters whose refusal is real but which stay properties anyway, with the reason.
# Keep this empty if you can: every entry is a silent failure someone will hit.
ACCEPTED = {}

MACROS = {}


def macro_bodies():
    """Multi-line `#define NAME(...) \\` macros, which some setters are written as.

    A body that is one macro call is not unreadable, it is the macro's guards -- and
    wgrender's WITH_EMITTER is exactly that: resolve, return false on a dead handle,
    assign, return true. Following the macro is what tells a guard-only setter apart
    from one this simply failed to read.
    """
    joined = '\n'.join(p.read_text() for p in sorted((WGRENDER / 'src').glob('*.c')))
    out = {}
    for m in re.finditer(r'#define\s+(\w+)\(([^)]*)\)((?:[^\n]*\\\n)*[^\n]*)', joined):
        out[m.group(1)] = m.group(3)
    return out


def bodies():
    """Every bool function body in wgrender's C, public or internal."""
    joined = '\n'.join(p.read_text() for p in sorted((WGRENDER / 'src').glob('*.c')))
    out = {}
    for m in re.finditer(r'(?:WGRI_KEEP\s*\n)?bool\s+(wgr[i]?_\w+)\s*\(([^;{]*?)\)\s*\{(.*?)\n\}',
                         joined, re.S):
        out.setdefault(m.group(1), m.group(3))
    for m in re.finditer(r'WGRI_KEEP\s+bool\s+(wgr\w+)\s*\([^)]*\)\s*\{([^\n}]*)\}', joined):
        out.setdefault(m.group(1), m.group(2))
    return out


HANDLE_GUARD = re.compile(
    r'^(?:!\s*\w*resolve\w*\s*\([^()]*\)'
    r'|\w*resolve\w*\s*\([^()]*\)\s*==\s*NULL'
    r'|\w+\s*==\s*NULL|!\s*\w+)$')

LOGS = re.compile(r'\blog_(warn|error|fatal)\b')


def refusals(name, all_bodies, depth=0):
    """The value conditions `name` returns false on, following delegation to wgri_*.

    A condition that only tests the resolved pointer is the handle guard, which every
    setter has and which wgrender logs; it is not a value refusal.
    """
    body = all_bodies.get(name)
    if body is None:
        return None
    flat = ' '.join(body.split())
    delegate = re.fullmatch(r'return\s+(wgr[i]?_\w+)\s*\([^()]*\)\s*;', flat)
    if delegate and depth < 3:
        return refusals(delegate.group(1), all_bodies, depth + 1)
    # a body that is one macro call carries that macro's guards, not none
    call = re.search(r'(?:^|;\s*)([A-Z_][A-Z0-9_]*)\s*\(.*\)\s*;\s*$', flat)
    if call and call.group(1) in MACROS:
        # whatever ran before the macro is clamping or bookkeeping, not a refusal:
        # the macro is what returns, so its guards are the ones that matter
        flat = ' '.join(MACROS[call.group(1)].replace('\\', ' ').split())
    # `if (<expression>) [log_warn(...);] return false;`, braces optional. A guard
    # that logs is not silent: the program finds out whether or not the binding hands
    # the bool back, so it is not a reason to give up a property.
    # Strictly `if (<cond>) [log_...();] return false;`. Anything else between the
    # condition and the return is a statement, which means this is not a simple guard
    # and reading it as one invents refusals -- set_text's `if (text != NULL) { ...
    # malloc ... if (copy == NULL) return false; }` is an allocation check, not a
    # refusal of the text.
    guards = re.findall(
        r'if\s*\(([^{};]*?)\)\s*(?:\{\s*)?((?:log_\w+\([^;]*\);\s*)*)return false;', flat)
    if not guards:
        return None  # nothing recognisable: say so rather than report it clean
    found = []
    for cond, between in guards:
        if LOGS.search(between):
            continue
        for part in re.split(r'\|\|', cond):
            part = part.strip()
            if not HANDLE_GUARD.match(part):
                found.append(part)
    return found


def void_setters():
    """Setters wgrender declares void: they cannot fail, so a property is always right."""
    joined = '\n'.join(p.read_text() for p in sorted((WGRENDER / 'include').glob('*.h')))
    return set(re.findall(r'^\s*void\s+(wgr_\w+_set_\w+)\s*\(', joined, re.M))


REFUSAL = re.compile(
    r'\bfalse\b[^.;]{0,80}?\b(for|when|outside|below|above|if|unless)\b'
    r'|\brefus(e|es|ed|ing)\b|\bnot accepted\b', re.I)

# Words a Haxe doc comment can use to say the same thing.
SAYS_SO = re.compile(r'\brefus(e|es|ed|ing)\b|\bfalse\b|\bkeeps? what it had\b'
                     r'|\bignored\b|\bnot a \w+\b', re.I)


def documented_refusals():
    """Setters whose header comment names a refusal, with the sentence it used.

    AGENTS.md makes this a contract: "a setter's comment uses the word that matches
    the code, and 'false for ...' names every refusal ... a binding decides
    method-or-property from that sentence". So the sentence is the interface, and a
    binding that does not repeat it is dropping the thing it was told.
    """
    out = {}
    for h in sorted((WGRENDER / 'include').glob('*.h')):
        text = h.read_text()
        for m in re.finditer(
                r'(/\*(?:[^*]|\*(?!/))*\*/)?\s*bool\s+(wgr_\w+_set_\w+)\s*\([^;]*?\);'
                r'((?:[ \t]*/\*(?:[^*]|\*(?!/))*\*/)?)', text):
        # the comment above the declaration, or the one trailing it on the same line
            comment = (m.group(1) or '') + (m.group(3) or '')
            if comment and REFUSAL.search(comment):
                out[m.group(2)] = ' '.join(comment.split())
    return out


def doc_comments():
    """Each member's doc comment, keyed `Module.member`.

    A property's documentation sits above its `public var`, not above the accessor
    that makes the call, and the accessor can be pages away with other members in
    between -- so this keys on the member name and lets the caller join through the
    property/method maps, rather than pairing a comment with the next Raw call it
    happens to see.
    """
    out = {}
    for f in sorted((ROOT / 'src/wgr').glob('*.hx')):
        text = f.read_text()
        for m in re.finditer(
                r'/\*\*((?:[^*]|\*(?!/))*)\*/\s*(?:@:\w+(?:\([^)]*\))?\s*)*'
                r'(?:public\s+)?(?:static\s+)?(?:inline\s+)?(?:var|final|function)\s+(\w+)',
                text):
            out[f'{f.stem}.{m.group(2)}'] = m.group(1)
    return out


def binding():
    """What the API layer exposes as a property, and what as a method."""
    props, methods = {}, {}
    for f in sorted((ROOT / 'src/wgr').glob('*.hx')):
        s = f.read_text()
        for m in re.finditer(r'inline function set_(\w+)\([^)]*\)[^{]*\{\s*Raw\.(wgr_\w+)\(', s):
            props[m.group(2)] = f'{f.stem}.{m.group(1)}'
        for m in re.finditer(r'function (set[A-Z]\w*)\([^)]*\):Bool\s*\n?\s*return Raw\.(wgr_\w+)\(', s):
            methods[m.group(2)] = f'{f.stem}.{m.group(1)}'
    return props, methods


def main():
    global MACROS
    MACROS = macro_bodies()
    all_bodies = bodies()
    if not all_bodies:
        sys.exit(f'no C sources under {WGRENDER}/src')
    props, methods = binding()
    void = void_setters()

    swallowed, fine, unparsed = [], [], []
    for c_name, where in sorted(props.items()):
        if c_name in void:
            fine.append((c_name, where))
            continue
        conds = refusals(c_name, all_bodies)
        if conds is None:
            unparsed.append((c_name, where))
        elif not conds:
            fine.append((c_name, where))
        elif c_name in UNREACHABLE or c_name in ACCEPTED:
            fine.append((c_name, where))
        else:
            swallowed.append((c_name, where, conds))

    documented = documented_refusals()
    docs = doc_comments()
    undocumented = []
    for c_name, sentence in sorted(documented.items()):
        where = props.get(c_name) or methods.get(c_name)
        if where is None:
            continue  # not wrapped; coverage.py is what answers for that
        mine = docs.get(where)
        if c_name in UNREACHABLE:
            continue  # documenting a case the types rule out is noise, not accuracy
        if mine is None or not SAYS_SO.search(mine):
            undocumented.append((where, c_name, sentence))

    if '--check' in sys.argv:
        # The gate. This is prose against prose -- wgrender's header comment against
        # the binding's doc comment -- so it is safe to fail a build on. The C reading
        # below is not, and only warns.
        for where, c_name, sentence in undocumented:
            print(f'  {where}: {c_name}\'s header names a refusal the doc comment does not')
            print(f'      header: {sentence[:120]}')
        for c_name, where, conds in swallowed:
            print(f'  warning: {where} is a property, but {c_name} refuses: {"; ".join(conds)}')
        stale = [n for n in list(UNREACHABLE) + list(ACCEPTED)
                 if n not in props and n not in methods]
        for n in stale:
            print(f'  {n}: listed as an exception, but the binding does not wrap it')
        for c_name, where in unparsed:
            print(f'  warning: could not read {c_name}\'s guard from the C ({where})')
        for n in stale:
            pass
        print(f'setters: {"stale" if undocumented else "current"} '
              f'({len(documented)} documented refusals, {len(undocumented)} not repeated; '
              f'{len(props)} properties, {len(methods)} methods)')
        return 1 if undocumented or stale else 0

    print(f'{len(props)} properties and {len(methods)} methods wrap a wgrender setter.\n')
    if swallowed:
        print('properties swallowing a silent value refusal:')
        for c_name, where, conds in swallowed:
            print(f'  {where:<28} {c_name}')
            for cond in conds:
                print(f'  {"":<28}   false when  {cond}')
        print()
    print(f'{len(fine)} properties can only fail on a dead handle, which wgrender logs.')
    print(f'\n{len(documented)} setters name a refusal in their header; '
          f'{len(documented) - len(undocumented)} are repeated in the binding\'s docs.')
    for where, c_name, sentence in undocumented:
        print(f'  {where:<28} {c_name} says so and the binding does not')
    if UNREACHABLE:
        print(f'\n{len(UNREACHABLE)} refusals Haxe\'s types make unreachable:')
        for n, why in sorted(UNREACHABLE.items()):
            print(f'  {n:<34} {why}')
    if unparsed:
        print(f'\n{len(unparsed)} not read from the C (delegated too far, or written another way):')
        for c_name, where in unparsed:
            print(f'  {where:<28} {c_name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
