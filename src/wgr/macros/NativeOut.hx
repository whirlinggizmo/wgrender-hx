package wgr.macros;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
#end

/**
	Where a native build's C++ goes, for an hxml that is the same on every OS:

	```
	--cpp build/cpp
	--macro wgr.macros.NativeOut.build()
	```

	moves hxcpp's output to `build/<os>/<variant>/cpp`, the wg* family layout
	(whirlinggizmo/.github CONVENTIONS.md, "Build directories"): `build/linux/release/cpp`,
	`build/macos/release/cpp`, and on Windows `build/windows/msvc/cpp` or, with MinGW
	(`-D mingw` or `HXCPP_MINGW`), `build/windows/mingw/cpp`. A committed hxml can't
	name the OS it's built on; this does it at compile time. Optional: leave the line out
	and `--cpp` is where the output goes.

	It also defines `wgr-work-dir` as that build's work directory (`build/linux/release`),
	for a program that keeps files of its own there, such as a download cache:
	`haxe.macro.Compiler.getDefine("wgr-work-dir")`.
**/
class NativeOut {
	#if macro
	public static function build() {
		if (!Context.defined("cpp") || Context.defined("emscripten"))
			return;
		final os = switch (Sys.systemName()) {
			case "Windows": "windows";
			case "Mac": "macos";
			case other: other.toLowerCase();
		}
		final variant = os != "windows" ? "release" : (Context.defined("mingw") || Sys.getEnv("HXCPP_MINGW") != null) ? "mingw" : "msvc";
		Compiler.define("wgr-work-dir", 'build/$os/$variant');
		Compiler.setOutput('build/$os/$variant/cpp');
	}
	#end
}
