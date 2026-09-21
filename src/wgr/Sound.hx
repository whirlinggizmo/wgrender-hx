package wgr;

// wgr_sound.h — a playable instance of an Audio

/** A playing (or playable) instance of an `Audio`, with its own state. **/
abstract Sound(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var loop(never, set):Bool;

	/** 0 silent, 1 as recorded. **/
	public var volume(never, set):Float;

	/** Playback rate: 1 as recorded, 2 an octave up. Changes the speed too. **/
	public var pitch(never, set):Float;

	/** -1 hard left, 0 centered, 1 hard right. **/
	public var pan(never, set):Float;

	/** Whether it is sounding right now. **/
	public var isPlaying(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** The sound takes its own reference to `audio`. **/
	public inline function new(audio:Audio)
		this = (Raw.wgr_sound_create(audio) : Handle);

	inline function set_volume(v:Float):Float {
		Raw.wgr_sound_set_volume(this, v);
		return v;
	}

	inline function set_pitch(v:Float):Float {
		Raw.wgr_sound_set_pitch(this, v);
		return v;
	}

	inline function set_pan(v:Float):Float {
		Raw.wgr_sound_set_pan(this, v);
		return v;
	}

	inline function get_isPlaying():Bool
		return Raw.wgr_sound_is_playing(this);

	inline function set_loop(v:Bool):Bool {
		Raw.wgr_sound_set_loop(this, v);
		return v;
	}

	public inline function play():Bool
		return Raw.wgr_sound_play(this);

	/** Stop, keeping the position, so `resume` picks up where it left off. **/
	public inline function pause():Bool
		return Raw.wgr_sound_pause(this);

	/** Play on from the current position. **/
	public inline function resume():Bool
		return Raw.wgr_sound_resume(this);

	/** Stop and rewind. **/
	public inline function stop():Bool
		return Raw.wgr_sound_stop(this);

	/** The sound takes its own reference; a none handle leaves it nothing to play. **/
	public inline function setAudio(audio:Audio):Bool
		return Raw.wgr_sound_set_audio(this, audio);

	/** Objects are private, so they're destroyed; resources are shared and released. **/
	public inline function destroy():Void
		Raw.wgr_sound_destroy(this);
}
