/**
	`haxelib run wgrender-hx <command>`.

	An installed wgrender-hx carries wgrender as a submodule under project/lib but not
	a built one: wgrender is C, and its own Makefile is what packs the shaders and
	vendors sokol. So there is one step between installing this and building against
	it, and this is it.

	    haxelib run wgrender-hx setup          fetch the submodule and build wgrender
	    haxelib run wgrender-hx setup web      the same, plus the Emscripten library
	    haxelib run wgrender-hx where          print where the submodule and library are

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
		if (!sys.FileSystem.exists(haxe.io.Path.join([dir, "Makefile"]))) {
			Sys.println('no wgrender under $dir.\n'
				+ "If this is a source checkout rather than a haxelib install, there is\n"
				+ "nothing to set up: point -D WGR_BUILD_XML at your own wgrender instead.");
			Sys.exit(1);
		}
		Sys.println("building wgrender (native)");
		shell("make", ["-C", dir, "all"], root);
		if (web) {
			Sys.println("building wgrender (web, no threads)");
			shell("make", ["-C", dir, "web", "WEB_THREADS=0"], root);
		}
		where();
	}

	static function where():Void {
		final dir = wgrender();
		Sys.println('wgrender:  $dir');
		for (name in ["build/desktop/libwgrender.a", "build/webgl2-nothreads/libwgrender.a"]) {
			final path = haxe.io.Path.join([dir, name]);
			Sys.println('  ${sys.FileSystem.exists(path) ? "built  " : "missing"}  $name');
		}
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
