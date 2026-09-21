#!/usr/bin/env python3
"""Build `hello3d` as a wgrender host with a Haxe guest on top.

The build itself is guestbuild.py in the wgrender-hx haxelib, shared with every other
example; this says which example it is.

    ./build.py host | guest | desktop | all | serve | sizes | clean
"""
import pathlib
import subprocess
import sys

LIB = pathlib.Path(subprocess.run(['haxelib', 'path', 'wgrender-hx'], check=True,
                                  capture_output=True, text=True).stdout.split('\n')[0].strip()).parent
sys.path.insert(0, str(LIB / 'tools'))
from guestbuild import Project  # noqa: E402

Project(root=pathlib.Path(__file__).resolve().parent, name='hello3d', entry='Hello3D',
        title='hello3d', background='#1c1c26').main()
