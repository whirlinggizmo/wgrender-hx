package wgr;

// wgr_texture.h — the image resource

/** A loaded image: reference counted, shared. **/
abstract Texture(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Texture
		return (Raw.wgr_texture_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_texture_release(this);
}
