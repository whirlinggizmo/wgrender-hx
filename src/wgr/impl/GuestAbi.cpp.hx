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
	static var onAsset:(id:Int, path:String, ok:Bool) -> Void;

	public static function register(init:() -> Void, frame:(dt:Float, frameId:Int) -> Void,
			asset:(id:Int, path:String, ok:Bool) -> Void):Void {
		onInit = init;
		onFrame = frame;
		onAsset = asset;
		GuestRaw.wgr_guest_register(cpp.Callable.fromStaticFunction(initOp), cpp.Callable.fromStaticFunction(frameOp),
			cpp.Callable.fromStaticFunction(assetOp), cpp.Callable.fromStaticFunction(shutdownOp));
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

	static function shutdownOp():Int
		return 0;

	/** Checked here because it is the one point both routes pass through. **/
	public static function start(width:Int, height:Int, title:String, flags:Int):Void {
		Version.check();
		GuestRaw.wgr_guest_start(width, height, title, flags);
	}

	/** Make a file local; the host calls the asset op with `id` when it is. **/
	public static inline function loadAsset(path:String, id:Int):Bool
		return GuestRaw.wgr_guest_asset_load(path, id) != 0;

	/** On desktop there is no page: `main` is the entry, so run the guest now. **/
	public static function autostart(boot:(host:Dynamic) -> Void):Void
		boot(null);
}
