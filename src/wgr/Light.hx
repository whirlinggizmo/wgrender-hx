package wgr;

// wgr_light.h

abstract Light(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	/**
		Which kind it was made as. Read only — a light doesn't change kind.
	**/
	public var kind(get, never):LightKind;

	/** Default: white. **/
	public var color(get, set):Color;

	/** Default 1. Below 0 is held as 0. **/
	public var intensity(get, set):Float;

	/** Point and spot. **/
	public var position(get, set):Vec3;

	/** Directional and spot; default (0, -1, 0). Held normalized, so reading it back
		gives a unit vector rather than what was passed. **/
	public var direction(get, set):Vec3;

	/** Point and spot; 0 is unlimited, the default. Below 0 is held as 0. **/
	public var range(get, set):Float;

	/** Default: enabled. **/
	public var enabled(get, set):Bool;

	public var castsShadows(get, set):Bool;

	/** Full brightness out to here, in radians from the direction. Set with `setSpotCone`. **/
	public var spotInnerAngle(get, never):Float;

	/** Faded to nothing by here. Set with `setSpotCone`. **/
	public var spotOuterAngle(get, never):Float;

	/**
		How far this light's shadows reach in world units, 50 by default. A directional
		light covers that much of what the camera sees, so less is sharper; a spot
		covers its cone out to this or its range, whichever is nearer. Refused at or
		below 0, which wgrender logs.
	**/
	public var shadowDistance(get, set):Float;

	/**
		The shadow map's resolution in pixels each way, 2048 by default. Clamped to
		256..4096 and rounded down to a power of two, so 100 reads back 256 and 9000
		reads back 4096. A size below 1 is refused instead, since that is not a size.
		Bigger is sharper and slower, and costs twice the memory each step.

		Reading it gives the power of two the GPU actually gets, not what was asked for.

		The casting lights in a scene share one map and all get the largest size any of
		them asked for, so keep them the same unless you mean it.
	**/
	public var shadowMapSize(get, set):Int;

	/** How much of this light a shadow blocks: 0 none, 1 all of it (the default).
		Clamped to that range, so 1.5 reads back as 1. **/
	public var shadowStrength(get, set):Float;

	/**
		A colour mixed into what a shadow leaves behind; black by default, meaning
		nothing added. Scaled by how deep the shadow is, so a half-shadowed edge gets
		half of it. The stylised knob, for a blue or warm shadow without changing how
		the rest of the scene is lit.
	**/
	public var shadowColor(get, set):Color;

	/** Always-on part of the depth offset, in shadow-map texels. Set with `setShadowBias`. **/
	public var shadowBiasConstant(get, never):Float;

	/** The part scaled by how steeply the surface faces the light. Set with `setShadowBias`. **/
	public var shadowBiasSlope(get, never):Float;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	inline function get_kind():LightKind
		return LightKind.of(Raw.wgr_light_get_type(this));

	inline function get_spotInnerAngle():Float
		return Raw.wgr_light_get_spot_inner_angle(this);

	inline function get_spotOuterAngle():Float
		return Raw.wgr_light_get_spot_outer_angle(this);

	inline function get_shadowBiasConstant():Float
		return Raw.wgr_light_get_shadow_bias_constant(this);

	inline function get_shadowBiasSlope():Float
		return Raw.wgr_light_get_shadow_bias_slope(this);

	public inline function new(kind:LightKind)
		this = (Raw.wgr_light_create(kind) : Handle);

	inline function get_direction():Vec3
		return Vec3.of(Raw.wgr_light_get_direction(this));

	inline function set_direction(v:Vec3):Vec3 {
		Raw.wgr_light_set_direction(this, v.x, v.y, v.z);
		return v;
	}

	inline function get_intensity():Float
		return Raw.wgr_light_get_intensity(this);

	inline function set_intensity(v:Float):Float {
		Raw.wgr_light_set_intensity(this, v);
		return v;
	}

	inline function get_color():Color
		return Raw.wgr_light_get_color(this);

	inline function set_color(v:Color):Color {
		Raw.wgr_light_set_color(this, v);
		return v;
	}

	inline function get_position():Vec3
		return Vec3.of(Raw.wgr_light_get_position(this));

	inline function set_position(v:Vec3):Vec3 {
		Raw.wgr_light_set_position(this, v.x, v.y, v.z);
		return v;
	}

	inline function get_range():Float
		return Raw.wgr_light_get_range(this);

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

	inline function get_shadowDistance():Float
		return Raw.wgr_light_get_shadow_distance(this);

	inline function set_shadowDistance(v:Float):Float {
		Raw.wgr_light_set_shadow_distance(this, v);
		return v;
	}

	inline function get_shadowMapSize():Int
		return Raw.wgr_light_get_shadow_map_size(this);

	inline function set_shadowMapSize(v:Int):Int {
		Raw.wgr_light_set_shadow_map_size(this, v);
		return v;
	}

	inline function get_shadowStrength():Float
		return Raw.wgr_light_get_shadow_strength(this);

	inline function set_shadowStrength(v:Float):Float {
		Raw.wgr_light_set_shadow_strength(this, v);
		return v;
	}

	inline function get_shadowColor():Color
		return Raw.wgr_light_get_shadow_color(this);

	inline function set_shadowColor(v:Color):Color {
		Raw.wgr_light_set_shadow_color(this, v);
		return v;
	}

	/**
		Full brightness inside `inner`, fading to nothing at `outer`, in radians from the
		direction. Both are clamped to 0..pi/2; defaults pi/6 and pi/4. Read them back
		with `spotInnerAngle` and `spotOuterAngle`.
	**/
	public inline function setSpotCone(inner:Float, outer:Float):Bool
		return Raw.wgr_light_set_spot_cone(this, inner, outer);

	/**
		Depth offsets that keep a surface from shadowing itself, in shadow-map texels —
		what the artifact is made of, so the same numbers hold at any map size or
		distance. Defaults (1, 4). Too little gives lit surfaces a striped "shadow
		acne"; too much and the shadow creeps away from what casts it.
	**/
	public inline function setShadowBias(constant:Float, slope:Float):Bool
		return Raw.wgr_light_set_shadow_bias(this, constant, slope);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_light_destroy(this);
}
