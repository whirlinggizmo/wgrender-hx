package wgr.flat;

// wgr_camera3d.h, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Camera3D`. **/
abstract Camera3D(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	/** Perspective's default fov is pi/4 (45 degrees). **/
	public static inline function create(projection:Projection = Perspective):Camera3D
		return (Raw.wgr_camera3d_create(projection) : Handle);

	/** Where it is and what it looks at; `up` defaults to +Y. **/
	public static inline function setView(camera:Camera3D, position:Vec3, target:Vec3, ?up:Vec3):Bool {
		final u = up != null ? up : new Vec3(0, 1, 0);
		return Raw.wgr_camera3d_set_view(camera, position.x, position.y, position.z, target.x, target.y, target.z,
			u.x, u.y, u.z);
	}

	/** Vertical field of view in radians, `0 < fov < pi`. Perspective only. **/
	public static inline function setFov(camera:Camera3D, fov:Float):Bool
		return Raw.wgr_camera3d_set_fov(camera, fov);

	public static inline function getFov(camera:Camera3D):Float
		return Raw.wgr_camera3d_get_fov(camera);
}
