package wgr;

// wgr_light.h

enum abstract LightKind(Int) to Int {
	var Directional = 0;
	var Point = 1;
	var Spot = 2;

	/** C++ needs the cast: the header says `wgr_light_type_t`, not `int`. **/
	@:to inline function toRaw():CLightType
		return untyped __cpp__("(wgr_light_type_t)({0})", this);
}
