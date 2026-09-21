package wgr;

// wgr_model.h — a mesh placed in the world

/** A placed instance of a `Mesh`, with its own transform, tint and animation. **/
abstract Model(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var animation(never, set):Int;

	/** Drawn at all. **/
	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: it can. **/
	public var pickable(get, set):Bool;

	/**
		Enabled (the default): a hit reacts — hover, press and click in an interactive
		scene. Disabled: still drawn and still picked, and it still blocks the pointer,
		but it doesn't react.
	**/
	public var enabled(get, set):Bool;

	/**
		Drawn into a casting light's depth map, so it shadows what's behind it. On by
		default; turn it off for a skybox or a glow.
	**/
	public var castsShadow(get, set):Bool;

	/** Shadows darken it. On by default; turn it off for something that shouldn't shade. **/
	public var receivesShadow(get, set):Bool;

	/** How many animations the mesh brought. **/
	public var animationCount(get, never):Int;

	/**
		Where the active animation is posed, in seconds — wrapped when looping, else
		clamped. glTF animations are timed in seconds, not frames. Set before the mesh
		arrives and it applies once it does.
	**/
	public var animationTime(get, set):Float;

	/** True once it has a loaded mesh to draw. **/
	public var isReady(get, never):Bool;
	public var animationSpeed(never, set):Float;
	public var animationLoop(never, set):Bool;
	public var tint(never, set):Color;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/**
		The model takes its own reference to `mesh`, which may be none: an empty model
		can be placed and animated now and given its mesh later with `setMesh`, and
		drawing and animating do nothing until then.
	**/
	public inline function new(mesh:Mesh)
		this = (Raw.wgr_model_create(mesh) : Handle);

	inline function get_visible():Bool
		return Raw.wgr_model_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_model_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_model_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_model_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_model_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_model_set_enabled(this, v);
		return v;
	}

	inline function get_castsShadow():Bool
		return Raw.wgr_model_casts_shadow(this);

	inline function set_castsShadow(v:Bool):Bool {
		Raw.wgr_model_set_casts_shadow(this, v);
		return v;
	}

	inline function get_receivesShadow():Bool
		return Raw.wgr_model_receives_shadow(this);

	inline function set_receivesShadow(v:Bool):Bool {
		Raw.wgr_model_set_receives_shadow(this, v);
		return v;
	}

	inline function get_animationCount():Int
		return Raw.wgr_model_get_animation_count(this);

	inline function get_animationTime():Float
		return Raw.wgr_model_get_animation_time(this);

	inline function set_animationTime(v:Float):Float {
		Raw.wgr_model_set_animation_time(this, v);
		return v;
	}

	inline function get_isReady():Bool
		return Raw.wgr_model_is_ready(this);

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

	/** How long an animation runs, in seconds; 0 for no such animation or no mesh yet. **/
	public inline function getAnimationDuration(animation:Int):Float
		return Raw.wgr_model_get_animation_duration(this, animation);

	/**
		Draw one of the mesh's slots (0..31) with `material` instead of the mesh's own.
		A slot of -1 sets every one, and a none material restores the mesh's. Overrides
		stay when the mesh changes. The model takes its own reference.
	**/
	public inline function setMaterial(slot:Int, material:Material):Bool
		return Raw.wgr_model_set_material(this, slot, material);

	/** What it draws `slot` with, borrowed — the override if there is one, else the mesh's. **/
	public inline function getMaterial(slot:Int):Material
		return (Raw.wgr_model_get_material(this, slot) : Handle);

	/** Draw it once, now, outside any scene. Between `Render.beginMode3D` and its end. **/
	public inline function draw():Void
		Raw.wgr_model_draw(this);

	/** Swap the geometry, keeping this model's transform, tint and materials. **/
	public inline function setMesh(mesh:Mesh):Bool
		return Raw.wgr_model_set_mesh(this, mesh);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_model_destroy(this);
}
