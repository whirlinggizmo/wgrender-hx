package wgr;

// wgr_font.h — the typeface resource

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
