package wgr.impl;

import wgr.impl.GuestRaw;

/**
	The guest side of `host/wgr_guest.h`, for the hxcpp target: the host is the same C
	glue compiled into this binary, and the ops are plain function pointers.

	The counterpart of `GuestAbi.js.hx`. There is no scratch arena here — hxcpp passes
	strings and structs directly — but the ops still catch, because an exception that
	escapes into wgrender's C frames unwinds out of `main` and exits 255.

	Note what is *not* different: there is no wasm, no module to load and no host
	process. On desktop the Haxe program is the entry point, and `autostart` runs the
	guest from `main` where the page's boot script would on the web.
**/
class GuestAbi {
	/** Nothing to attach: the host is linked into this binary. **/
	public static function attach(_:Dynamic):Void {}

	static var onInit:() -> Void;
	static var onFrame:(dt:Float, frameId:Int) -> Void;
	static var onTick:(dt:Float) -> Void;
	static var onAsset:(id:Int, path:String, ok:Bool) -> Void;
	static var onShutdown:() -> Void;

	/**
		`shutdown` is optional and runs once, after the last frame, on the way out --
		wgrender's `wgr_set_cleanup` for a guest. It is the op to release anything the
		guest owns outside wgrender; anything wgrender owns is already being torn down.
	**/
	public static function register(init:() -> Void, frame:(dt:Float, frameId:Int) -> Void,
			asset:(id:Int, path:String, ok:Bool) -> Void, ?shutdown:() -> Void):Void {
		onInit = init;
		onFrame = frame;
		onAsset = asset;
		onShutdown = shutdown;
		GuestRaw.wgr_guest_register(cpp.Callable.fromStaticFunction(initOp), cpp.Callable.fromStaticFunction(frameOp),
			cpp.Callable.fromStaticFunction(assetOp), cpp.Callable.fromStaticFunction(shutdownOp));
	}

	/**
		Fixed-rate simulation: `tick` runs 0..N times before each frame, always with
		`dt` of 1/`hz`. Optional, and set on its own because it is the one op that
		needs configuring. `hz` of 0 or less turns it off.

		Draw in the frame op, not here, and use `tickFraction` there to interpolate
		between the last two tick states.
	**/
	public static function registerTick(tick:(dt:Float) -> Void, hz:Int):Void {
		onTick = tick;
		GuestRaw.wgr_guest_register_tick(cpp.Callable.fromStaticFunction(tickOp), hz);
	}

	/** How far this frame is into the next tick, 0..1. 0 without a tick. **/
	public static inline function tickFraction():Float
		return GuestRaw.wgr_guest_tick_fraction();

	static function tickOp(dt:Single):Int {
		try
			onTick(dt)
		catch (e:haxe.Exception) {
			Log.error('guest: uncaught exception in tick: ${e.message}');
			return 1;
		}
		return 0;
	}

	static function initOp():Int {
		try
			onInit()
		catch (e:haxe.Exception) {
			Log.error('guest: uncaught exception in init: ${e.message}');
			return 1;
		}
		return 0;
	}

	static function frameOp(dt:Single, frameId:cpp.UInt32):Int {
		try
			onFrame(dt, frameId)
		catch (e:haxe.Exception) {
			Log.error('guest: uncaught exception in frame: ${e.message}');
			return 1;
		}
		return 0;
	}

	static function assetOp(id:cpp.UInt32, path:cpp.ConstCharStar, ok:Int):Int {
		try
			onAsset(id, path.toString(), ok != 0)
		catch (e:haxe.Exception) {
			Log.error('guest: uncaught exception in asset: ${e.message}');
			return 1;
		}
		return 0;
	}

	static function shutdownOp():Int {
		if (onShutdown == null)
			return 0;
		try
			onShutdown()
		catch (e:haxe.Exception) {
			Log.error('guest: uncaught exception in shutdown: ${e.message}');
			return 1;
		}
		return 0;
	}

	/**
		Refuses on a version mismatch rather than starting: unlike a frame fault, it is
		known before anything runs, it is total — every call may be wrong — and there is
		no recovering from it. Starting anyway would turn one clear error into a pile of
		confusing ones. (librl's BOOT_ERR_VERSION_MISMATCH does the same.)

		Checked here because it is the one point both routes pass through.
	**/
	public static function start(width:Int, height:Int, title:String, ?flags:WindowFlag):Bool {
		if (!Version.check())
			return false;
		GuestRaw.wgr_guest_start(width, height, title, flags == null ? 0 : (flags : Int));
		return true;
	}

	/** Make a file local; the host calls the asset op with `id` when it is. **/
	public static inline function loadAsset(path:String, id:Int):Bool
		return GuestRaw.wgr_guest_asset_load(path, id) != 0;

	/** On desktop there is no page: `main` is the entry, so run the guest now. **/
	public static function autostart(boot:(host:Dynamic) -> Void):Void
		boot(null);
}
