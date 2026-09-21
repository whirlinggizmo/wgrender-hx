#!/usr/bin/env python3
"""Build `simple` as a wgrender host with a Haxe guest on top.

The build itself is guestbuild.py in the wgrender-hx haxelib, shared with every other
example; this says which example it is. The page, the boot module and both hxml files
are generated from these four values, so there is nothing here to keep in step.

    ./build.py host | guest | desktop | all | serve | sizes | clean
"""
import pathlib
import sys

# examples/<name>/build.py, so the library is two directories up. The hxml still says
# `-lib wgrender-hx`, which resolves through `haxelib dev` -- that way building an
# example exercises the packaging a user gets, not just the source tree.
LIB = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(LIB / 'tools'))
from guestbuild import Project  # noqa: E402

Project(root=pathlib.Path(__file__).resolve().parent, name='simple', entry='Guest',
        title='simple').main()
