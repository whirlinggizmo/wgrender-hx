#!/usr/bin/env python3
"""Build and check every example here.

    examples/build.py all        build each one (web and native)
    examples/build.py web        the web build only
    examples/build.py drive      run each web build in a headless browser
    examples/build.py compare    sizes against wgrender's own C build of each
    examples/build.py bench      frame cost, Haxe against C, for each
    examples/build.py clean

Each example owns its build.py; this runs them, so there is one command to say
"everything still works" after a change to the binding. The library's own checks are
test/check.py at the root -- they are not an example's business and run on their own.

Python rather than a Makefile: nothing else in wgrender-hx uses make, and wgrender's
own tools (serve.py, webdeploy.py) are Python and get shelled out to from here, so
this adds no dependency that building already needed.

    WGRENDER_DIR   where wgrender-c is
    ONLY=name,name limit it to those examples
"""
import os
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
LIB = HERE.parent
WGRENDER = pathlib.Path(os.environ.get('WGRENDER_DIR', LIB / '../wgrender-c')).resolve()
C_BUILD = WGRENDER / 'examples/build/webgl2-nothreads'

# simple-hxcpp is the other architecture -- Haxe through hxcpp into one wasm, rather
# than a JS guest on a wgrender host -- so it has its own commands and is not driven
# or benched with the guests.
GUESTS = ['hello3d', 'particles', 'simple']
OTHERS = ['simple-hxcpp']


def wanted(names):
    only = os.environ.get('ONLY')
    return [n for n in names if not only or n in only.split(',')]


def run(cmd, cwd, **kw):
    print(f'\n=== {cwd.name}: {" ".join(str(c) for c in cmd)}', flush=True)
    subprocess.run([str(c) for c in cmd], check=True, cwd=cwd, **kw)


def each(command, names=None):
    for name in wanted(names or GUESTS + OTHERS):
        run(['./build.py', command], HERE / name)


def drive():
    for name in wanted(GUESTS):
        run(['node', 'tools/drive.mjs'], HERE / name)
    if 'simple-hxcpp' in wanted(OTHERS):
        run(['node', 'check_web.mjs'], HERE / 'simple-hxcpp')


def bench():
    if not C_BUILD.exists():
        sys.exit(f'no C builds at {C_BUILD}\n'
                 f'  make -C {WGRENDER} wasm-all WEB_THREADS=0')
    for name in wanted(GUESTS):
        for args in ([f'--site={C_BUILD}', f'--url=/?ex={name}', '--probe=examples.json',
                      f'--label={name}-c'],
                     [f'--site={HERE / name / "out/web"}', f'--label={name}-haxe']):
            subprocess.run(['node', str(LIB / 'tools/bench.mjs'), *args], check=True)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'all':
        each('all')
    elif command in ('web', 'guest', 'host', 'desktop', 'sizes', 'clean'):
        # the guests take host/guest/desktop; simple-hxcpp takes web/desktop
        if command in ('guest', 'host'):
            each(command, GUESTS)
        elif command == 'web':
            each('all', GUESTS)
            each('web', OTHERS)
        else:
            each(command)
    elif command == 'drive':
        drive()
    elif command == 'compare':
        subprocess.run([str(LIB / 'tools/compare.py')], check=True)
    elif command == 'bench':
        bench()
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    sys.exit(main() or 0)
