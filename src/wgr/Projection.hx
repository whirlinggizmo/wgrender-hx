package wgr;

// wgr_camera3d.h

enum abstract Projection(Int) to Int {
	var Perspective = 0;
	var Orthographic = 1;

	/** C++ needs the cast: the header says `wgr_camera3d_projection_t`, not `int`. **/
	@:to inline function toRaw():CProjection
		return untyped __cpp__("(wgr_camera3d_projection_t)({0})", this);
}
