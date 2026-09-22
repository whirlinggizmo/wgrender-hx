#!/usr/bin/env python3
"""Start an example: everything around the source, so only the source is written.

    tools/new_example.py <name> [--entry Class] [--title "..."] [--background "#rgb"]

Writes examples/<name>/ with the build script, the headless driver and a .gitignore,
then a src/<Entry>.hx stub that starts and clears the screen. guestbuild.py generates
the page, the boot module and both hxml files at build time, so those are not here.

There is one of these per example and they differ only by name, which is exactly the
kind of thing that drifts when it is copied by hand.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

BUILD_PY = '''#!/usr/bin/env python3
"""Build `{name}` as a wgrender host with a Haxe guest on top.

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
                 'or install it:\\n'
                 '  haxelib git wgrender-hx https://github.com/whirlinggizmo/wgrender-hx')
    LIB = pathlib.Path(found)
sys.path.insert(0, str(LIB / 'tools'))
from guestbuild import Project  # noqa: E402

Project(root=pathlib.Path(__file__).resolve().parent, name='{name}', entry='{entry}',
        title='{title}', background='{background}').main()
'''

DRIVE_MJS = '''// The shared driver, in the wgrender-hx haxelib; this names the example.
import {{ dirname, join, resolve }} from "node:path";
import {{ fileURLToPath, pathToFileURL }} from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const lib = join(HERE, "../../.."); // examples/<name>/tools -> the library
process.argv.push(`--site=${{resolve(join(HERE, "../out/web"))}}`, "--label={name}");
await import(pathToFileURL(join(lib, "tools/drive.mjs")).href);
'''

STUB = '''// wgrender's {name} example, as a Haxe guest.
import wgr.*;

@:expose("WgrGuest")
class {entry} {{
	static inline final SCREEN_WIDTH = 900;
	static inline final SCREEN_HEIGHT = 700;

	static var background:Color;

	static function main():Void {{
		GuestAbi.autostart(start);
	}}

	public static function start(host:Dynamic):Bool {{
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), (_, _, _) -> {{}});
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "{name} (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}}

	static function onInit():Void {{
		// Built here, not in a static initialiser: on the web those run before the
		// host exists. Raw says so if you forget.
		background = Color.rgba(28, 28, 38);
	}}

	static function onFrame(dt:Float):Void {{
		Render.begin();
		Render.clearBackground(background);
		Text.draw("{name}", 12, 36, 24, Color.RAYWHITE);
		Render.end();
	}}
}}
'''


FLAGS = ('--entry', '--title', '--background')


def main():
    argv, args, opts = sys.argv[1:], [], {}
    i = 0
    while i < len(argv):
        if argv[i] in FLAGS and i + 1 < len(argv):
            opts[argv[i]] = argv[i + 1]
            i += 2
            continue
        if argv[i].startswith('--'):
            sys.exit(f'unknown option {argv[i]}\n{__doc__}')
        args.append(argv[i])
        i += 1
    if len(args) != 1:
        sys.exit(__doc__)
    name = args[0]
    if not re.fullmatch(r'[a-z][a-z0-9_]*', name):
        sys.exit(f'{name}: an example name is lowercase letters, digits and underscores')

    def opt(flag, default):
        return opts.get(flag, default)

    entry = opt('--entry', ''.join(p.capitalize() for p in name.split('_')))
    title = opt('--title', name)
    background = opt('--background', '#1c1c26')

    root = ROOT / 'examples' / name
    if root.exists():
        sys.exit(f'{root} already exists')
    (root / 'src').mkdir(parents=True)
    (root / 'tools').mkdir()

    (root / 'build.py').write_text(BUILD_PY.format(
        name=name, entry=entry, title=title, background=background))
    (root / 'build.py').chmod(0o755)
    (root / 'tools/drive.mjs').write_text(DRIVE_MJS.format(name=name))
    (root / '.gitignore').write_text(
        'out/\nbuild/\nweb/index.html\nweb/boot.js\nguest.hxml\ndesktop.hxml\n')
    (root / f'src/{entry}.hx').write_text(STUB.format(name=name, entry=entry))

    print(f'examples/{name}/')
    print(f'  src/{entry}.hx   the stub to replace')
    print(f'  build.py, tools/drive.mjs, .gitignore')
    print(f'\nadd {name!r} to GUESTS in examples/build.py, then: cd examples/{name} && ./build.py all')
    return 0


if __name__ == '__main__':
    sys.exit(main())
