#!/usr/bin/env python3
"""Build `simple` as a wgrender host with a Haxe guest on top.

The build itself is guestbuild.py in the wgrender-hx haxelib, shared with every other
example; this says which example it is. The page, the boot module and both hxml files
are generated from these four values, so there is nothing here to keep in step.

    ./build.py host | guest | desktop | all | serve | sizes | clean
"""
import pathlib
import subprocess
import sys

LIB = pathlib.Path(subprocess.run(['haxelib', 'path', 'wgrender-hx'], check=True,
                                  capture_output=True, text=True).stdout.split('\n')[0].strip()).parent
sys.path.insert(0, str(LIB / 'tools'))
from guestbuild import Project  # noqa: E402

Project(root=pathlib.Path(__file__).resolve().parent, name='simple', entry='Guest',
        title='simple').main()
