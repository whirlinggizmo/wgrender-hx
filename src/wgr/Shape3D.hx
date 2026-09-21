package wgr;

// wgr_shape3d.h — immediate primitives, drawn between Render.beginMode3D/endMode3D

class Shape3D {
	/** A ground grid of `slices` squares each way, `spacing` world units apart. **/
	public static inline function drawGrid(slices:Int, spacing:Float, color:Color):Void
		Raw.wgr_shape3d_draw_grid(slices, spacing, color);

	public static inline function drawLine(from:Vec3, to:Vec3, color:Color):Void
		Raw.wgr_shape3d_draw_line(from.x, from.y, from.z, to.x, to.y, to.z, color);

	public static inline function drawCube(center:Vec3, size:Vec3, color:Color):Void
		Raw.wgr_shape3d_draw_cube(center.x, center.y, center.z, size.x, size.y, size.z, color);

	public static inline function drawCubeWires(center:Vec3, size:Vec3, color:Color):Void
		Raw.wgr_shape3d_draw_cube_wires(center.x, center.y, center.z, size.x, size.y, size.z, color);

	public static inline function drawSphere(center:Vec3, radius:Float, color:Color):Void
		Raw.wgr_shape3d_draw_sphere(center.x, center.y, center.z, radius, color);

	/** Filled, facing +Z before `rotation` (radians) turns it. **/
	public static inline function drawRectangle(center:Vec3, width:Float, height:Float, color:Color,
			?rotation:Vec3):Void {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		Raw.wgr_shape3d_draw_rectangle(center.x, center.y, center.z, width, height, r.x, r.y, r.z, color);
	}

	/** An outline, facing +Z before `rotation` (radians) turns it. **/
	public static inline function drawCircle(center:Vec3, radius:Float, color:Color, ?rotation:Vec3):Void {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		Raw.wgr_shape3d_draw_circle(center.x, center.y, center.z, radius, r.x, r.y, r.z, color);
	}
}
