package wgr;

// wgr_shape2d.h — immediate primitives on the screen, drawn in call order

/**
	Screen-space primitives, in logical pixels with a top-left origin. These draw where
	they are called; for something the scene keeps and picks, wgrender also has a
	shape2d *object*, which this does not wrap yet.
**/
class Shape2D {
	public static inline function drawRectangle(x:Float, y:Float, width:Float, height:Float, color:Color):Void
		Raw.wgr_shape2d_draw_rectangle(x, y, width, height, color);

	public static inline function drawRectangleLines(x:Float, y:Float, width:Float, height:Float, color:Color):Void
		Raw.wgr_shape2d_draw_rectangle_lines(x, y, width, height, color);

	public static inline function drawLine(from:Vec2, to:Vec2, color:Color):Void
		Raw.wgr_shape2d_draw_line(from.x, from.y, to.x, to.y, color);

	public static inline function drawCircle(center:Vec2, radius:Float, color:Color):Void
		Raw.wgr_shape2d_draw_circle(center.x, center.y, radius, color);

	public static inline function drawCircleLines(center:Vec2, radius:Float, color:Color):Void
		Raw.wgr_shape2d_draw_circle_lines(center.x, center.y, radius, color);

	public static inline function drawTriangle(a:Vec2, b:Vec2, c:Vec2, color:Color):Void
		Raw.wgr_shape2d_draw_triangle(a.x, a.y, b.x, b.y, c.x, c.y, color);

	/** Every corner rounded the same. **/
	public static inline function drawRoundedRectangle(x:Float, y:Float, width:Float, height:Float, radius:Float,
			color:Color):Void
		Raw.wgr_shape2d_draw_rounded_rectangle(x, y, width, height, radius, radius, radius, radius, color);

	/** Corner radii clockwise from the top left. **/
	public static inline function drawRoundedRectangleCorners(x:Float, y:Float, width:Float, height:Float,
			topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float, color:Color):Void
		Raw.wgr_shape2d_draw_rounded_rectangle(x, y, width, height, topLeft, topRight, bottomRight, bottomLeft,
			color);

	/** An inset border: per-edge thickness, then corner radii clockwise from top left. **/
	public static inline function drawBorder(x:Float, y:Float, width:Float, height:Float, left:Float, top:Float,
			right:Float, bottom:Float, topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float,
			color:Color):Void
		Raw.wgr_shape2d_draw_border(x, y, width, height, left, top, right, bottom, topLeft, topRight, bottomRight,
			bottomLeft, color);
}
