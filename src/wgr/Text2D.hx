package wgr;

// wgr_text2d.h — retained text on the screen

/**
	A placed string with retained state: set its text, place and colour once and
	wgrender keeps them, instead of your code re-passing them every frame. Add it to a
	`Scene` and `Scene.draw` draws it; `draw` draws it on its own.

	It retains the state, not the geometry — the text is still shaped on every draw,
	at the same per-frame cost as `Font.draw`. What it saves is re-sending the string.

	A none `font` uses `Text.defaultFont` until one is attached, so you can create,
	place and show text before its font asset has loaded. It holds its own reference
	to the font.
**/
abstract Text2D(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var font(never, set):Font;
	public var text(never, set):String;
	public var position(never, set):Vec2;

	/** Pixel height of one line. **/
	public var size(never, set):Float;

	public var color(never, set):Color;

	/** Wrap to this many logical pixels, between words; 0 is off (the default). **/
	public var maxWidth(never, set):Float;

	public var visible(get, set):Bool;

	/** Whether a pick can hit it. Default: pickable. **/
	public var pickable(get, set):Bool;

	/** Disabled: still drawn, picked and blocking the pointer, but it doesn't react. **/
	public var enabled(get, set):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** `Handle.NONE` for the default font; attach a real one later with `font`. **/
	public inline function new(font:Font)
		this = (Raw.wgr_text2d_create(font) : Handle);

	inline function set_font(v:Font):Font {
		Raw.wgr_text2d_set_font(this, v);
		return v;
	}

	inline function set_text(v:String):String {
		Raw.wgr_text2d_set_text(this, v); // wgrender copies it
		return v;
	}

	inline function set_position(v:Vec2):Vec2 {
		Raw.wgr_text2d_set_position(this, v.x, v.y);
		return v;
	}

	inline function set_size(v:Float):Float {
		Raw.wgr_text2d_set_size(this, v);
		return v;
	}

	inline function set_color(v:Color):Color {
		Raw.wgr_text2d_set_color(this, v);
		return v;
	}

	inline function set_maxWidth(v:Float):Float {
		Raw.wgr_text2d_set_max_width(this, v);
		return v;
	}

	inline function get_visible():Bool
		return Raw.wgr_text2d_is_visible(this);

	inline function set_visible(v:Bool):Bool {
		Raw.wgr_text2d_set_visible(this, v);
		return v;
	}

	inline function get_pickable():Bool
		return Raw.wgr_text2d_is_pickable(this);

	inline function set_pickable(v:Bool):Bool {
		Raw.wgr_text2d_set_pickable(this, v);
		return v;
	}

	inline function get_enabled():Bool
		return Raw.wgr_text2d_is_enabled(this);

	inline function set_enabled(v:Bool):Bool {
		Raw.wgr_text2d_set_enabled(this, v);
		return v;
	}

	/** Default: the position is the block's top-left corner. **/
	public inline function setAlign(horizontal:AlignX, vertical:AlignY):Bool
		return Raw.wgr_text2d_set_align(this, horizontal, vertical);

	/** The laid-out text at its current size: widest line, and the lines' total height. **/
	public inline function measure():Vec2
		return new Vec2(Raw.wgr_text2d_measure_width(this), Raw.wgr_text2d_measure_height(this));

	/** Draw it now; a scene draws its members itself. **/
	public inline function draw():Void
		Raw.wgr_text2d_draw(this);

	/** Also takes it out of every scene it's in. **/
	public inline function destroy():Void
		Raw.wgr_text2d_destroy(this);
}
