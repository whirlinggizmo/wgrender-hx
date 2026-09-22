package wgr.flat;

// wgr_light.h, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Light`. **/
abstract Light(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create(kind:LightKind):Light
		return (Raw.wgr_light_create(kind) : Handle);

	public static inline function destroy(light:Light):Void
		Raw.wgr_light_destroy(light);

	public static inline function getKind(light:Light):LightKind
		return LightKind.of(Raw.wgr_light_get_type(light));

	public static inline function setColor(light:Light, color:Color):Bool
		return Raw.wgr_light_set_color(light, color);

	public static inline function getColor(light:Light):Color
		return Raw.wgr_light_get_color(light);

	public static inline function setIntensity(light:Light, intensity:Float):Bool
		return Raw.wgr_light_set_intensity(light, intensity);

	public static inline function getIntensity(light:Light):Float
		return Raw.wgr_light_get_intensity(light);

	/** Directional and spot only. **/
	public static inline function setDirection(light:Light, direction:Vec3):Bool
		return Raw.wgr_light_set_direction(light, direction.x, direction.y, direction.z);

	/** Point and spot only. **/
	public static inline function setPosition(light:Light, position:Vec3):Bool
		return Raw.wgr_light_set_position(light, position.x, position.y, position.z);

	/** How far it reaches. Point and spot only. **/
	public static inline function setRange(light:Light, range:Float):Bool
		return Raw.wgr_light_set_range(light, range);

	public static inline function setEnabled(light:Light, value:Bool):Bool
		return Raw.wgr_light_set_enabled(light, value);

	public static inline function isEnabled(light:Light):Bool
		return Raw.wgr_light_is_enabled(light);

	public static inline function setCastsShadows(light:Light, value:Bool):Bool
		return Raw.wgr_light_set_casts_shadows(light, value);

	public static inline function castsShadows(light:Light):Bool
		return Raw.wgr_light_get_casts_shadows(light);
}
