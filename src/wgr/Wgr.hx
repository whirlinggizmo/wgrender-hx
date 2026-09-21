package wgr;

#if cpp
import cpp.ConstCharStar;
#end
import wgr.Raw;

/**
	wgrender for Haxe: the C API (`wgr.Raw`) wrapped in stock Haxe types.

	- `String`, `Int` and `Float` instead of `ConstCharStar` / `Single`
	- `enum abstract`s and an or-able `WindowFlag` instead of C constants
	- vectors, mouse and pick state as small Haxe objects
	- closures for callbacks, called through static trampolines
	- an abstract per handle kind (`Model`, `Texture`, `Font`, ...) carrying that
	  kind's methods, so `model.tint = c` is a call and passing the wrong kind is a
	  compile error; the zero value is "none" (`isNone`)
	- C `wgr_foo_bar(foo, ...)` is Haxe `foo.bar(...)` where `foo` is a handle, and
	  `Foo.bar(...)` otherwise

	Every abstract here is over an `Int`, so the whole layer compiles away: a call
	costs exactly what the C call costs. The only allocations are the small value
	objects (`Vec2`, `Vec3`, `MouseState`, `PickResult`) the wrappers hand back.

	`wgr.Raw` has the same slice of the C API as is, for anything not wrapped here.
**/
// NOTE: ../simple carries an @:buildXml here. It is on wgr.GuestAbi instead in this
// project: this guest never calls Wgr's lifecycle, so -dce full strips the class and
// the metadata would go with it. Something that survives DCE has to carry it.
class Wgr {
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

#if cpp
/** Small helpers the wrappers need to reach C from Haxe. **/
@:noCompletion
@:cppFileCode('#include <stdint.h>')
class Native {
	/** A `void *` / `const char *` null that survives hxcpp's type checking. **/
	public static inline function nullPtr():VoidStar {
		return untyped __cpp__("nullptr");
	}

	public static inline function nullStr():ConstCharStar {
		return untyped __cpp__("(const char *)nullptr");
	}

	/** wgrender's callbacks carry a `void *`; we carry a table key in it. **/
	public static inline function toUser(id:Int):VoidStar {
		return untyped __cpp__("(void *)(intptr_t)({0})", id);
	}

	public static inline function fromUser(user:VoidStar):Int {
		return untyped __cpp__("(int)(intptr_t)({0})", user);
	}

	public static inline function cstr(s:String):ConstCharStar {
		return s == null ? nullStr() : ConstCharStar.fromString(s);
	}
}

#end

// ---------------------------------------------------------------- values ----

/** An untyped wgrender handle (what a pick result hits); 0 is none. **/
abstract Handle(Int) from Int to Int {
	/** The zero handle: not created (yet), or creation failed. Assignable to any kind. **/
	public static final NONE:Handle = 0;

	public var isNone(get, never):Bool;

	inline function get_isNone():Bool
		return this == 0;

	/** wgrender's C `wgr_handle_t`. **/
	@:to inline function toRaw():WgrHandle
		return this;

	public inline function toString():String
		return Std.string(this);
}

/** A packed 0xRRGGBBAA color, by value. **/
abstract Color(Int) from Int to Int {
	public static inline var WHITE:Color = cast 0xFFFFFFFF;
	public static inline var BLACK:Color = cast 0x000000FF;
	public static inline var BLUE:Color = cast 0x0079F1FF;
	public static inline var RAYWHITE:Color = cast 0xF5F5F5FF;

	public static inline function rgba(r:Int, g:Int, b:Int, a:Int):Color
		return Raw.wgr_color_rgba(r, g, b, a);

	/** wgrender's C `wgr_color_t`. **/
	@:to inline function toRaw():WgrColor
		return this;
}

@:structInit
class Vec2 {
	public final x:Float;
	public final y:Float;

	public inline function new(x:Float = 0, y:Float = 0) {
		this.x = x;
		this.y = y;
	}

	public function toString():String
		return '($x, $y)';
}

@:structInit
class Vec3 {
	public final x:Float;
	public final y:Float;
	public final z:Float;

	public inline function new(x:Float = 0, y:Float = 0, z:Float = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	public function toString():String
		return '($x, $y, $z)';
}

@:structInit
class MouseState {
	public final x:Int;
	public final y:Int;

	/** Scroll this frame: about one unit per wheel notch. **/
	public final wheel:Float;

	public final wheelX:Float;
	public final left:Int;
	public final right:Int;
	public final middle:Int;
	public final buttons:Array<Int>;
	public final dx:Int;
	public final dy:Int;

	public function new(x, y, wheel, wheelX, left, right, middle, buttons, dx, dy) {
		this.x = x;
		this.y = y;
		this.wheel = wheel;
		this.wheelX = wheelX;
		this.left = left;
		this.right = right;
		this.middle = middle;
		this.buttons = buttons;
		this.dx = dx;
		this.dy = dy;
	}
}

@:structInit
class PickResult {
	public final hit:Bool;

	/** Compare with typed handles: `pick.handle == model`. **/
	public final handle:Handle;

	/** World-space distance from the ray origin to the hit. **/
	public final distance:Float;

	public final pointLocal:Vec3;
	public final pointWorld:Vec3;
	public final normalLocal:Vec3;
	public final normalWorld:Vec3;

	public function new(hit, handle, distance, pointLocal, pointWorld, normalLocal, normalWorld) {
		this.hit = hit;
		this.handle = handle;
		this.distance = distance;
		this.pointLocal = pointLocal;
		this.pointWorld = pointWorld;
		this.normalLocal = normalLocal;
		this.normalWorld = normalWorld;
	}
}

// ----------------------------------------------------------------- enums ----

/** Window flags, or-ed together: `Msaa4x | Resizable`. **/
enum abstract WindowFlag(Int) to Int {
	var Fullscreen = 0x00000002;
	var Resizable = 0x00000004;
	var Undecorated = 0x00000008;
	var Transparent = 0x00000010;
	var Msaa4x = 0x00000020;
	var VsyncOff = 0x00000040;
	var Hidden = 0x00000080;
	var LowDpi = 0x00002000;

	@:op(A | B)
	public static inline function or(a:WindowFlag, b:WindowFlag):WindowFlag
		return cast((a : Int) | (b : Int));
}

enum abstract LogLevel(Int) to Int {
	var Trace = 0;
	var Debug = 1;
	var Info = 2;
	var Warn = 3;
	var Error = 4;
	var Fatal = 5;

	#if cpp
	/** C++ needs the cast: the header says `wgr_log_level_t`, not `int`. **/
	@:to inline function toRaw():CLogLevel
		return untyped __cpp__("(wgr_log_level_t)({0})", this);
	#end
}

/** Asset flags, or-ed together. **/
enum abstract AssetFlag(Int) to Int {
	/** Re-download even if cached. **/
	var ForceFetch = 1 << 0;

	/** Only make the file local; don't load the resource it names. **/
	var FileOnly = 1 << 1;

	@:op(A | B)
	public static inline function or(a:AssetFlag, b:AssetFlag):AssetFlag
		return cast((a : Int) | (b : Int));
}

enum abstract Projection(Int) to Int {
	var Perspective = 0;
	var Orthographic = 1;

	#if cpp
	/** C++ needs the cast: the header says `wgr_camera3d_projection_t`, not `int`. **/
	@:to inline function toRaw():CProjection
		return untyped __cpp__("(wgr_camera3d_projection_t)({0})", this);
	#end
}

enum abstract LightKind(Int) to Int {
	var Directional = 0;
	var Point = 1;
	var Spot = 2;

	#if cpp
	/** C++ needs the cast: the header says `wgr_light_type_t`, not `int`. **/
	@:to inline function toRaw():CLightType
		return untyped __cpp__("(wgr_light_type_t)({0})", this);
	#end
}

enum abstract SpriteFacing(Int) to Int {
	/** Parallel to the view plane. **/
	var Camera = 0;

	/** Turns about world Y to face the camera, stays upright. **/
	var CameraFixedY = 1;

	/** Flat in the XZ plane, normal +Y. **/
	var YUp = 2;

	/** Its own rotation: the local XY plane, facing +Z. **/
	var Free = 3;

	#if cpp
	/** C++ needs the cast: the header says `wgr_sprite3d_facing_t`, not `int`. **/
	@:to inline function toRaw():CSpriteFacing
		return untyped __cpp__("(wgr_sprite3d_facing_t)({0})", this);
	#end
}

/**
	Where a block of text sits horizontally relative to its position. wgrender has one
	C enum for both axes and returns false for a value meant for the other one; this
	splits it in two, so `setAlign(Top, Left)` doesn't compile.
**/
enum abstract AlignX(Int) to Int {
	var Left = 0;
	var Center = 1;
	var Right = 2;

	#if cpp
	/** C++ needs the cast: the header says `wgr_text_align_t`, not `int`. **/
	@:to inline function toRaw():CTextAlign
		return untyped __cpp__("(wgr_text_align_t)({0})", this);
	#end
}

/** Where a block of text sits vertically relative to its position. See `AlignX`. **/
enum abstract AlignY(Int) to Int {
	var Top = 3;
	var Middle = 4;
	var Bottom = 5;

	#if cpp
	/** C++ needs the cast: the header says `wgr_text_align_t`, not `int`. **/
	@:to inline function toRaw():CTextAlign
		return untyped __cpp__("(wgr_text_align_t)({0})", this);
	#end
}

enum abstract ButtonState(Int) from Int to Int {
	/** Not held. **/
	var Up = 0;

	/** Went down this frame. **/
	var Pressed = 1;

	/** Held. **/
	var Down = 2;

	/** Went up this frame. **/
	var Released = 3;
}

// @@KEYS@@
// Generated by tools/gen_keys.py from wgrender's include/wgr_keys.h — do not edit.

/**
	wgrender's key codes (`WGR_KEY_*`, wgr_keys.h). The numbers currently follow the
	GLFW/sokol layout, but that is an implementation detail: code to the names.
	`KeyCheck` below asserts them against the header at C++ compile time.
**/
enum abstract Key(Int) from Int to Int {
	var Space = 32;
	var Apostrophe = 39;
	var Comma = 44;
	var Minus = 45;
	var Period = 46;
	var Slash = 47;
	var Digit0 = 48;
	var Digit1 = 49;
	var Digit2 = 50;
	var Digit3 = 51;
	var Digit4 = 52;
	var Digit5 = 53;
	var Digit6 = 54;
	var Digit7 = 55;
	var Digit8 = 56;
	var Digit9 = 57;
	var Semicolon = 59;
	var Equal = 61;
	var A = 65;
	var B = 66;
	var C = 67;
	var D = 68;
	var E = 69;
	var F = 70;
	var G = 71;
	var H = 72;
	var I = 73;
	var J = 74;
	var K = 75;
	var L = 76;
	var M = 77;
	var N = 78;
	var O = 79;
	var P = 80;
	var Q = 81;
	var R = 82;
	var S = 83;
	var T = 84;
	var U = 85;
	var V = 86;
	var W = 87;
	var X = 88;
	var Y = 89;
	var Z = 90;
	var LeftBracket = 91;
	var Backslash = 92;
	var RightBracket = 93;
	var GraveAccent = 96;
	var Escape = 256;
	var Enter = 257;
	var Tab = 258;
	var Backspace = 259;
	var Insert = 260;
	var Delete = 261;
	var Right = 262;
	var Left = 263;
	var Down = 264;
	var Up = 265;
	var PageUp = 266;
	var PageDown = 267;
	var Home = 268;
	var End = 269;
	var CapsLock = 280;
	var F1 = 290;
	var F2 = 291;
	var F3 = 292;
	var F4 = 293;
	var F5 = 294;
	var F6 = 295;
	var F7 = 296;
	var F8 = 297;
	var F9 = 298;
	var F10 = 299;
	var F11 = 300;
	var F12 = 301;
	var LeftShift = 340;
	var LeftControl = 341;
	var LeftAlt = 342;
	var LeftSuper = 343;
	var RightShift = 344;
	var RightControl = 345;
	var RightAlt = 346;
	var RightSuper = 347;

	#if cpp
	/** C++ needs the cast: the header says `wgr_keycode_t`, not `int`. **/
	@:to inline function toRaw():CKeycode
		return untyped __cpp__("(wgr_keycode_t)({0})", this);
	#end
}

@:keep
@:noCompletion
@:cppFileCode('#include <wgr_keys.h>
static_assert(WGR_KEY_SPACE == 32, "wgr.Wgr Key.Space is out of date with wgr_keys.h");
static_assert(WGR_KEY_APOSTROPHE == 39, "wgr.Wgr Key.Apostrophe is out of date with wgr_keys.h");
static_assert(WGR_KEY_COMMA == 44, "wgr.Wgr Key.Comma is out of date with wgr_keys.h");
static_assert(WGR_KEY_MINUS == 45, "wgr.Wgr Key.Minus is out of date with wgr_keys.h");
static_assert(WGR_KEY_PERIOD == 46, "wgr.Wgr Key.Period is out of date with wgr_keys.h");
static_assert(WGR_KEY_SLASH == 47, "wgr.Wgr Key.Slash is out of date with wgr_keys.h");
static_assert(WGR_KEY_0 == 48, "wgr.Wgr Key.Digit0 is out of date with wgr_keys.h");
static_assert(WGR_KEY_1 == 49, "wgr.Wgr Key.Digit1 is out of date with wgr_keys.h");
static_assert(WGR_KEY_2 == 50, "wgr.Wgr Key.Digit2 is out of date with wgr_keys.h");
static_assert(WGR_KEY_3 == 51, "wgr.Wgr Key.Digit3 is out of date with wgr_keys.h");
static_assert(WGR_KEY_4 == 52, "wgr.Wgr Key.Digit4 is out of date with wgr_keys.h");
static_assert(WGR_KEY_5 == 53, "wgr.Wgr Key.Digit5 is out of date with wgr_keys.h");
static_assert(WGR_KEY_6 == 54, "wgr.Wgr Key.Digit6 is out of date with wgr_keys.h");
static_assert(WGR_KEY_7 == 55, "wgr.Wgr Key.Digit7 is out of date with wgr_keys.h");
static_assert(WGR_KEY_8 == 56, "wgr.Wgr Key.Digit8 is out of date with wgr_keys.h");
static_assert(WGR_KEY_9 == 57, "wgr.Wgr Key.Digit9 is out of date with wgr_keys.h");
static_assert(WGR_KEY_SEMICOLON == 59, "wgr.Wgr Key.Semicolon is out of date with wgr_keys.h");
static_assert(WGR_KEY_EQUAL == 61, "wgr.Wgr Key.Equal is out of date with wgr_keys.h");
static_assert(WGR_KEY_A == 65, "wgr.Wgr Key.A is out of date with wgr_keys.h");
static_assert(WGR_KEY_B == 66, "wgr.Wgr Key.B is out of date with wgr_keys.h");
static_assert(WGR_KEY_C == 67, "wgr.Wgr Key.C is out of date with wgr_keys.h");
static_assert(WGR_KEY_D == 68, "wgr.Wgr Key.D is out of date with wgr_keys.h");
static_assert(WGR_KEY_E == 69, "wgr.Wgr Key.E is out of date with wgr_keys.h");
static_assert(WGR_KEY_F == 70, "wgr.Wgr Key.F is out of date with wgr_keys.h");
static_assert(WGR_KEY_G == 71, "wgr.Wgr Key.G is out of date with wgr_keys.h");
static_assert(WGR_KEY_H == 72, "wgr.Wgr Key.H is out of date with wgr_keys.h");
static_assert(WGR_KEY_I == 73, "wgr.Wgr Key.I is out of date with wgr_keys.h");
static_assert(WGR_KEY_J == 74, "wgr.Wgr Key.J is out of date with wgr_keys.h");
static_assert(WGR_KEY_K == 75, "wgr.Wgr Key.K is out of date with wgr_keys.h");
static_assert(WGR_KEY_L == 76, "wgr.Wgr Key.L is out of date with wgr_keys.h");
static_assert(WGR_KEY_M == 77, "wgr.Wgr Key.M is out of date with wgr_keys.h");
static_assert(WGR_KEY_N == 78, "wgr.Wgr Key.N is out of date with wgr_keys.h");
static_assert(WGR_KEY_O == 79, "wgr.Wgr Key.O is out of date with wgr_keys.h");
static_assert(WGR_KEY_P == 80, "wgr.Wgr Key.P is out of date with wgr_keys.h");
static_assert(WGR_KEY_Q == 81, "wgr.Wgr Key.Q is out of date with wgr_keys.h");
static_assert(WGR_KEY_R == 82, "wgr.Wgr Key.R is out of date with wgr_keys.h");
static_assert(WGR_KEY_S == 83, "wgr.Wgr Key.S is out of date with wgr_keys.h");
static_assert(WGR_KEY_T == 84, "wgr.Wgr Key.T is out of date with wgr_keys.h");
static_assert(WGR_KEY_U == 85, "wgr.Wgr Key.U is out of date with wgr_keys.h");
static_assert(WGR_KEY_V == 86, "wgr.Wgr Key.V is out of date with wgr_keys.h");
static_assert(WGR_KEY_W == 87, "wgr.Wgr Key.W is out of date with wgr_keys.h");
static_assert(WGR_KEY_X == 88, "wgr.Wgr Key.X is out of date with wgr_keys.h");
static_assert(WGR_KEY_Y == 89, "wgr.Wgr Key.Y is out of date with wgr_keys.h");
static_assert(WGR_KEY_Z == 90, "wgr.Wgr Key.Z is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT_BRACKET == 91, "wgr.Wgr Key.LeftBracket is out of date with wgr_keys.h");
static_assert(WGR_KEY_BACKSLASH == 92, "wgr.Wgr Key.Backslash is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT_BRACKET == 93, "wgr.Wgr Key.RightBracket is out of date with wgr_keys.h");
static_assert(WGR_KEY_GRAVE_ACCENT == 96, "wgr.Wgr Key.GraveAccent is out of date with wgr_keys.h");
static_assert(WGR_KEY_ESCAPE == 256, "wgr.Wgr Key.Escape is out of date with wgr_keys.h");
static_assert(WGR_KEY_ENTER == 257, "wgr.Wgr Key.Enter is out of date with wgr_keys.h");
static_assert(WGR_KEY_TAB == 258, "wgr.Wgr Key.Tab is out of date with wgr_keys.h");
static_assert(WGR_KEY_BACKSPACE == 259, "wgr.Wgr Key.Backspace is out of date with wgr_keys.h");
static_assert(WGR_KEY_INSERT == 260, "wgr.Wgr Key.Insert is out of date with wgr_keys.h");
static_assert(WGR_KEY_DELETE == 261, "wgr.Wgr Key.Delete is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT == 262, "wgr.Wgr Key.Right is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT == 263, "wgr.Wgr Key.Left is out of date with wgr_keys.h");
static_assert(WGR_KEY_DOWN == 264, "wgr.Wgr Key.Down is out of date with wgr_keys.h");
static_assert(WGR_KEY_UP == 265, "wgr.Wgr Key.Up is out of date with wgr_keys.h");
static_assert(WGR_KEY_PAGE_UP == 266, "wgr.Wgr Key.PageUp is out of date with wgr_keys.h");
static_assert(WGR_KEY_PAGE_DOWN == 267, "wgr.Wgr Key.PageDown is out of date with wgr_keys.h");
static_assert(WGR_KEY_HOME == 268, "wgr.Wgr Key.Home is out of date with wgr_keys.h");
static_assert(WGR_KEY_END == 269, "wgr.Wgr Key.End is out of date with wgr_keys.h");
static_assert(WGR_KEY_CAPS_LOCK == 280, "wgr.Wgr Key.CapsLock is out of date with wgr_keys.h");
static_assert(WGR_KEY_F1 == 290, "wgr.Wgr Key.F1 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F2 == 291, "wgr.Wgr Key.F2 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F3 == 292, "wgr.Wgr Key.F3 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F4 == 293, "wgr.Wgr Key.F4 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F5 == 294, "wgr.Wgr Key.F5 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F6 == 295, "wgr.Wgr Key.F6 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F7 == 296, "wgr.Wgr Key.F7 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F8 == 297, "wgr.Wgr Key.F8 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F9 == 298, "wgr.Wgr Key.F9 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F10 == 299, "wgr.Wgr Key.F10 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F11 == 300, "wgr.Wgr Key.F11 is out of date with wgr_keys.h");
static_assert(WGR_KEY_F12 == 301, "wgr.Wgr Key.F12 is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT_SHIFT == 340, "wgr.Wgr Key.LeftShift is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT_CONTROL == 341, "wgr.Wgr Key.LeftControl is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT_ALT == 342, "wgr.Wgr Key.LeftAlt is out of date with wgr_keys.h");
static_assert(WGR_KEY_LEFT_SUPER == 343, "wgr.Wgr Key.LeftSuper is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT_SHIFT == 344, "wgr.Wgr Key.RightShift is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT_CONTROL == 345, "wgr.Wgr Key.RightControl is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT_ALT == 346, "wgr.Wgr Key.RightAlt is out of date with wgr_keys.h");
static_assert(WGR_KEY_RIGHT_SUPER == 347, "wgr.Wgr Key.RightSuper is out of date with wgr_keys.h");')
class KeyCheck {
	// Exists only to give the static_asserts above a translation unit.
	static function __check():Void {}
}
// @@KEYS-END@@

// --------------------------------------------------------------- logging ----

class Log {
	public static inline function setLevel(level:LogLevel):Void
		Raw.wgr_logger_set_level(level);

	public static inline function message(level:LogLevel, msg:String):Void
		Raw.wgr_logger_message(level, "%s", msg);

	public static inline function trace(msg:String):Void
		message(Trace, msg);

	public static inline function debug(msg:String):Void
		message(Debug, msg);

	public static inline function info(msg:String):Void
		message(Info, msg);

	public static inline function warn(msg:String):Void
		message(Warn, msg);

	public static inline function error(msg:String):Void
		message(Error, msg);

	public static inline function fatal(msg:String):Void
		message(Fatal, msg);
}

// ---------------------------------------------------------------- assets ----

#if cpp
/**
	A pending "make this file local" task. Attach callbacks with `then`; wgrender
	fires exactly one of them on the main thread during a later frame, then frees
	the task.
**/
abstract AssetTask(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/**
		`wgr_asset_add_task`. False (and no callback) if the task is invalid or the
		queue is full.
	**/
	public inline function then(onSuccess:(path:String) -> Void, ?onFailure:(path:String) -> Void):Bool
		return Asset.addTask(cast this, onSuccess, onFailure);
}

#end

class Asset {
	#if cpp
	static var pending = new Map<Int, {onSuccess:(path:String) -> Void, onFailure:(path:String) -> Void}>();
	static var nextId = 1;
	#end

	/** Where relative asset paths resolve from: a directory or a URL base. **/
	public static inline function setHost(host:String):Void
		Raw.wgr_asset_set_host(host);

#if cpp
	/** A task to attach callbacks to (`AssetTask.then`); none on failure. **/
	public static inline function ensureAsync(path:String, ?fetchUrl:String, ?flags:AssetFlag):AssetTask
		return (Raw.wgr_asset_ensure_async(path, Native.cstr(fetchUrl), flags == null ? 0 : (flags : Int)) : Handle);

	@:allow(wgr.AssetTask)
	static function addTask(task:Handle, onSuccess:(path:String) -> Void, ?onFailure:(path:String) -> Void):Bool {
		final id = nextId++;
		pending.set(id, {onSuccess: onSuccess, onFailure: onFailure});
		final ok = Raw.wgr_asset_add_task(task, cpp.Callable.fromStaticFunction(successTrampoline),
			cpp.Callable.fromStaticFunction(failureTrampoline), Native.toUser(id)) == 0;
		if (!ok)
			pending.remove(id);
		return ok;
	}

	// One callback per task, then the task is gone — so drop the closures here.
	static function finish(user:VoidStar, path:ConstCharStar, success:Bool):Void {
		final id = Native.fromUser(user);
		final entry = pending.get(id);
		if (entry == null)
			return;
		pending.remove(id);
		final cb = success ? entry.onSuccess : entry.onFailure;
		if (cb == null)
			return;
		try
			cb(path.toString())
		catch (e:haxe.Exception)
			Wgr.report('an asset callback for "${path.toString()}"', e);
	}

	static function successTrampoline(path:ConstCharStar, user:VoidStar):Void
		finish(user, path, true);

	static function failureTrampoline(path:ConstCharStar, user:VoidStar):Void
		finish(user, path, false);
	#end
}

// --------------------------------------------------------- audio / sound ----

/** A loaded sound file: reference counted, shared. **/
abstract Audio(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Audio
		return (Raw.wgr_audio_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_audio_release(this);
}

/** A playing (or playable) instance of an `Audio`, with its own state. **/
abstract Sound(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var loop(never, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sound takes its own reference to `audio`. **/
	public inline function new(audio:Audio)
		this = (Raw.wgr_sound_create(audio) : Handle);

	inline function set_loop(v:Bool):Bool {
		Raw.wgr_sound_set_loop(this, v);
		return v;
	}

	public inline function play():Bool
		return Raw.wgr_sound_play(this);

	/** Objects are private, so they're destroyed; resources are shared and released. **/
	public inline function destroy():Void
		Raw.wgr_sound_destroy(this);
}

// ---------------------------------------------------------- mesh / model ----

/** Loaded model geometry: reference counted, shared. **/
abstract Mesh(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Mesh
		return (Raw.wgr_mesh_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_mesh_release(this);
}

/** A placed instance of a `Mesh`, with its own transform, tint and animation. **/
abstract Model(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var animation(never, set):Int;
	public var animationSpeed(never, set):Float;
	public var animationLoop(never, set):Bool;
	public var tint(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The model takes its own reference to `mesh`. **/
	public inline function new(mesh:Mesh)
		this = (Raw.wgr_model_create(mesh) : Handle);

	inline function set_animation(v:Int):Int {
		Raw.wgr_model_set_animation(this, v);
		return v;
	}

	inline function set_animationSpeed(v:Float):Float {
		Raw.wgr_model_set_animation_speed(this, v);
		return v;
	}

	inline function set_animationLoop(v:Bool):Bool {
		Raw.wgr_model_set_animation_loop(this, v);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_model_set_tint(this, v);
		return v;
	}

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_model_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	/** Advance the current animation by `dt` seconds. **/
	public inline function animate(dt:Float):Bool
		return Raw.wgr_model_animate(this, dt);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_model_destroy(this);
}

/** The defaults `setTransform` fills in for an omitted rotation or scale. **/
@:noCompletion
class Transform {
	public static final NO_ROTATION = new Vec3(0, 0, 0);
	public static final UNIT_SCALE = new Vec3(1, 1, 1);
}

// ----------------------------------------------------- texture / sprite3d ---

/** A loaded image: reference counted, shared. **/
abstract Texture(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Texture
		return (Raw.wgr_texture_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_texture_release(this);
}

/** A `Texture` placed in the 3D scene, with its own transform, tint and facing. **/
abstract Sprite3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var facing(never, set):SpriteFacing;
	public var tint(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sprite takes its own reference to `texture`. **/
	public inline function new(texture:Texture)
		this = (Raw.wgr_sprite3d_create(texture) : Handle);

	inline function set_facing(v:SpriteFacing):SpriteFacing {
		Raw.wgr_sprite3d_set_facing(this, v);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_sprite3d_set_tint(this, v);
		return v;
	}

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_sprite3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_sprite3d_destroy(this);
}

// ----------------------------------------------------------- fonts / text ---

/** A loaded typeface. Fonts are sized per draw call, so one handle serves any size. **/
abstract Font(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Font
		return (Raw.wgr_font_create(path) : Handle);

	public inline function draw(text:String, x:Float, y:Float, size:Float, color:Color):Void
		Raw.wgr_text_draw_ex(this, text, x, y, size, color);

	public inline function measure(text:String, size:Float):Vec2
		return Text.toVec2(Raw.wgr_text_measure_ex(this, text, size));

	/** The frame rate, in this font; a none font draws in the built-in one. **/
	public inline function drawFps(x:Float, y:Float, size:Float, color:Color):Void
		Raw.wgr_text_draw_fps_ex(this, x, y, size, color);

	/** Once at a 3D point, facing the camera; `size` is line height in world units. **/
	public inline function draw3D(text:String, position:Vec3, size:Float, color:Color):Void
		Raw.wgr_text_draw_3d(this, text, position.x, position.y, position.z, size, color);

	/** Drop this reference; the font goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_font_release(this);
}

/** Text in wgrender's built-in font. For a TTF, use `Font`. **/
class Text {
	public static inline function draw(text:String, x:Int, y:Int, size:Int, color:Color):Void
		Raw.wgr_text_draw(text, x, y, size, color);

	/** Width in the built-in font. **/
	public static inline function measure(text:String, size:Int):Int
		return Raw.wgr_text_measure(text, size);

	public static inline function drawFps(x:Int, y:Int):Void
		Raw.wgr_text_draw_fps(x, y);

	/**
		What `Text.draw`/`measure` use, and what a none font means everywhere else
		(`Font.draw`, `Text2D`, `Text3D`). None goes back to wgrender's built-in font,
		JetBrains Mono, printable ASCII only. The default font holds its own reference.
	**/
	public static var defaultFont(get, set):Font;

	static inline function get_defaultFont():Font
		return (Raw.wgr_text_get_default_font() : Handle);

	static inline function set_defaultFont(v:Font):Font {
		Raw.wgr_text_set_default_font(v);
		return v;
	}

	@:allow(wgr)
	static inline function toVec2(v:#if cpp CVec2 #else Vec2 #end):Vec2
		#if cpp return new Vec2(v.x, v.y); #else return v; #end
}

/**
	A placed string with retained state: set its text, place and colour once and
	wgrender keeps them, instead of your code re-passing them every frame. Add it to a
	`Scene` and `Scene.draw` draws it; `draw` draws it on its own.

	It retains the state, not the geometry — the text is still shaped on every draw,
	at the same per-frame cost as `Font.draw`. What it saves is re-sending the string.

	A none `font` uses `Text.defaultFont` until one is attached, so you can create,
	place and show text before its font asset has loaded. It holds its own reference
	to the font.
**/
abstract Text2D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var font(never, set):Font;
	public var text(never, set):String;
	public var position(never, set):Vec2;

	/** Pixel height of one line. **/
	public var size(never, set):Float;

	public var color(never, set):Color;

	/** Wrap to this many logical pixels, between words; 0 is off (the default). **/
	public var maxWidth(never, set):Float;

	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: pickable. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** `Handle.NONE` for the default font; attach a real one later with `font`. **/
	public inline function new(font:Font)
		this = (Raw.wgr_text2d_create(font) : Handle);

	inline function set_font(v:Font):Font {
		Raw.wgr_text2d_set_font(this, v);
		return v;
	}

	inline function set_text(v:String):String {
		Raw.wgr_text2d_set_text(this, v); // wgrender copies it
		return v;
	}

	inline function set_position(v:Vec2):Vec2 {
		Raw.wgr_text2d_set_position(this, v.x, v.y);
		return v;
	}

	inline function set_size(v:Float):Float {
		Raw.wgr_text2d_set_size(this, v);
		return v;
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_text2d_set_color(this, v);
		return v;
	}

	inline function set_maxWidth(v:Float):Float {
		Raw.wgr_text2d_set_max_width(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_text2d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_text2d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_text2d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_text2d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_text2d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_text2d_set_enabled(this, v);
		return v;
	}

	/** Default: the position is the block's top-left corner. **/
	public inline function setAlign(horizontal:AlignX, vertical:AlignY):Bool
		return Raw.wgr_text2d_set_align(this, horizontal, vertical);

	/** The laid-out text at its current size: widest line, and the lines' total height. **/
	public inline function measure():Vec2
		return new Vec2(Raw.wgr_text2d_measure_width(this), Raw.wgr_text2d_measure_height(this));

	/** Draw it now; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_text2d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_text2d_destroy(this);
}

/**
	The same, placed in the 3D world instead of on the screen: `size` is in world
	units, it has a transform and a `facing`, and it is depth-tested and sorted with
	the scene's other transparent parts. Note there is no scale — the size is the
	scale.
**/
abstract Text3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var font(never, set):Font;
	public var text(never, set):String;

	/** Line height in world units (default 1), descender to ascender. **/
	public var size(never, set):Float;

	public var color(never, set):Color;

	/** Wrap to this many world units, between words; 0 is off (the default). **/
	public var maxWidth(never, set):Float;

	public var facing(never, set):SpriteFacing;
	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: pickable. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** `Handle.NONE` for the default font; attach a real one later with `font`. **/
	public inline function new(font:Font)
		this = (Raw.wgr_text3d_create(font) : Handle);

	inline function set_font(v:Font):Font {
		Raw.wgr_text3d_set_font(this, v);
		return v;
	}

	inline function set_text(v:String):String {
		Raw.wgr_text3d_set_text(this, v); // wgrender copies it
		return v;
	}

	inline function set_size(v:Float):Float {
		Raw.wgr_text3d_set_size(this, v);
		return v;
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_text3d_set_color(this, v);
		return v;
	}

	inline function set_maxWidth(v:Float):Float {
		Raw.wgr_text3d_set_max_width(this, v);
		return v;
	}

	inline function set_facing(v:SpriteFacing):SpriteFacing {
		Raw.wgr_text3d_set_facing(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_text3d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_text3d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_text3d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_text3d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_text3d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_text3d_set_enabled(this, v);
		return v;
	}

	/** Default: centred both ways, so the position is the middle of the block. **/
	public inline function setAlign(horizontal:AlignX, vertical:AlignY):Bool
		return Raw.wgr_text3d_set_align(this, horizontal, vertical);

	/** `rotation` in radians. No scale: `size` is the scale. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		return Raw.wgr_text3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z);
	}

	/** World-space width and height of the current text; (0, 0) until the font loads. **/
	public inline function measure():Vec2
		return Text.toVec2(Raw.wgr_text3d_get_size(this));

	/** Draw it now, inside 3D mode; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_text3d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_text3d_destroy(this);
}

// -------------------------------------------------- camera / light / scene --

abstract Camera3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** Perspective's default fov is pi/4 (45 degrees). **/
	public inline function new(projection:Projection = Perspective)
		this = (Raw.wgr_camera3d_create(projection) : Handle);

	public inline function setView(position:Vec3, target:Vec3, ?up:Vec3):Bool {
		final u = up != null ? up : Camera3DDefaults.UP;
		return Raw.wgr_camera3d_set_view(this, position.x, position.y, position.z, target.x, target.y, target.z, u.x,
			u.y, u.z);
	}

	/** Scenes using it fall back to the active camera. **/
	public inline function destroy():Void
		Raw.wgr_camera3d_destroy(this);
}

@:noCompletion
class Camera3DDefaults {
	public static final UP = new Vec3(0, 1, 0);
}

abstract Light(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var direction(never, set):Vec3;
	public var intensity(never, set):Float;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new(kind:LightKind)
		this = (Raw.wgr_light_create(kind) : Handle);

	inline function set_direction(v:Vec3):Vec3 {
		Raw.wgr_light_set_direction(this, v.x, v.y, v.z);
		return v;
	}

	inline function set_intensity(v:Float):Float {
		Raw.wgr_light_set_intensity(this, v);
		return v;
	}

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_light_destroy(this);
}

/** What `Scene.add` takes: a `Model`, `Sprite3D`, `Text2D`, `Text3D` or `Light`. **/
abstract SceneMember(Handle) to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	@:from static inline function ofModel(v:Model):SceneMember
		return cast v;

	@:from static inline function ofSprite3D(v:Sprite3D):SceneMember
		return cast v;

	@:from static inline function ofLight(v:Light):SceneMember
		return cast v;

	@:from static inline function ofText2D(v:Text2D):SceneMember
		return cast v;

	@:from static inline function ofText3D(v:Text3D):SceneMember
		return cast v;
}

abstract Scene(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var activeCamera(never, set):Camera3D;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new()
		this = (Raw.wgr_scene_create() : Handle);

	inline function set_activeCamera(v:Camera3D):Camera3D {
		Raw.wgr_scene_set_active_camera(this, v);
		return v;
	}

	public inline function add(member:SceneMember, layer:Int = 0):Bool
		return Raw.wgr_scene_add(this, member, layer);

	public inline function setAmbient(color:Color, intensity:Float):Bool
		return Raw.wgr_scene_set_ambient(this, color, intensity);

	public inline function draw():Void
		Raw.wgr_scene_draw(this);

	/**
		What is under (`x`, `y`) in screen space. A none `camera` uses the scene's
		active one. Compare the result with typed handles: `pick.handle == model`.
	**/
	public inline function pick(x:Float, y:Float, ?camera:Camera3D):PickResult
		return Scene.toPickResult(Raw.wgr_scene_pick(this, camera == null ? 0 : (camera : Handle), x, y));

	@:allow(wgr)
	static inline function toVec3(v:#if cpp CVec3 #else Vec3 #end):Vec3
		#if cpp return new Vec3(v.x, v.y, v.z); #else return v; #end

	/** A scene doesn't own its members; destroying it leaves them alone. **/
	public inline function destroy():Void
		Raw.wgr_scene_destroy(this);

	@:allow(wgr)
	static function toPickResult(r:#if cpp CPickResult #else PickResult #end):PickResult {
		#if cpp
		return new PickResult(r.hit, (r.handle : Int), r.distance, toVec3(r.point_local), toVec3(r.point_world),
			toVec3(r.normal_local), toVec3(r.normal_world));
		#else
		return r;
		#end
	}
}

// ----------------------------------------------------------------- frame ----

class Render {
	public static inline function begin():Void
		Raw.wgr_render_begin();

	public static inline function end():Void
		Raw.wgr_render_end();

	public static inline function clearBackground(color:Color):Void
		Raw.wgr_render_clear_background(color);
}

class Window {
	public static inline function getScreenSize():Vec2
		return Text.toVec2(Raw.wgr_window_get_screen_size());
}

#if cpp
/** Every key at once, plus this frame's pressed keys and characters. **/
abstract KeyboardState(CKeyboardState) from CKeyboardState {
	@:arrayAccess public inline function get(key:Key):ButtonState
		return this.keys[key];

	/** Went down this frame. **/
	public inline function isPressed(key:Key):Bool
		return get(key) == Pressed;

	/** Held, including the frame it went down. **/
	public inline function isDown(key:Key):Bool
		return get(key) == Pressed || get(key) == Down;

	/** Went up this frame. **/
	public inline function isReleased(key:Key):Bool
		return get(key) == Released;
}

#end

class Input {
	public static function getMouseState():MouseState {
		#if cpp
		final m = Raw.wgr_input_get_mouse_state();
		return new MouseState(m.x, m.y, m.wheel, m.wheel_x, m.left, m.right, m.middle,
			[m.buttons[0], m.buttons[1], m.buttons[2]], m.dx, m.dy);
		#else
		return Raw.wgr_input_get_mouse_state();
		#end
	}

	public static inline function getKey(key:Key):ButtonState
		return Raw.wgr_input_get_key(key);

	/** Went down this frame. **/
	public static inline function isKeyPressed(key:Key):Bool
		return getKey(key) == Pressed;

	/** Held, including the frame it went down. **/
	public static inline function isKeyDown(key:Key):Bool
		return getKey(key) == Pressed || getKey(key) == Down;

	/** Went up this frame. **/
	public static inline function isKeyReleased(key:Key):Bool
		return getKey(key) == Released;

	#if cpp
	/** For one key, `getKey` / `isKeyPressed` are simpler. **/
	public static inline function getKeyboardState():KeyboardState
		return Raw.wgr_input_get_keyboard_state();
	#end
}
