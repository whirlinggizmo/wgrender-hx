package wgr;

// wgr_shader.h — a custom material shader resource

/**
	A custom material shader: reference counted and shared, like any resource.

	Write a fragment shader (and optionally a vertex hook) against wgrender's
	`shaders/wgr.glsl`, compile it for every backend with `tools/shaderpack.py
	name.glsl`, and load the `.wgrshader` it writes. Use it with `Material.custom`;
	its parameters and textures are then set by the names your shader gives them.
**/
abstract Shader(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public static inline function create(path:String):Shader
		return (Raw.wgr_shader_create(path) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_shader_release(this);
}
