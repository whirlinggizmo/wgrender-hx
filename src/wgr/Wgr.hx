package wgr;

#if cpp
import cpp.ConstCharStar;
#end

// wgr.h — the application: open a window, run the loop

@:buildXml('<include name="${WGR_BUILD_XML}" />')
class Wgr {
	// wgrender enters the loop here on hxcpp; on js the guest ABI does.
	#if cpp
	// --- lifecycle ---
	static var initCallback:() -> Void;
	static var frameCallback:(dt:Float, tickFraction:Float) -> Void;

	#end

	/**
		An exception that escapes into wgrender's C frames takes the loop with it, and
		the report is worse the further it gets: on the web the page freezes on an
		`Uncaught [object WebAssembly.Exception]` with the message gone; natively it
		unwinds out of `main` and exits 255. So every callback wgrender makes into
		Haxe catches at the edge and logs instead, and a bad frame stays a bad frame.

		`e.message`, not `e.details()`: hxcpp has no stack to add unless the build
		defines `HXCPP_STACK_TRACE`, so `details()` says the same thing for 57 KB more
		wasm. Define it if you want stacks and can spend that.
	**/
	@:allow(wgr)
	static function report(where:String, e:haxe.Exception):Void {
		Log.error('uncaught exception in $where: ${e.message}');
	}

	#if cpp
	static function initTrampoline(user:VoidStar):Void {
		if (initCallback == null)
			return;
		try
			initCallback()
		catch (e:haxe.Exception)
			report("the init callback", e);
	}

	static function frameTrampoline(dt:Single, tickFraction:Single, user:VoidStar):Void {
		if (frameCallback == null)
			return;
		try
			frameCallback(dt, tickFraction)
		catch (e:haxe.Exception)
			report("the frame callback", e);
	}

	/** Open the window and set up the loop. Call before anything else. **/
	public static function initValues(width:Int, height:Int, title:String, ?flags:WindowFlag):Int {
		return Raw.wgr_init_values(width, height, title, flags == null ? 0 : (flags : Int));
	}

	/** Runs once, after the window exists and before the first frame. **/
	public static function setInit(cb:() -> Void):Void {
		initCallback = cb;
		Raw.wgr_set_init(cpp.Callable.fromStaticFunction(initTrampoline), Native.nullPtr());
	}

	/** Runs every frame: `dt` seconds since the last one. **/
	public static function setFrame(cb:(dt:Float, tickFraction:Float) -> Void):Void {
		frameCallback = cb;
		Raw.wgr_set_frame(cpp.Callable.fromStaticFunction(frameTrampoline), Native.nullPtr());
	}

	/** Drive the loop. On the web this returns at once and the browser drives frames. **/
	public static inline function run():Int {
		return Raw.wgr_run();
	}

	#end

	/** Close the window / end the loop. **/
	public static inline function requestQuit():Void {
		Raw.wgr_request_quit();
	}

	public static inline function getPlatform():String {
		return Raw.wgr_get_platform().toString();
	}

	public static inline function setTargetFps(fps:Int):Void {
		Raw.wgr_set_target_fps(fps);
	}
}
