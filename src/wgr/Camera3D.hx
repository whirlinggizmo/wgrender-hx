package wgr;

// wgr_camera3d.h

abstract Camera3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** Perspective's default fov is pi/4 (45 degrees). **/
	public inline function new(projection:Projection = Perspective)
		this = (Raw.wgr_camera3d_create(projection) : Handle);

	public inline function setView(position:Vec3, target:Vec3, ?up:Vec3):Bool {
		final u = up != null ? up : Camera3DDefaults.UP;
		return Raw.wgr_camera3d_set_view(this, position.x, position.y, position.z, target.x, target.y, target.z, u.x,
			u.y, u.z);
	}

	/** Scenes using it fall back to the active camera. **/
	public inline function destroy():Void
		Raw.wgr_camera3d_destroy(this);
}

@:noCompletion
class Camera3DDefaults {
	public static final UP = new Vec3(0, 1, 0);
}
