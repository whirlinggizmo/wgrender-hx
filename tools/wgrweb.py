"""wgrender's web tooling (its tools/weblib.py: the browser, DevTools and process
handling), for the browser checks here.

    from wgrweb import W, weblib

W is the wgrender tools/wgrpath.py finds ($WGRENDER_DIR, a sibling checkout, or the
submodule), so a check here always drives the same wgrender the build used.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wgrpath import find  # noqa: E402

W = find(argv=[])
sys.path.insert(0, str(W / 'tools'))
try:
    import weblib  # noqa: E402,F401
except ImportError:
    sys.exit(f'{W} predates tools/weblib.py; update the submodule (haxelib run wgrender-hx setup)')
