package wgr;

// wgr_emitter3d.h — particles in the world

/**
	A particle emitter placed in the 3D scene. Add it to a `Scene` and `Scene.draw`
	draws it; `draw` draws it on its own, inside `Render.beginMode3D`.

	It takes its own reference to the texture, so the caller can release theirs.

	Particles are unlit: the texture times the particle's color, with no material
	and no scene lighting. A lit effect wants `Sprite3D` objects with a material.
**/
abstract Emitter3D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	/** Where it is, as last set. **/
	public var position(get, never):Vec3;

	/** Whether new particles are made; the ones alive finish their lives either way. **/
	public var emitting(get, set):Bool;

	public var visible(never, set):Bool;

	/** Particles alive now. **/
	public var count(get, never):Int;

	/** Made per second while emitting. **/
	public var rate(never, set):Float;

	/** Velocity lost per second — particles that slow down rather than coast. **/
	public var drag(never, set):Float;

	/** How much of a moving emitter's own velocity a new particle is given. **/
	public var inheritVelocity(never, set):Float;

	/** Stretch along the direction of travel, in seconds of motion. **/
	public var stretch(never, set):Float;

	/** Fixes the random sequence, so a run repeats. **/
	public var seed(never, set):Int;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	inline function get_position():Vec3
		return Vec3.of(Raw.wgr_emitter3d_get_position(this));

	public inline function new(texture:Texture)
		this = (Raw.wgr_emitter3d_create(texture) : Handle);

	/** Where new particles appear; the ones alive stay where they were born. **/
	public inline function setPosition(position:Vec3):Bool
		return Raw.wgr_emitter3d_set_position(this, position.x, position.y, position.z);

	/** Move without the trail a `setPosition` sweep would leave. **/
	public inline function jump(position:Vec3):Bool
		return Raw.wgr_emitter3d_jump(this, position.x, position.y, position.z);

	/** New particles appear anywhere in this box around the position. **/
	public inline function setSpawnBox(half:Vec3):Bool
		return Raw.wgr_emitter3d_set_spawn_box(this, half.x, half.y, half.z);

	public inline function setSpawnSphere(radius:Float):Bool
		return Raw.wgr_emitter3d_set_spawn_sphere(this, radius);

	/** Initial velocity, `spread` radians of cone around it, and its variance. **/
	public inline function setVelocity(velocity:Vec3, spread:Float = 0, speedVariance:Float = 0):Bool
		return Raw.wgr_emitter3d_set_velocity(this, velocity.x, velocity.y, velocity.z, spread, speedVariance);

	public inline function setGravity(gravity:Vec3):Bool
		return Raw.wgr_emitter3d_set_gravity(this, gravity.x, gravity.y, gravity.z);

	inline function get_emitting():Bool
		return Raw.wgr_emitter3d_is_emitting(this);

	inline function set_emitting(v:Bool):Bool {
		Raw.wgr_emitter3d_set_emitting(this, v);
		return v;
	}

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_emitter3d_set_visible(this, v);
		return v;
	}

	inline function get_count():Int
		return Raw.wgr_emitter3d_get_count(this);

	/**
		The most that can be alive at once; 1024 by default. Must be 1..65536 — a value
		outside that is refused rather than clamped, and the emitter keeps the max it
		had, which is why this is a method and not a property. Setting it clears the
		particles that were alive.
	**/
	public inline function setMax(count:Int):Bool
		return Raw.wgr_emitter3d_set_max(this, count);

	inline function set_rate(v:Float):Float {
		Raw.wgr_emitter3d_set_rate(this, v);
		return v;
	}

	inline function set_drag(v:Float):Float {
		Raw.wgr_emitter3d_set_drag(this, v);
		return v;
	}

	inline function set_inheritVelocity(v:Float):Float {
		Raw.wgr_emitter3d_set_inherit_velocity(this, v);
		return v;
	}

	inline function set_stretch(v:Float):Float {
		Raw.wgr_emitter3d_set_stretch(this, v);
		return v;
	}

	inline function set_seed(v:Int):Int {
		Raw.wgr_emitter3d_set_seed(this, v);
		return v;
	}

	/** How long a particle lives, picked per particle between the two. **/
	public inline function setLife(minSeconds:Float, maxSeconds:Float):Bool
		return Raw.wgr_emitter3d_set_life(this, minSeconds, maxSeconds);

	/** Start and end size, and how much that varies per particle. **/
	public inline function setSize(start:Float, end:Float, variance:Float = 0):Bool
		return Raw.wgr_emitter3d_set_size(this, start, end, variance);

	/** Start and end tint; the end's alpha is usually 0, so particles fade out. **/
	public inline function setColor(start:Color, end:Color):Bool
		return Raw.wgr_emitter3d_set_color(this, start, end);

	/** Turn rate, picked per particle between the two (radians per second). **/
	public inline function setSpin(min:Float, max:Float):Bool
		return Raw.wgr_emitter3d_set_spin(this, min, max);

	/** The sub-rectangle of the texture a particle is cut from. **/
	public inline function setSource(x:Float, y:Float, width:Float, height:Float):Bool
		return Raw.wgr_emitter3d_set_source(this, x, y, width, height);

	/** A flipbook: `columns` by `rows` frames, `count` of them (0: all). **/
	public inline function setFrames(columns:Int, rows:Int, count:Int = 0, perSecond:Float = 0):Bool
		return Raw.wgr_emitter3d_set_frames(this, columns, rows, count, perSecond);

	public inline function setAlphaMode(mode:AlphaMode, cutoff:Float = 0):Bool
		return Raw.wgr_emitter3d_set_alpha_mode(this, mode, cutoff);

	/** Make `count` particles now, on top of whatever the rate is doing. **/
	public inline function burst(count:Int):Bool
		return Raw.wgr_emitter3d_burst(this, count);

	/** Run it forward `seconds` so it is already going when it first appears. **/
	public inline function prewarm(seconds:Float):Bool
		return Raw.wgr_emitter3d_prewarm(this, seconds);

	/** A size curve, in place of the start/end pair: `t` from 0 to 1 over a life. **/
	public inline function addSizeKey(t:Float, size:Float):Bool
		return Raw.wgr_emitter3d_add_size_key(this, t, size);

	public inline function clearSizeKeys():Bool
		return Raw.wgr_emitter3d_clear_size_keys(this);

	/** A colour curve, in place of the start/end pair. **/
	public inline function addColorKey(t:Float, color:Color):Bool
		return Raw.wgr_emitter3d_add_color_key(this, t, color);

	public inline function clearColorKeys():Bool
		return Raw.wgr_emitter3d_clear_color_keys(this);

	/** Each particle takes one of these at birth, instead of the start tint. **/
	public inline function addPaletteColor(color:Color):Bool
		return Raw.wgr_emitter3d_add_palette_color(this, color);

	public inline function clearPalette():Bool
		return Raw.wgr_emitter3d_clear_palette(this);

	/** Every particle alive, gone. **/
	public inline function clear():Void
		Raw.wgr_emitter3d_clear(this);

	/** Draw it now; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_emitter3d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_emitter3d_destroy(this);
}
