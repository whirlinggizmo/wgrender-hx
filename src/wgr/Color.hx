package wgr;

// wgr_color.h

/** A packed 0xRRGGBBAA color, by value. **/
abstract Color(Int) from Int to Int {
	public static inline var WHITE:Color = cast 0xFFFFFFFF;
	public static inline var BLACK:Color = cast 0x000000FF;
	public static inline var BLUE:Color = cast 0x0079F1FF;
	public static inline var RAYWHITE:Color = cast 0xF5F5F5FF;
	public static inline var LIGHTGRAY:Color = cast 0xC8C8C8FF;
	public static inline var DARKGRAY:Color = cast 0x505050FF;
	public static inline var RED:Color = cast 0xE62937FF;
	public static inline var GOLD:Color = cast 0xFFCB00FF;
	public static inline var LIME:Color = cast 0x009E2FFF;
	public static inline var SKYBLUE:Color = cast 0x66BFFFFF;
	public static inline var VIOLET:Color = cast 0x873CBEFF;

	/** Red, 0..255. **/
	public var red(get, never):Int;

	/** Green, 0..255. **/
	public var green(get, never):Int;

	/** Blue, 0..255. **/
	public var blue(get, never):Int;

	/** Alpha, 0..255. Note that 0 is transparent, not "unset". **/
	public var alpha(get, never):Int;

	/** Components 0..255, clamped. They saturate rather than wrap into the next channel. **/
	public static inline function rgba(r:Int, g:Int, b:Int, a:Int = 255):Color
		return Raw.wgr_color_rgba(r, g, b, a);

	/** The same from 0..1, rounded to the nearest 8-bit step. **/
	public static inline function rgbaf(r:Float, g:Float, b:Float, a:Float = 1):Color
		return Raw.wgr_color_rgbaf(r, g, b, a);

	inline function get_red():Int
		return Raw.wgr_color_get_red(this);

	inline function get_green():Int
		return Raw.wgr_color_get_green(this);

	inline function get_blue():Int
		return Raw.wgr_color_get_blue(this);

	inline function get_alpha():Int
		return Raw.wgr_color_get_alpha(this);

	/** The same color at another alpha, 0..255. **/
	public inline function withAlpha(a:Int):Color
		return Raw.wgr_color_with_alpha(this, a);

	/** A straight-line blend, component by component; `t` is clamped to 0..1. **/
	public inline function lerp(to:Color, t:Float):Color
		return Raw.wgr_color_lerp(this, to, t);

	/** wgrender's C `wgr_color_t`. **/
	@:to inline function toRaw():WgrColor
		return this;
}
