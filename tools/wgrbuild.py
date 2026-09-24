#!/usr/bin/env python3
"""wgrender's libraries, built the way wgrender builds them, and the flags a program
compiles and links against them with, read from wgrender's build.json.

    from wgrbuild import web, desktop
    lib, cflags, ldflags = web(WGRENDER)                # tools/buildweb.py, no threads
    lib, ldflags = desktop(WGRENDER, headless=True)     # a CMake preset of wgrender's

The web library comes from wgrender's tools/buildweb.py (emcc and Python, nothing
else), single-threaded because hxcpp's emscripten target has none, with BACKEND and
WEB_DEBUG from the environment. The desktop one is wgrender's `<os>-release` or
`<os>-headless` CMake preset (`windows-mingw[-headless]` on Windows: this is gcc or
clang), built as far as the library. Either is in wgrender's out/<platform>/<variant>/
(its work in build/), the wg* family layout (whirlinggizmo/.github CONVENTIONS.md, "Build directories"). For the programs here that
link a library rather than compiling wgrender in (simple-hxcpp, the checks, the hxcpp web
builds); an installed binding compiles its sources instead (project/wgrender.xml).
"""
import json
import os
import platform
import subprocess
import sys
from pathlib import Path


def run(cmd, **kw):
    print('+', ' '.join(str(c) for c in cmd), flush=True)
    subprocess.run([str(c) for c in cmd], check=True, **kw)


def manifest(wgrender):
    path = Path(wgrender) / 'build.json'
    if not path.exists():
        sys.exit(f'no {path}: this wgrender predates it; update the submodule')
    return json.loads(path.read_text())


def web(wgrender):
    """(library, compile flags, link flags) of the single-threaded web library."""
    wgrender = Path(wgrender)
    backend = os.environ.get('BACKEND') or 'webgl2'
    debug = os.environ.get('WEB_DEBUG') or '0'
    run([sys.executable, wgrender / 'tools/buildweb.py', f'BACKEND={backend}', 'WEB_THREADS=0',
         f'WEB_DEBUG={debug}'], cwd=wgrender)
    name = f'{backend}-nothreads' + ('-debug' if debug == '1' else '')
    target = manifest(wgrender)['web'][name]
    return (wgrender / 'out' / 'web' / name / 'libwgrender.a',
            [f'-I{wgrender / "include"}', *target['program_cflags']], list(target['ldflags']))


def desktop(wgrender, headless=False):
    """(library, link flags) of the desktop or headless library, for gcc or clang."""
    wgrender = Path(wgrender)
    system = {'Linux': 'linux', 'Darwin': 'macos', 'Windows': 'windows'}[platform.system()]
    if system == 'windows':
        variant = 'mingw-headless' if headless else 'mingw'
    else:
        variant = 'headless' if headless else 'release'
    preset = f'{system}-{variant}'
    run(['cmake', '--preset', preset], cwd=wgrender, stdout=subprocess.DEVNULL)
    run(['cmake', '--build', '--preset', preset, '--target', 'wgrender'], cwd=wgrender)
    target = manifest(wgrender)['desktop'][system + ('-headless' if headless else '')]
    flags = [f'-l{lib}' for lib in target['libs']]
    for framework in target.get('frameworks', []):
        flags += ['-framework', framework]
    return wgrender / 'out' / system / variant / 'libwgrender.a', flags
