package wgr;


/**
	The guest side of `host/wgr_guest.h`, for the JS target: the host is an Emscripten
	module and the ops are JS functions turned into C function pointers.

	Haxe picks this over `GuestAbi.cpp.hx` by target, so `Guest.hx` carries no `#if` of
	its own — the whole point of doing this in Haxe rather than twice.

	Each op wrapper owns two things the C side can't do for us:

	- **it catches**, converting a throw into the nonzero return the ABI expects,
	  because an exception escaping into the host's frames freezes the page on an
	  opaque `Uncaught [object WebAssembly.Exception]`;
	- **it releases the scratch arena** — `Raw` allocates strings and struct-return
	  slots on the wasm stack, and Haxe has no `finally`, so the op edge restores the
	  stack pointer once, fault or not.
**/
class GuestAbi {
	/** The Emscripten module every call goes through. **/
	public static function attach(host:Dynamic):Void
		Raw.attach(host);

	static var onInit:() -> Void;
	static var onFrame:(dt:Float, frameId:Int) -> Void;
	static var onTick:(dt:Float) -> Void;
	static var onAsset:(id:Int, path:String, ok:Bool) -> Void;
	static var onShutdown:() -> Void;

	/**
		`shutdown` is optional and runs once, after the last frame, on the way out --
		wgrender's `wgr_set_cleanup` for a guest. It is the op to release anything the
		guest owns outside wgrender; anything wgrender owns is already being torn down.

		Left out, the slot stays 0 rather than being filled with a function that does
		nothing: an op costs a table entry in the wasm module for as long as it is
		installed, and `addFunction` cannot take one back.
	**/
	public static function register(init:() -> Void, frame:(dt:Float, frameId:Int) -> Void,
			asset:(id:Int, path:String, ok:Bool) -> Void, ?shutdown:() -> Void):Void {
		onInit = init;
		onFrame = frame;
		onAsset = asset;
		onShutdown = shutdown;
		Raw.host._wgr_guest_register(op("init", "i", () -> onInit()),
			op("frame", "ifi", (dt:Float, frameId:Int) -> onFrame(dt, frameId)),
			op("asset", "iiii", (id:Int, path:Int, ok:Int) -> onAsset(id, Raw.str(path), ok != 0)),
			shutdown == null ? 0 : op("shutdown", "i", () -> onShutdown()));
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
		Raw.host._wgr_guest_register_tick(op("tick", "if", (dt:Float) -> onTick(dt)), hz);
	}

	/** How far this frame is into the next tick, 0..1. 0 without a tick. **/
	public static inline function tickFraction():Float
		return Raw.host._wgr_guest_tick_fraction();

	static function op(name:String, signature:String, body:Dynamic):Int {
		return Raw.host.addFunction(Reflect.makeVarArgs(args -> {
			final mark = Raw.stackMark();
			var code = 0;
			try
				Reflect.callMethod(null, body, args)
			catch (e:haxe.Exception) {
				Log.error('guest: uncaught exception in $name: ${e.message}');
				code = 1;
			}
			Raw.stackRelease(mark);
			return code;
		}), signature);
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
		final mark = Raw.stackMark();
		Raw.host._wgr_guest_start(width, height, Raw.cstr(title), flags == null ? 0 : (flags : Int));
		Raw.stackRelease(mark);
		return true;
	}

	/** Make a file local; the host calls the asset op with `id` when it is. **/
	/**
		Make a file local; the host calls the asset op with `id` when it is.

		`fetchUrl` overrides where the bytes are downloaded from, without changing the
		key they are cached and resolved under -- a mirror, a CDN, a signed link. It is
		used verbatim, so a relative URL is relative to the page. `flags` is
		wgrender's, `ForceFetch` being the one worth knowing: fetch even if the cache
		already has it.
	**/
	public static inline function loadAsset(path:String, id:Int, ?fetchUrl:String, ?flags:AssetFlag):Bool
		return Raw.wgr_guest_asset_load(path, id, fetchUrl, flags == null ? 0 : (flags : Int));

	/** On js the page owns startup: web/boot.js loads the host, then calls `start`. **/
	public static function autostart(_:(host:Dynamic) -> Void):Void {}
}
