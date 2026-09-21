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

	/** How far from the camera this light's shadows are drawn. **/
	public var shadowDistance(never, set):Float;

	/** The shadow map's resolution in texels. **/
	public var shadowMapSize(never, set):Int;

	/** 0..1. **/
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
