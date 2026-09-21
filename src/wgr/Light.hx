package wgr;

// wgr_light.h

abstract Light(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var direction(never, set):Vec3;
	public var intensity(never, set):Float;

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

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_light_destroy(this);
}
