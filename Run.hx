/**
	`haxelib run wgrender-hx <command>`.

	An installed wgrender-hx carries wgrender as a submodule under project/lib, and
	`haxelib git` fetches it along with everything else. For a native target there is
	nothing to build here: hxcpp compiles wgrender's sources with the same toolchain
	it compiles your program with, which is what lets Windows work at all.

	The web target is different. There wgrender is a wasm *host* the page loads and
	the game is a JS guest on top of it, so the host is an emcc link that wgrender's
	own Makefile does.

	    haxelib run wgrender-hx setup          fetch the wgrender submodule
	    haxelib run wgrender-hx setup web      also build the Emscripten host library
	    haxelib run wgrender-hx where          print where wgrender is

	Nothing here is needed in a checkout of this repo: the examples and test/check.py
	define WGR_BUILD_XML and point at whatever wgrender they are working against.
**/
class Run {
	static var root:String;

	static function main():Void {
		// haxelib runs this with the library directory as the working directory and
		// the caller's directory as the last argument.
		final args = Sys.args();
		root = Sys.getCwd();
		if (args.length > 0 && sys.FileSystem.isDirectory(args[args.length - 1]))
			args.pop();

		switch (args[0]) {
			case "setup":
				setup(args[1] == "web");
			case "where":
				where();
			default:
				Sys.println(help());
				Sys.exit(args[0] == null ? 0 : 1);
		}
	}

	static function help():String
		return "haxelib run wgrender-hx setup [web]   fetch and build wgrender\n"
			+ "haxelib run wgrender-hx where         where wgrender and its library are";

	static function wgrender():String
		return haxe.io.Path.join([root, "project/lib/wgrender-c"]);

	static function setup(web:Bool):Void {
		final dir = wgrender();
		if (!sys.FileSystem.exists(haxe.io.Path.join([dir, "Makefile"]))) {
			Sys.println("fetching the wgrender submodule");
			shell("git", ["submodule", "update", "--init", "--recursive"], root);
		}
		if (!sys.FileSystem.exists(haxe.io.Path.join([dir, "include/wgr.h"]))) {
			Sys.println('no wgrender under $dir.\n'
				+ "If this is a source checkout rather than a haxelib install, there is\n"
				+ "nothing to set up: point -D WGR_BUILD_XML at your own wgrender instead.");
			Sys.exit(1);
		}
		Sys.println('wgrender is here: $dir');
		Sys.println("Nothing to build. hxcpp compiles wgrender's sources with your own\n"
			+ "toolchain when you build, so a native target needs no library from here.");

		if (web) {
			// The web target is the exception. There the game is a JS guest on a
			// wgrender wasm *host*, and that host is an emcc link rather than
			// anything hxcpp does, so it is wgrender's own Makefile that builds it.
			if (Sys.systemName() == "Windows") {
				Sys.println('\nThe web library needs `make` and Emscripten, and wgrender\'s\n'
					+ "build is a Unix Makefile. Build it under MSYS2 or WSL:\n"
					+ '  make -C "$dir" web WEB_THREADS=0');
				Sys.exit(1);
			}
			Sys.println("\nbuilding wgrender (web, no threads)");
			shell("make", ["-C", dir, "web", "WEB_THREADS=0"], root);
		}
		where();
	}

	static function where():Void {
		final dir = wgrender();
		final have = sys.FileSystem.exists(haxe.io.Path.join([dir, "include/wgr.h"]));
		Sys.println('wgrender:  $dir');
		Sys.println('  sources  ${have ? "present" : "MISSING -- run setup"}');
		final web = haxe.io.Path.join([dir, "build/webgl2-nothreads/libwgrender.a"]);
		Sys.println('  web lib  ${sys.FileSystem.exists(web) ? "built" : "not built (setup web)"}');
	}

	static function shell(command:String, args:Array<String>, cwd:String):Void {
		final was = Sys.getCwd();
		Sys.setCwd(cwd);
		final code = Sys.command(command, args);
		Sys.setCwd(was);
		if (code != 0)
			Sys.exit(code);
	}
}
