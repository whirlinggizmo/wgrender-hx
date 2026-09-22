package wgr.flat;

// wgr_texture.h — the image resource, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Texture`: a loaded image, reference counted and shared. **/
abstract Texture(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create(path:String):Texture
		return (Raw.wgr_texture_create(path) : Handle);

	public static inline function release(texture:Texture):Void
		Raw.wgr_texture_release(texture);

	/** Its size in pixels. **/
	public static inline function getSize(texture:Texture):Vec2
		return Vec2.of(Raw.wgr_texture_get_size(texture));

	/** How this texture repeats and filters wherever it is used. **/
	public static inline function setSampling(texture:Texture, wrapU:TextureWrap, wrapV:TextureWrap,
			filter:TextureFilter):Bool
		return Raw.wgr_texture_set_sampling(texture, wrapU, wrapV, filter);
}
