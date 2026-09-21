package wgr;

// wgr_model.h — a mesh placed in the world

/** A placed instance of a `Mesh`, with its own transform, tint and animation. **/
abstract Model(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var animation(never, set):Int;
	public var animationSpeed(never, set):Float;
	public var animationLoop(never, set):Bool;
	public var tint(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The model takes its own reference to `mesh`. **/
	public inline function new(mesh:Mesh)
		this = (Raw.wgr_model_create(mesh) : Handle);

	inline function set_animation(v:Int):Int {
		Raw.wgr_model_set_animation(this, v);
		return v;
	}

	inline function set_animationSpeed(v:Float):Float {
		Raw.wgr_model_set_animation_speed(this, v);
		return v;
	}

	inline function set_animationLoop(v:Bool):Bool {
		Raw.wgr_model_set_animation_loop(this, v);
		return v;
	}

	inline function set_tint(v:Color):Color {
		Raw.wgr_model_set_tint(this, v);
		return v;
	}

	/** `rotation` in radians. **/
	public inline function setTransform(position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : Transform.NO_ROTATION;
		final s = scale != null ? scale : Transform.UNIT_SCALE;
		return Raw.wgr_model_set_transform(this, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	/** Advance the current animation by `dt` seconds. **/
	public inline function animate(dt:Float):Bool
		return Raw.wgr_model_animate(this, dt);

	/** The material for one of the mesh's slots; the model takes its own reference. **/
	public inline function setMaterial(slot:Int, material:Material):Bool
		return Raw.wgr_model_set_material(this, slot, material);

	/** Swap the geometry, keeping this model's transform, tint and materials. **/
	public inline function setMesh(mesh:Mesh):Bool
		return Raw.wgr_model_set_mesh(this, mesh);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_model_destroy(this);
}
