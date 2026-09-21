package wgr;

// wgr_texture.h — the image resource

/** A loaded image: reference counted, shared. **/
abstract Texture(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** Its size in pixels. **/
	public var size(get, never):Vec2;

	/**
		Stands in for a texture that failed to load — a glTF file's missing image, say,
		which still loads the model, with a warning. Built in: a magenta and black
		checker. Setting one takes a reference; set `Handle.NONE` to restore the
		built-in. Only affects resources loaded after the call.
	**/
	public static var placeholder(get, set):Texture;

	/** The 1x1 white texture, for a material or sprite that wants no image. **/
	public static var defaultTexture(get, never):Texture;

	public static inline function create(path:String):Texture
		return (Raw.wgr_texture_create(path) : Handle);

	/**
		A texture to draw into: `width` x `height` pixels, cleared to transparent black
		each time. Draw into it between `Render.beginTexture` and `Render.endTexture`,
		then use it like any other. Matches the screen's format and MSAA; no mipmaps.
	**/
	public static inline function createTarget(width:Int, height:Int):Texture
		return (Raw.wgr_texture_create_target(width, height) : Handle);

	static inline function get_defaultTexture():Texture
		return (Raw.wgr_texture_get_default() : Handle);

	static inline function get_placeholder():Texture
		return (Raw.wgr_texture_get_placeholder() : Handle);

	static inline function set_placeholder(v:Texture):Texture {
		Raw.wgr_texture_set_placeholder(v);
		return v;
	}

	inline function get_size():Vec2
		return Vec2.of(Raw.wgr_texture_get_size(this));

	/**
		Draw it once, axis-aligned, top-left at (`x`, `y`) in logical pixels — no object
		needed. A `width` or `height` at or below 0 uses the texture's own. Outside 3D
		mode, in call order. For rotation, a source region or picking, use `Sprite2D`.
	**/
	public inline function draw(x:Float, y:Float, width:Float = 0, height:Float = 0, tint:Color = Color.WHITE):Void
		Raw.wgr_texture_draw(this, x, y, width, height, tint);

	/**
		A region of it — `source` in texture pixels, a zero size meaning all of it —
		drawn into the rectangle at (`x`, `y`). For icons and panels cut from an atlas.
	**/
	public inline function drawRegion(sourceX:Float, sourceY:Float, sourceWidth:Float, sourceHeight:Float, x:Float,
			y:Float, width:Float = 0, height:Float = 0, tint:Color = Color.WHITE):Void
		Raw.wgr_texture_draw_ex(this, sourceX, sourceY, sourceWidth, sourceHeight, x, y, width, height, tint);

	/**
		The same region, nine-sliced: the borders keep their size, the edges stretch
		along one axis and the middle along both — a skinned panel or button at any
		size. Borders that don't fit shrink to fit; all four at 0 draws the plain region.
	**/
	public inline function drawNineSlice(sourceX:Float, sourceY:Float, sourceWidth:Float, sourceHeight:Float,
			left:Float, top:Float, right:Float, bottom:Float, x:Float, y:Float, width:Float = 0, height:Float = 0,
			tint:Color = Color.WHITE):Void
		Raw.wgr_texture_draw_nine_slice(this, sourceX, sourceY, sourceWidth, sourceHeight, left, top, right, bottom, x,
			y, width, height, tint);

	/** How this texture repeats and filters wherever it is used. **/
	public inline function setSampling(wrapU:TextureWrap, wrapV:TextureWrap, filter:TextureFilter):Bool
		return Raw.wgr_texture_set_sampling(this, wrapU, wrapV, filter);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_texture_release(this);
}
