package wgr;

// wgr_light.h

abstract Light(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var color(never, set):Color;
	public var intensity(never, set):Float;

	/** Point and spot. **/
	public var position(never, set):Vec3;

	/** Directional and spot; default (0, -1, 0). **/
	public var direction(never, set):Vec3;

	/** Point and spot; 0 is unlimited, the default. **/
	public var range(never, set):Float;

	/** Default: enabled. **/
	public var enabled(get, set):Bool;

	public var castsShadows(get, set):Bool;

	/** How far from the camera this light's shadows are drawn. Refused at or below 0. **/
	public var shadowDistance(never, set):Float;

	/**
		The shadow map's resolution in pixels each way, 2048 by default. Clamped to
		256..4096 and rounded down to a power of two, so 100 becomes 256 and 9000
		becomes 4096; a size below 1 is refused instead, since that is not a size.
		Bigger is sharper and slower, and costs twice the memory each step.

		wgrender has no getter for it, so what a size was clamped to can't be read back.

		The casting lights in a scene share one map and all get the largest size any of
		them asked for, so keep them the same unless you mean it.
	**/
	public var shadowMapSize(never, set):Int;

	/**
		How dark this light's shadows are: 0 none, 1 full. A value outside 0..1 is
		refused rather than clamped, unlike `shadowMapSize`, so the strength keeps
		whatever it had.
	**/
	public var shadowStrength(never, set):Float;

	public var shadowColor(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new(kind:LightKind)
		this = (Raw.wgr_light_create(kind) : Handle);

	inline function set_direction(v:Vec3):Vec3 {
		Raw.wgr_light_set_direction(this, v.x, v.y, v.z);
		return v;
	}

	inline function set_intensity(v:Float):Float {
		Raw.wgr_light_set_intensity(this, v);
		return v;
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_light_set_color(this, v);
		return v;
	}

	inline function set_position(v:Vec3):Vec3 {
		Raw.wgr_light_set_position(this, v.x, v.y, v.z);
		return v;
	}

	inline function set_range(v:Float):Float {
		Raw.wgr_light_set_range(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_light_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_light_set_enabled(this, v);
		return v;
	}

	inline function get_castsShadows():Bool
		return Raw.wgr_light_get_casts_shadows(this);

	inline function set_castsShadows(v:Bool):Bool {
		Raw.wgr_light_set_casts_shadows(this, v);
		return v;
	}

	inline function set_shadowDistance(v:Float):Float {
		Raw.wgr_light_set_shadow_distance(this, v);
		return v;
	}

	inline function set_shadowMapSize(v:Int):Int {
		Raw.wgr_light_set_shadow_map_size(this, v);
		return v;
	}

	inline function set_shadowStrength(v:Float):Float {
		Raw.wgr_light_set_shadow_strength(this, v);
		return v;
	}

	inline function set_shadowColor(v:Color):Color {
		Raw.wgr_light_set_shadow_color(this, v);
		return v;
	}

	/** Full brightness inside `inner`, fading to nothing at `outer` (radians). **/
	public inline function setSpotCone(inner:Float, outer:Float):Bool
		return Raw.wgr_light_set_spot_cone(this, inner, outer);

	/** Nudges the depth test off the surface: a constant, plus a slope-scaled part. **/
	public inline function setShadowBias(constant:Float, slope:Float):Bool
		return Raw.wgr_light_set_shadow_bias(this, constant, slope);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_light_destroy(this);
}
