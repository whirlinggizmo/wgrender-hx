package wgr;

// wgr_color.h

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
