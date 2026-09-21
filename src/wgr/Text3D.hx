package wgr;

// wgr_text3d.h — retained text in the world

/**
	The same, placed in the 3D world instead of on the screen: `size` is in world
	units, it has a transform and a `facing`, and it is depth-tested and sorted with
	the scene's other transparent parts. Note there is no scale — the size is the
	scale.
**/
abstract Text3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var font(never, set):Font;
	public var text(never, set):String;

	/** Line height in world units (default 1), descender to ascender. **/
	public var size(never, set):Float;

	public var color(never, set):Color;

	/** Wrap to this many world units, between words; 0 is off (the default). **/
	public var maxWidth(never, set):Float;

	public var facing(never, set):SpriteFacing;
	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: pickable. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** `Handle.NONE` for the default font; attach a real one later with `font`. **/
	public inline function new(font:Font)
		this = (Raw.wgr_text3d_create(font) : Handle);

	inline function set_font(v:Font):Font {
		Raw.wgr_text3d_set_font(this, v);
		return v;
	}

	inline function set_text(v:String):String {
		Raw.wgr_text3d_set_text(this, v); // wgrender copies it
		return v;
	}

	inline function set_size(v:Float):Float {
		Raw.wgr_text3d_set_size(this, v);
		return v;
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_text3d_set_color(this, v);
		return v;
	}

	inline function set_maxWidth(v:Float):Float {
		Raw.wgr_text3d_set_max_width(this, v);
		return v;
	}

	inline function set_facing(v:SpriteFacing):SpriteFacing {
		Raw.wgr_text3d_set_facing(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_text3d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_text3d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_text3d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_text3d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_text3d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_text3d_set_enabled(this, v);
		return v;
	}

	/** Default: centred both ways, so the position is the middle of the block. **/
	public inline function setAlign(horizontal:AlignX, vertical:AlignY):Bool
		return Raw.wgr_text3d_set_align(this, horizontal, vertical);

	/** `rotation` in radians. No scale: `size` is the scale. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		return Raw.wgr_text3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z);
	}

	/** World-space width and height of the current text; (0, 0) until the font loads. **/
	public inline function measure():Vec2
		return Vec2.of(Raw.wgr_text3d_get_size(this));

	/** Draw it now, inside 3D mode; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_text3d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_text3d_destroy(this);
}
