package wgr;

// wgr_sprite2d.h — a Texture placed on the screen

/**
	A textured quad in screen space, referencing a shared `Texture`.

	Coordinates are logical pixels with a top-left origin and y down, so on a
	high-DPI display one logical pixel spans several real ones. Angles are radians,
	and positive turns clockwise on screen because y points down.

	Add it to a `Scene` — which draws all 3D first, then its 2D members by layer and
	insertion order, and picks 2D members first, topmost first — or `draw` it
	directly, in call order. A sprite with no texture, or one still loading, is
	neither drawn nor picked.
**/
abstract Sprite2D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	/** Where the pivot goes, in logical pixels. **/
	public var position(never, set):Vec2;

	/** Radians around the pivot; positive turns clockwise, since y points down. **/
	public var rotation(never, set):Float;

	/** Multiplies the size. A negative component flips it on that axis. **/
	public var scale(never, set):Vec2;

	public var tint(never, set):Color;

	/** Drawn at all. **/
	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: it can. **/
	public var pickable(get, set):Bool;

	/**
		Enabled (the default): a hit reacts — hover, press and click in an interactive
		scene. Disabled: still drawn and still picked, and it still blocks the pointer,
		but it doesn't react.
	**/
	public var enabled(get, set):Bool;

	/** How it uses its texture's alpha. Set it with `setAlphaMode`. **/
	public var alphaMode(get, never):AlphaMode;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** `texture` may be none and set later with `setTexture`. **/
	public inline function new(texture:Texture)
		this = (Raw.wgr_sprite2d_create(texture) : Handle);

	inline function set_position(v:Vec2):Vec2 {
		Raw.wgr_sprite2d_set_position(this, v.x, v.y);
		return v;
	}

	inline function set_rotation(v:Float):Float {
		Raw.wgr_sprite2d_set_rotation(this, v);
		return v;
	}

	inline function set_scale(v:Vec2):Vec2 {
		Raw.wgr_sprite2d_set_scale(this, v.x, v.y);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_sprite2d_set_tint(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_sprite2d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_sprite2d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_sprite2d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_sprite2d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_sprite2d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_sprite2d_set_enabled(this, v);
		return v;
	}

	inline function get_alphaMode():AlphaMode
		return AlphaMode.of(Raw.wgr_sprite2d_get_alpha_mode(this));

	/** The sprite takes its own reference; a none texture leaves it nothing to draw. **/
	public inline function setTexture(texture:Texture):Bool
		return Raw.wgr_sprite2d_set_texture(this, texture);

	/**
		The region of the texture to show, in texture pixels — for sprite sheets and
		atlases. A width or height at or below 0 goes back to the whole texture.
	**/
	public inline function setSource(x:Float, y:Float, width:Float, height:Float):Bool
		return Raw.wgr_sprite2d_set_source(this, x, y, width, height);

	/**
		Its on-screen size in logical pixels, before scale. A width or height at or
		below 0 means the source region's own size, which is the default.
	**/
	public inline function setSize(width:Float, height:Float):Bool
		return Raw.wgr_sprite2d_set_size(this, width, height);

	/**
		The point `position` refers to and `rotation` turns around, **as a fraction of
		the sprite** rather than in pixels: (0, 0) is its top-left and (1, 1) its
		bottom-right. Default (0.5, 0.5), the center.
	**/
	public inline function setPivot(x:Float, y:Float):Bool
		return Raw.wgr_sprite2d_set_pivot(this, x, y);

	/**
		Nine-slice: borders in source pixels that keep their size when the sprite is
		drawn at another size — panels, buttons, frames. The corners stay put, the edges
		stretch along one axis and the middle along both. A 0 border leaves that axis
		unsliced and all four at 0 turns it off, which is the default. Set the on-screen
		size with `setSize`. Picks hit the whole rectangle: the alpha test is skipped
		while a sprite is sliced.
	**/
	public inline function setNineSlice(left:Float, top:Float, right:Float, bottom:Float):Bool
		return Raw.wgr_sprite2d_set_nine_slice(this, left, top, right, bottom);

	/**
		How it uses its texture's alpha; `Blend` by default. Blended, `Add` for glows,
		`Opaque` to ignore alpha, or `Mask` to cut out texels below `cutoff` (0..1). 2D
		sprites always draw in order — the mode only changes how they are blended.
	**/
	public inline function setAlphaMode(mode:AlphaMode, cutoff:Float = 0):Bool
		return Raw.wgr_sprite2d_set_alpha_mode(this, mode, cutoff);

	/**
		Draw it with a material instead of wgrender's sprite shader; a none material
		goes back to that. A custom material's shader draws the sprite in screen pixels
		— `wgr_world_pos` is the pixel, and the scene's lights don't reach 2D. On a
		nine-sliced sprite, `wgr_uv1` spans each slice.
	**/
	public inline function setMaterial(material:Material):Bool
		return Raw.wgr_sprite2d_set_material(this, material);

	/** What it draws with, borrowed; none when it's on the built-in sprite shader. **/
	public inline function getMaterial():Material
		return (Raw.wgr_sprite2d_get_material(this) : Handle);

	/** Let picks pass through texels whose alpha is below `threshold` (0..1). **/
	public inline function setPickAlphaTest(enable:Bool, threshold:Float = 0.5):Bool
		return Raw.wgr_sprite2d_set_pick_alpha_test(this, enable, threshold);

	/** Draw it once, now, outside any scene, in call order. **/
	public inline function draw():Void
		Raw.wgr_sprite2d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_sprite2d_destroy(this);
}
