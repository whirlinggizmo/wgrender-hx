package wgr;

// wgr_scene.h — what is drawn, and picking against it

abstract Scene(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var activeCamera(never, set):Camera3D;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new()
		this = (Raw.wgr_scene_create() : Handle);

	inline function set_activeCamera(v:Camera3D):Camera3D {
		Raw.wgr_scene_set_active_camera(this, v);
		return v;
	}

	public inline function add(member:SceneMember, layer:Int = 0):Bool
		return Raw.wgr_scene_add(this, member, layer);

	public inline function setAmbient(color:Color, intensity:Float):Bool
		return Raw.wgr_scene_set_ambient(this, color, intensity);

	public inline function draw():Void
		Raw.wgr_scene_draw(this);

	/**
		What is under (`x`, `y`) in screen space. A none `camera` uses the scene's
		active one. Compare the result with typed handles: `pick.handle == model`.
	**/
	public inline function pick(x:Float, y:Float, ?camera:Camera3D):PickResult
		return Scene.toPickResult(Raw.wgr_scene_pick(this, camera == null ? 0 : (camera : Handle), x, y));

	@:allow(wgr)
	static inline function toVec3(v:#if cpp CVec3 #else Vec3 #end):Vec3
		#if cpp return new Vec3(v.x, v.y, v.z); #else return v; #end

	/** A scene doesn't own its members; destroying it leaves them alone. **/
	public inline function destroy():Void
		Raw.wgr_scene_destroy(this);

	@:allow(wgr)
	static function toPickResult(r:#if cpp CPickResult #else PickResult #end):PickResult {
		#if cpp
		return new PickResult(r.hit, (r.handle : Int), r.distance, toVec3(r.point_local), toVec3(r.point_world),
			toVec3(r.normal_local), toVec3(r.normal_world));
		#else
		return r;
		#end
	}
}
