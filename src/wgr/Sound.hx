package wgr;

// wgr_sound.h — a playable instance of an Audio

/** A playing (or playable) instance of an `Audio`, with its own state. **/
abstract Sound(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var loop(never, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sound takes its own reference to `audio`. **/
	public inline function new(audio:Audio)
		this = (Raw.wgr_sound_create(audio) : Handle);

	inline function set_loop(v:Bool):Bool {
		Raw.wgr_sound_set_loop(this, v);
		return v;
	}

	public inline function play():Bool
		return Raw.wgr_sound_play(this);

	/** Objects are private, so they're destroyed; resources are shared and released. **/
	public inline function destroy():Void
		Raw.wgr_sound_destroy(this);
}
