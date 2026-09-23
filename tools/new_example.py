#!/usr/bin/env python3
"""Start an example: everything around the source, so only the source is written.

    tools/new_example.py <name> [--entry Class] [--title "..."] [--background "#rgb"]

Writes examples/<name>/ with build.web.hxml and build.desktop.hxml -- the build, and
what a user copies -- a .gitignore, and a src/<Entry>.hx stub that starts and clears
the screen. That is the whole example: examples/build.py runs the suite's chores for it
by name, and wgr.macros.WebHost writes the page and its boot module into out/web when
the web build runs.

There is one of these per example and they differ only by name, which is exactly the
kind of thing that drifts when it is copied by hand.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

WEB_HXML = '''# {name}, for the web: the Haxe guest compiled to JS, and a wasm host linked to
# exactly the wgrender calls it makes. `haxe build.web.hxml`, then serve out/web; the
# page loads its assets from /assets on the same origin.
-cp src
-lib wgrender-hx
--main {entry}
--js out/web/{name}.js

-D js-es=6
-dce full
-D analyzer-optimize
{title}-D wgr-background={background}
--macro wgr.macros.WebHost.build()
'''

DESKTOP_HXML = '''# {name}, native: the same guest source through hxcpp, with wgrender compiled into
# the binary. `haxe build.desktop.hxml`; the program looks for assets/ beside itself.
-cp src
-lib wgrender-hx
--main {entry}
--cpp build/cpp/desktop

-D HAXE_OUTPUT_FILE={name}-guest
-dce full
-D analyzer-optimize
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
    # A leading digit is allowed because wgrender has an example called 2d and these
    # are named after the C file they port. Only the entry class cannot start with one,
    # and that is what --entry is for.
    if not re.fullmatch(r'[a-z0-9][a-z0-9_]*', name):
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

    # the page's title defaults to the example's name, so only a different one is written
    (root / 'build.web.hxml').write_text(WEB_HXML.format(
        name=name, entry=entry, background=background,
        title='' if title == name else f'-D wgr-title={title}\n'))
    (root / 'build.desktop.hxml').write_text(DESKTOP_HXML.format(name=name, entry=entry))
    (root / '.gitignore').write_text('out/\nbuild/\n')
    (root / f'src/{entry}.hx').write_text(STUB.format(name=name, entry=entry))

    print(f'examples/{name}/')
    print(f'  src/{entry}.hx   the stub to replace')
    print(f'  build.web.hxml, build.desktop.hxml   the build')
    print(f'\nadd {name!r} to GUESTS in examples/build.py, then: examples/build.py all {name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
