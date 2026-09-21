package wgr;

// wgr_sprite3d.h — a Texture placed in the 3D scene

/** A `Texture` placed in the 3D scene, with its own transform, tint and facing. **/
abstract Sprite3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var facing(never, set):SpriteFacing;
	public var tint(never, set):Color;

	/** Where it is, as last set. **/
	public var position(get, never):Vec3;

	/** Its own rotation in radians — what `Free` facing uses. **/
	public var rotation(get, never):Vec3;

	public var scale(get, never):Vec3;

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

	/**
		The world size of the quad before scale, square. The rectangular form is
		`setExtent`. Default 1x1; a size at or below 0 is refused.
	**/
	public var size(never, set):Float;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sprite takes its own reference to `texture`. **/
	public inline function new(texture:Texture)
		this = (Raw.wgr_sprite3d_create(texture) : Handle);

	inline function get_position():Vec3
		return Vec3.of(Raw.wgr_sprite3d_get_position(this));

	inline function get_rotation():Vec3
		return Vec3.of(Raw.wgr_sprite3d_get_rotation(this));

	inline function get_scale():Vec3
		return Vec3.of(Raw.wgr_sprite3d_get_scale(this));

	inline function get_visible():Bool
		return Raw.wgr_sprite3d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_sprite3d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_sprite3d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_sprite3d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_sprite3d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_sprite3d_set_enabled(this, v);
		return v;
	}

	inline function get_alphaMode():AlphaMode
		return AlphaMode.of(Raw.wgr_sprite3d_get_alpha_mode(this));

	inline function set_size(v:Float):Float {
		Raw.wgr_sprite3d_set_size(this, v);
		return v;
	}

	inline function set_facing(v:SpriteFacing):SpriteFacing {
		Raw.wgr_sprite3d_set_facing(this, v);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_sprite3d_set_tint(this, v);
		return v;
	}

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_sprite3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	/** The sprite takes its own reference; a none texture leaves it with nothing to draw. **/
	public inline function setTexture(texture:Texture):Bool
		return Raw.wgr_sprite3d_set_texture(this, texture);

	/** The world size of the quad before scale. A width or height at or below 0 is refused. **/
	public inline function setExtent(width:Float, height:Float):Bool
		return Raw.wgr_sprite3d_set_extent(this, width, height);

	/**
		The region of the texture to show, in texture pixels — for sprite sheets and
		atlases. A width or height at or below 0 goes back to the whole texture.
	**/
	public inline function setSource(x:Float, y:Float, width:Float, height:Float):Bool
		return Raw.wgr_sprite3d_set_source(this, x, y, width, height);

	/**
		The point of the quad that sits on the sprite's position and that it turns
		around, **as a fraction of the quad** rather than in pixels: (0, 0) is its
		top-left, (1, 1) its bottom-right, (0.5, 0.5) its center — the default. y runs
		down the texture, so (0.5, 1) puts the position at the bottom edge, which is
		what a sprite standing on the ground wants.
	**/
	public inline function setPivot(x:Float, y:Float):Bool
		return Raw.wgr_sprite3d_set_pivot(this, x, y);

	/**
		How it uses its texture's alpha; `Blend` by default. In a scene, blended sprites
		are sorted back to front with the other transparent parts. Opaque and masked
		sprites — `cutoff` 0..1 cuts out texels below it — write depth and aren't
		sorted, and additive ones are drawn after the blended parts, unsorted. Unsorted
		sprites are grouped by texture, so they draw in fewer batches.
	**/
	public inline function setAlphaMode(mode:AlphaMode, cutoff:Float = 0):Bool
		return Raw.wgr_sprite3d_set_alpha_mode(this, mode, cutoff);

	/**
		Draw it with a material instead of wgrender's sprite shader (texture x tint,
		unlit); a none material goes back to that. It keeps its texture, region, tint,
		facing and alpha mode, and holds its own reference to the material.

		A PBR material lights it like a model, from the scene's lights and environment:
		the sprite's texture is the base color, and the quad's facing is the surface
		normal, so normal maps work on billboards. Sprites in one batch share the lights
		chosen for where that batch is, so one far from the rest can miss a light near it.
	**/
	public inline function setMaterial(material:Material):Bool
		return Raw.wgr_sprite3d_set_material(this, material);

	/** What it draws with, borrowed; none when it's on the built-in sprite shader. **/
	public inline function getMaterial():Material
		return (Raw.wgr_sprite3d_get_material(this) : Handle);

	/**
		Make picking ignore texels whose alpha is below `threshold` (0..1), so the
		transparent corners of a billboard don't catch the pointer. Builds a CPU alpha
		mask from the texture's source path the first time it's needed.
	**/
	public inline function setPickAlphaTest(enable:Bool, threshold:Float = 0.5):Bool
		return Raw.wgr_sprite3d_set_pick_alpha_test(this, enable, threshold);

	/** Draw it once, now, outside any scene. Between `Render.beginMode3D` and its end. **/
	public inline function draw():Void
		Raw.wgr_sprite3d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_sprite3d_destroy(this);
}
