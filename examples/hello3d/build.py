#!/usr/bin/env python3
"""Build `hello3d` as a wgrender host with a Haxe guest on top.

The build itself is guestbuild.py in the wgrender-hx haxelib, shared with every other
example; this says which example it is.

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

Project(root=pathlib.Path(__file__).resolve().parent, name='hello3d', entry='Hello3D',
        title='hello3d', background='#1c1c26').main()
