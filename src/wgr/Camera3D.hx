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

	/** Perspective vs orthographic; `fov` and `orthoHeight` each apply to one. **/
	public var projection(get, set):Projection;

	/** Vertical field of view in radians, `0 < fov < pi`. Perspective only. **/
	public var fov(get, set):Float;

	/** Full visible height in world units, `> 0`; width follows the window. Ortho only. **/
	public var orthoHeight(get, set):Float;

	/** The one scenes fall back to. Assign with `Camera3D.setActive`. **/
	public static var active(get, never):Camera3D;

	/** The camera wgrender makes for you, which needs no creating or destroying. **/
	public static var defaultCamera(get, never):Camera3D;

	static inline function get_active():Camera3D
		return (Raw.wgr_camera3d_get_active() : Handle);

	static inline function get_defaultCamera():Camera3D
		return (Raw.wgr_camera3d_get_default() : Handle);

	/** Make this the camera scenes without one of their own use. **/
	public inline function setActive():Bool
		return Raw.wgr_camera3d_set_active(this);

	inline function get_projection():Projection
		return Projection.of(Raw.wgr_camera3d_get_projection(this));

	inline function set_projection(v:Projection):Projection {
		Raw.wgr_camera3d_set_projection(this, v);
		return v;
	}

	inline function get_fov():Float
		return Raw.wgr_camera3d_get_fov(this);

	inline function set_fov(v:Float):Float {
		Raw.wgr_camera3d_set_fov(this, v);
		return v;
	}

	inline function get_orthoHeight():Float
		return Raw.wgr_camera3d_get_ortho_height(this);

	inline function set_orthoHeight(v:Float):Float {
		Raw.wgr_camera3d_set_ortho_height(this, v);
		return v;
	}

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
