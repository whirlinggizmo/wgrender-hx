#!/usr/bin/env python3
"""Build `fetch` as a wgrender host with a Haxe guest on top.

The build itself is guestbuild.py in the wgrender-hx haxelib, shared with every other
example; this says which example it is.

    ./build.py host | guest | desktop | all | serve | sizes | clean
"""
import pathlib
import subprocess
import sys

# The library: two directories up inside the repo, and wherever haxelib put it if
# this example has been copied out to start a project from. Only the bootstrap needs
# to know -- everything else comes from guestbuild.
LIB = pathlib.Path(__file__).resolve().parents[2]
if not (LIB / 'tools/guestbuild.py').exists():
    found = subprocess.run(['haxelib', 'libpath', 'wgrender-hx'],
                           capture_output=True, text=True).stdout.strip()
    if not found:
        sys.exit('wgrender-hx not found. Either keep this example inside the library, '
                 'or install it:\n'
                 '  haxelib git wgrender-hx https://github.com/whirlinggizmo/wgrender-hx')
    LIB = pathlib.Path(found)
sys.path.insert(0, str(LIB / 'tools'))
from guestbuild import Project  # noqa: E402

# -D WGR_INCLUDE_FETCHER: this is the one example that downloads, so it is the one
# that pays for a TLS stack. Everything else builds without it and without mbedtls.
Project(root=pathlib.Path(__file__).resolve().parent, name='fetch', entry='Fetch', defines=['WGR_INCLUDE_FETCHER'], 
        title='fetch', background='#1c1c26').main()
