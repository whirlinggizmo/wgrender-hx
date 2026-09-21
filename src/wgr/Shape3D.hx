package wgr;

// wgr_shape3d.h — primitives in the world, drawn now or kept in a scene

/**
	A shape, either way round.

	The statics draw immediately, between `Render.beginMode3D` and `endMode3D`, in call
	order. An instance is a scene object instead: give it a form once, place it, and
	add it to a `Scene`. Picked by its surface — the inside of a circle counts, a line
	or strip has no area and is never hit.
**/
abstract Shape3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var color(never, set):Color;
	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Lines and strips have no area either way. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	/** Points in the current strip. **/
	public var pointCount(get, never):Int;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new()
		this = (Raw.wgr_shape3d_create() : Handle);

	// --- the form it takes; the last one set wins ---

	public inline function setCube(size:Vec3):Bool
		return Raw.wgr_shape3d_set_cube(this, size.x, size.y, size.z);

	public inline function setSphere(radius:Float):Bool
		return Raw.wgr_shape3d_set_sphere(this, radius);

	/** Filled. **/
	public inline function setRectangle(width:Float, height:Float):Bool
		return Raw.wgr_shape3d_set_rectangle(this, width, height);

	/** An outline. **/
	public inline function setCircle(radius:Float):Bool
		return Raw.wgr_shape3d_set_circle(this, radius);

	public inline function setLine(from:Vec3, to:Vec3):Bool
		return Raw.wgr_shape3d_set_line(this, from.x, from.y, from.z, to.x, to.y, to.z);

	/** Empty the strip; `addPoint` appends to it. Rebuild it the same way to change it. **/
	public inline function setLineStrip():Bool
		return Raw.wgr_shape3d_set_line_strip(this);

	/** Append a point to the strip, in local space. **/
	public inline function addPoint(point:Vec3):Bool
		return Raw.wgr_shape3d_add_point(this, point.x, point.y, point.z);

	inline function get_pointCount():Int
		return Raw.wgr_shape3d_get_point_count(this);

	// --- where it is, and how it looks ---

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_shape3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_shape3d_set_color(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_shape3d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_shape3d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_shape3d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_shape3d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_shape3d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_shape3d_set_enabled(this, v);
		return v;
	}

	/** Draw it now, inside 3D mode; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_shape3d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_shape3d_destroy(this);

	// --- immediate: no handle, drawn where they are called ---

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
