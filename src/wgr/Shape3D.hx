package wgr;

// wgr_shape3d.h — immediate primitives, drawn between Render.beginMode3D/endMode3D

class Shape3D {
	/** A ground grid of `slices` squares each way, `spacing` world units apart. **/
	public static inline function drawGrid(slices:Int, spacing:Float, color:Color):Void
		Raw.wgr_shape3d_draw_grid(slices, spacing, color);
}
