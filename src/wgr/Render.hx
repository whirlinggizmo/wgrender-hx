package wgr;

// wgr_render.h — the frame

class Render {
	public static inline function begin():Void
		Raw.wgr_render_begin();

	public static inline function end():Void
		Raw.wgr_render_end();

	public static inline function clearBackground(color:Color):Void
		Raw.wgr_render_clear_background(color);

	/** Immediate 3D primitives (`Shape3D`) draw between these, in call order. **/
	public static inline function beginMode3D():Void
		Raw.wgr_render_begin_mode_3d();

	public static inline function endMode3D():Void
		Raw.wgr_render_end_mode_3d();
}
