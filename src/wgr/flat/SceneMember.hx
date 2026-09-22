package wgr.flat;

// wgr_scene.h — what Scene.add takes, flat

/**
	The flat form of `wgr.SceneMember`. Same rule as the sharp API: conversions go one
	way only, so any handle at all cannot pass for a member.
**/
abstract SceneMember(Handle) to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	@:allow(wgr.flat)
	static inline function of(v:Handle):SceneMember
		return cast v;

	@:from static inline function ofModel(v:Model):SceneMember
		return cast v;

	@:from static inline function ofLight(v:Light):SceneMember
		return cast v;

	@:from static inline function ofShape3D(v:Shape3D):SceneMember
		return cast v;
}
