#!/usr/bin/env python3
"""Emit the mechanical half of src/wgr/Raw.js.hx from the hxcpp port's extern list.

    tools/gen_raw_js.py            print the wrappers this file doesn't have yet

The two ports declare the same C surface; only the way they reach it differs. This
reads ../simple/src/wgr/Raw.hx and renders each extern as a host-module call, so the
JS side can't silently drift from the hxcpp side. Calls returning a struct, and the
lifecycle/asset calls the guest ABI replaces, are hand-written — they are listed as
skipped rather than guessed at.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CPP_RAW = ROOT / '../simple/src/wgr/Raw.hx'
JS_RAW = ROOT / 'src/wgr/Raw.js.hx'

# Replaced by the guest ABI (host/wgr_guest.h), so the JS layer never needs them.
GUEST_ABI_REPLACES = {'wgr_init_values', 'wgr_set_init', 'wgr_set_frame', 'wgr_run',
                      'wgr_asset_ensure_async', 'wgr_asset_add_task'}
STRUCT_RETURNS = {'CVec2', 'CVec3', 'CPickResult', 'CMouseState', 'CKeyboardState'}
HANDLE_TYPES = {'WgrHandle', 'WgrColor', 'Int'}


def haxe_type(c_type):
    if c_type == 'ConstCharStar':
        return 'String'
    if c_type in ('Single',):
        return 'Float'
    if c_type in HANDLE_TYPES or c_type.startswith('C'):
        return 'Int'
    return c_type  # Bool, Float, Void


def main():
    have = set(re.findall(r'function (wgr_[a-z0-9_]+)\(', JS_RAW.read_text()))
    source = CPP_RAW.read_text()
    decls = re.findall(r'@:native\("(wgr_[a-z0-9_]+)"\)\s*\n\tstatic function \1\(([^;]*?)\):([\w<>.]+);',
                       source, re.S)
    emitted, skipped = [], []
    for name, params, ret in decls:
        ret = ret.strip()
        if name in have or name in GUEST_ABI_REPLACES:
            continue
        if ret in STRUCT_RETURNS:
            skipped.append(f'{name} (returns {ret}: needs a scratch read)')
            continue
        fields = []
        for part in re.split(r',\s*', ' '.join(params.split())):
            if not part.strip():
                continue
            arg, _, c_type = part.partition(':')
            fields.append((arg.strip(), c_type.strip()))
        sig = ', '.join(f'{a}:{haxe_type(t)}' for a, t in fields)
        args = ', '.join(f'cstr({a})' if t == 'ConstCharStar' else a for a, t in fields)
        call = f'host._{name}({args})'
        if ret == 'Void':
            body = f'\t\t{call};'
        elif ret == 'Bool':
            body = f'\t\treturn {call} != 0;'
        else:
            body = f'\t\treturn {call};'
        emitted.append(f'\tpublic static inline function {name}({sig}):{haxe_type(ret)}\n{body}\n')

    print('\n'.join(emitted))
    if skipped:
        print('// hand-written, not generated:', file=sys.stderr)
        for s in skipped:
            print('//   ' + s, file=sys.stderr)
    print(f'// {len(emitted)} generated', file=sys.stderr)


if __name__ == '__main__':
    main()
