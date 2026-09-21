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

	public static inline function rgba(r:Int, g:Int, b:Int, a:Int):Color
		return Raw.wgr_color_rgba(r, g, b, a);

	/** wgrender's C `wgr_color_t`. **/
	@:to inline function toRaw():WgrColor
		return this;
}
