package wgr;

// wgr_render.h — the frame

class Render {
	public static inline function begin():Void
		Raw.wgr_render_begin();

	public static inline function end():Void
		Raw.wgr_render_end();

	public static inline function clearBackground(color:Color):Void
		Raw.wgr_render_clear_background(color);
}
