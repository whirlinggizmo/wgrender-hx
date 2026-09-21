#!/usr/bin/env python3
"""What of wgrender this binding reaches, and what it would take to reach more.

    tools/coverage.py [WGRENDER_DIR]     the report
    tools/coverage.py --check            fail if OMISSIONS has rotted

Two layers answer separately. `wgr.impl.Raw` is generated and covers the C surface;
the API layer above it — the handle abstracts and their methods — is hand-written, and
is where the gap lives. Both are reported, because "callable" and "wrapped" are
different questions and conflating them flatters the binding.

Example reachability is the useful number: a subsystem matters in proportion to how
many of wgrender's own examples it blocks.

Borrowed from librl's tools/audit_binding_parity.py, which audits six bindings across
four languages. This one has one binding to audit, and its methods call Raw directly
rather than through a name mapping, so it is much smaller — but the idea of recording
*intentional* omissions is taken whole. Without it a decision and a to-do look alike.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WGRENDER = pathlib.Path(
    next((a for a in sys.argv[1:] if not a.startswith('--')), None)
    or ROOT / '../wgrender-c').resolve()

# Reachable on hxcpp but deliberately not on js, and why: every one takes a C function
# pointer or a void *, which the guest ABI replaces there, or returns something too big
# to copy per frame. `--check` fails if one turns up in Raw.js.hx after all, so the
# list cannot quietly go stale.
OMISSIONS = {
    'wgr_set_init': 'js: takes a C callback; the guest ABI installs ops instead',
    'wgr_set_frame': 'js: takes a C callback; the guest ABI installs ops instead',
    'wgr_set_tick': 'js: takes a C callback; the guest ABI installs ops instead',
    'wgr_set_cleanup': 'js: takes a C callback; the guest ABI installs ops instead',
    'wgr_asset_add_task': 'js: takes a C callback; wgr_guest_asset_load takes an id',
    'wgr_event_on': 'js: takes a C callback',
    'wgr_event_off': 'js: takes a C callback',
    'wgr_event_once': 'js: takes a C callback',
    'wgr_event_emit': 'js: takes a void * payload',
    'wgr_asset_set_fetcher': 'js: takes a C callback',
    'wgr_asset_ping_host': 'js: takes a C callback',
    'wgr_input_get_keyboard_state': 'js: 512 ints; wants a heap reader, not a copy per frame',
}


def c_functions():
    out = {}
    for h in sorted((WGRENDER / 'include').glob('*.h')):
        text = re.sub(r'/\*.*?\*/', ' ', h.read_text(), flags=re.S)
        for m in re.finditer(r'^\s*(?:const\s+)?(?:unsigned\s+)?\w+\s*\*?\s*(wgr_[a-z0-9_]+)\s*\(', text, re.M):
            out.setdefault(h.stem, set()).add(m.group(1))
    return out


def reached():
    """What the hand-written API layer calls, and what each generated Raw declares."""
    api = set()
    for f in list((ROOT / 'src/wgr').glob('*.hx')) + list((ROOT / 'src/wgr/impl').glob('GuestAbi*.hx')):
        api |= set(re.findall(r'(?:Raw|GuestRaw)\.(wgr_[a-z0-9_]+)', f.read_text()))
    raw = {}
    for target, name in (('hxcpp', 'Raw.cpp.hx'), ('js', 'Raw.js.hx')):
        path = ROOT / 'src/wgr/impl' / name
        raw[target] = set(re.findall(r'function (wgr_[a-z0-9_]+)\(', path.read_text())) if path.exists() else set()
    return api, raw


def macros():
    joined = '\n'.join(p.read_text() for p in (WGRENDER / 'include').glob('*.h'))
    return set(re.findall(r'#\s*define\s+(wgr_\w+)\s*\(', joined))


def main():
    by_header = c_functions()
    every = {fn for fns in by_header.values() for fn in fns}
    api, raw = reached()

    if '--check' in sys.argv:
        rotted = [f'{fn}: listed as omitted from js, but Raw.js.hx has it' for fn in OMISSIONS
                  if fn in raw['js']]
        unknown = [f'{fn}: listed as omitted, but no such function' for fn in OMISSIONS if fn not in every]
        for line in rotted + unknown:
            print(f'  {line}')
        print(f'OMISSIONS: {"stale" if rotted or unknown else "current"} ({len(OMISSIONS)} entries)')
        return 1 if rotted or unknown else 0

    print(f'wgrender: {len(every)} public functions across {len(by_header)} headers\n')
    print(f'  {"C surface (generated)":<28} hxcpp {len(raw["hxcpp"]):>3}/{len(every)}   '
          f'js {len(raw["js"]):>3}/{len(every)}')
    print(f'  {"API layer (hand-written)":<28} {len(api):>9}/{len(every)}\n')

    print(f'{"header":<22} {"calls":>5} {"wrapped":>8}')
    for header, fns in sorted(by_header.items(), key=lambda kv: (len(kv[1] & api) / len(kv[1]), -len(kv[1]))):
        done = len(fns & api)
        print(f'{header:<22} {len(fns):>5} {done:>8}  {"#" * round(done / len(fns) * 10):<10} '
              f'{done / len(fns) * 100:>3.0f}%')

    skip = macros() | OMISSIONS.keys()
    rows = []
    for c in sorted((WGRENDER / 'examples').glob('*.c')):
        need = set(re.findall(r'\b(wgr_[a-z0-9_]+)\s*\(', c.read_text())) - skip - api
        rows.append((len(need), c.stem, sorted(need)))
    rows.sort()
    print(f'\nwgrender has {len(rows)} examples; what each still needs from the API layer:')
    for band, lo, hi in (('nothing', 0, 0), ('1-5', 1, 5), ('6-10', 6, 10), ('11+', 11, 10 ** 6)):
        names = [n for k, n, _ in rows if lo <= k <= hi]
        print(f'  {band:<8} {len(names):>2}  {", ".join(names)}')

    blockers = {}
    for _, _, need in rows:
        for fn in need:
            blockers.setdefault(re.match(r'wgr_([a-z0-9]+)', fn).group(1), set()).add(fn)
    ranked = sorted(blockers.items(), key=lambda kv: -sum(1 for _, _, n in rows if kv[0] in {
        re.match(r'wgr_([a-z0-9]+)', f).group(1) for f in n}))
    print('\nwrapping these unblocks the most examples:')
    for sub, fns in ranked[:6]:
        blocks = sum(1 for _, _, need in rows if any(f.startswith(f'wgr_{sub}') for f in need))
        print(f'  {sub:<12} blocks {blocks:>2} examples, {len(fns):>2} calls unwrapped')

    missing_js = sorted(raw['hxcpp'] - raw['js'])
    unexplained = [fn for fn in missing_js if fn not in OMISSIONS]
    print(f'\non hxcpp but not js ({len(missing_js)}), all accounted for'
          f'{"" if not unexplained else f" except {len(unexplained)}: " + ", ".join(unexplained)}:')
    for fn, why in sorted(OMISSIONS.items()):
        print(f'  {fn:<32} {why}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
