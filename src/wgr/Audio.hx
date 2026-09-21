package wgr;

// wgr_audio.h — the sound data resource

/**
	A loaded sound file: decoded PCM, reference counted and shared. `Sound` objects
	reference one by handle — including looping music, which is a `Sound` with
	`loop` set rather than a kind of its own.
**/
abstract Audio(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Audio
		return (Raw.wgr_audio_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_audio_release(this);
}
