package wgr;

// wgr_shape2d.h — primitives on the screen, drawn now or kept in a scene

/**
	The screen-space counterpart of `Shape3D`, and the same two ways round: the statics
	draw immediately in logical pixels with a top-left origin, an instance is a scene
	object with its own transform, pivot and outline.
**/
abstract Shape2D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var color(never, set):Color;

	/** Outline thickness; 0 fills, which is the default. Rectangles and circles. **/
	public var outline(never, set):Float;

	public var visible(get, set):Bool;

	/** Whether a pick can hit it. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new()
		this = (Raw.wgr_shape2d_create() : Handle);

	// --- the form it takes; the last one set wins ---

	public inline function setRectangle(width:Float, height:Float, cornerRadius:Float = 0):Bool
		return Raw.wgr_shape2d_set_rectangle(this, width, height, cornerRadius);

	public inline function setCircle(radius:Float):Bool
		return Raw.wgr_shape2d_set_circle(this, radius);

	public inline function setLine(from:Vec2, to:Vec2, thickness:Float = 1):Bool
		return Raw.wgr_shape2d_set_line(this, from.x, from.y, to.x, to.y, thickness);

	// --- where it is, and how it looks ---

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec2, rotation:Float = 0, ?scale:Vec2):Bool {
		final s = scale != null ? scale : Shape2D.UNIT_SCALE;
		return Raw.wgr_shape2d_set_transform(this, position.x, position.y, rotation, s.x, s.y);
	}

	/**
		What the transform turns and scales about, as a **fraction of the shape's own
		size** — (0, 0) its top-left, (0.5, 0.5) its middle, (1, 1) its bottom-right.
		Not pixels: (80, 30) puts it eighty widths away. Outside 0..1 is allowed.

		The default is the shape's own origin — a rectangle's top-left, a circle's
		centre — so nothing moves until one is set. Lines have explicit endpoints and
		ignore it.
	**/
	public inline function setPivot(pivot:Vec2):Bool
		return Raw.wgr_shape2d_set_pivot(this, pivot.x, pivot.y);

	inline function set_color(v:Color):Color {
		Raw.wgr_shape2d_set_color(this, v);
		return v;
	}

	inline function set_outline(v:Float):Float {
		Raw.wgr_shape2d_set_outline(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_shape2d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_shape2d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_shape2d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_shape2d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_shape2d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_shape2d_set_enabled(this, v);
		return v;
	}

	/** Draw it now; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_shape2d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_shape2d_destroy(this);

	// --- immediate: no handle, drawn where they are called ---

	static final UNIT_SCALE = new Vec2(1, 1);

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
