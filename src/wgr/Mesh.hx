package wgr;

// wgr_model.h — the geometry resource

/** Loaded model geometry: reference counted, shared. **/
abstract Mesh(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Mesh
		return (Raw.wgr_mesh_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_mesh_release(this);
}
