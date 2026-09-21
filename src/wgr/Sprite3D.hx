package wgr;

// wgr_sprite3d.h — a Texture placed in the 3D scene

/** A `Texture` placed in the 3D scene, with its own transform, tint and facing. **/
abstract Sprite3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var facing(never, set):SpriteFacing;
	public var tint(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sprite takes its own reference to `texture`. **/
	public inline function new(texture:Texture)
		this = (Raw.wgr_sprite3d_create(texture) : Handle);

	inline function set_facing(v:SpriteFacing):SpriteFacing {
		Raw.wgr_sprite3d_set_facing(this, v);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_sprite3d_set_tint(this, v);
		return v;
	}

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_sprite3d_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_sprite3d_destroy(this);
}
