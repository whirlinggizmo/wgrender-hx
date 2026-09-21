package wgr;

// wgr_emitter2d.h — particles on the screen

/**
	The same as `Emitter3D`, on the screen instead of in the world: positions and
	velocities are in logical pixels, and it draws over the 3D like `Sprite2D`.
**/
abstract Emitter2D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	/** Whether new particles are made; the ones alive finish their lives either way. **/
	public var emitting(get, set):Bool;

	public var visible(never, set):Bool;

	/** Particles alive now. **/
	public var count(get, never):Int;

	/** The most that can be alive at once. **/
	public var max(never, set):Int;

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

	public inline function new(texture:Texture)
		this = (Raw.wgr_emitter2d_create(texture) : Handle);

	/** Where new particles appear; the ones alive stay where they were born. **/
	public inline function setPosition(position:Vec2):Bool
		return Raw.wgr_emitter2d_set_position(this, position.x, position.y);

	/** Move without the trail a `setPosition` sweep would leave. **/
	public inline function jump(position:Vec2):Bool
		return Raw.wgr_emitter2d_jump(this, position.x, position.y);

	/** New particles appear anywhere in this box around the position. **/
	public inline function setSpawnBox(halfWidth:Float, halfHeight:Float):Bool
		return Raw.wgr_emitter2d_set_spawn_box(this, halfWidth, halfHeight);

	/** 3D's spawn sphere. **/
	public inline function setSpawnCircle(radius:Float):Bool
		return Raw.wgr_emitter2d_set_spawn_circle(this, radius);

	/** Initial velocity, `spread` radians of arc around it, and its variance. **/
	public inline function setVelocity(velocity:Vec2, spread:Float = 0, speedVariance:Float = 0):Bool
		return Raw.wgr_emitter2d_set_velocity(this, velocity.x, velocity.y, spread, speedVariance);

	public inline function setGravity(gravity:Vec2):Bool
		return Raw.wgr_emitter2d_set_gravity(this, gravity.x, gravity.y);

	inline function get_emitting():Bool
		return Raw.wgr_emitter2d_is_emitting(this);

	inline function set_emitting(v:Bool):Bool {
		Raw.wgr_emitter2d_set_emitting(this, v);
		return v;
	}

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_emitter2d_set_visible(this, v);
		return v;
	}

	inline function get_count():Int
		return Raw.wgr_emitter2d_get_count(this);

	inline function set_max(v:Int):Int {
		Raw.wgr_emitter2d_set_max(this, v);
		return v;
	}

	inline function set_rate(v:Float):Float {
		Raw.wgr_emitter2d_set_rate(this, v);
		return v;
	}

	inline function set_drag(v:Float):Float {
		Raw.wgr_emitter2d_set_drag(this, v);
		return v;
	}

	inline function set_inheritVelocity(v:Float):Float {
		Raw.wgr_emitter2d_set_inherit_velocity(this, v);
		return v;
	}

	inline function set_stretch(v:Float):Float {
		Raw.wgr_emitter2d_set_stretch(this, v);
		return v;
	}

	inline function set_seed(v:Int):Int {
		Raw.wgr_emitter2d_set_seed(this, v);
		return v;
	}

	/** How long a particle lives, picked per particle between the two. **/
	public inline function setLife(minSeconds:Float, maxSeconds:Float):Bool
		return Raw.wgr_emitter2d_set_life(this, minSeconds, maxSeconds);

	/** Start and end size, and how much that varies per particle. **/
	public inline function setSize(start:Float, end:Float, variance:Float = 0):Bool
		return Raw.wgr_emitter2d_set_size(this, start, end, variance);

	/** Start and end tint; the end's alpha is usually 0, so particles fade out. **/
	public inline function setColor(start:Color, end:Color):Bool
		return Raw.wgr_emitter2d_set_color(this, start, end);

	/** Turn rate, picked per particle between the two (radians per second). **/
	public inline function setSpin(min:Float, max:Float):Bool
		return Raw.wgr_emitter2d_set_spin(this, min, max);

	/** The sub-rectangle of the texture a particle is cut from. **/
	public inline function setSource(x:Float, y:Float, width:Float, height:Float):Bool
		return Raw.wgr_emitter2d_set_source(this, x, y, width, height);

	/** A flipbook: `columns` by `rows` frames, `count` of them (0: all). **/
	public inline function setFrames(columns:Int, rows:Int, count:Int = 0, perSecond:Float = 0):Bool
		return Raw.wgr_emitter2d_set_frames(this, columns, rows, count, perSecond);

	public inline function setAlphaMode(mode:AlphaMode, cutoff:Float = 0):Bool
		return Raw.wgr_emitter2d_set_alpha_mode(this, mode, cutoff);

	/** Make `count` particles now, on top of whatever the rate is doing. **/
	public inline function burst(count:Int):Bool
		return Raw.wgr_emitter2d_burst(this, count);

	/** Run it forward `seconds` so it is already going when it first appears. **/
	public inline function prewarm(seconds:Float):Bool
		return Raw.wgr_emitter2d_prewarm(this, seconds);

	/** A size curve, in place of the start/end pair: `t` from 0 to 1 over a life. **/
	public inline function addSizeKey(t:Float, size:Float):Bool
		return Raw.wgr_emitter2d_add_size_key(this, t, size);

	public inline function clearSizeKeys():Bool
		return Raw.wgr_emitter2d_clear_size_keys(this);

	/** A colour curve, in place of the start/end pair. **/
	public inline function addColorKey(t:Float, color:Color):Bool
		return Raw.wgr_emitter2d_add_color_key(this, t, color);

	public inline function clearColorKeys():Bool
		return Raw.wgr_emitter2d_clear_color_keys(this);

	/** Each particle takes one of these at birth, instead of the start tint. **/
	public inline function addPaletteColor(color:Color):Bool
		return Raw.wgr_emitter2d_add_palette_color(this, color);

	public inline function clearPalette():Bool
		return Raw.wgr_emitter2d_clear_palette(this);

	/** Every particle alive, gone. **/
	public inline function clear():Void
		Raw.wgr_emitter2d_clear(this);

	/** Draw it now; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_emitter2d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_emitter2d_destroy(this);
}
