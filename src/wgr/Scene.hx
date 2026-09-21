package wgr;

// wgr_scene.h — what is drawn, and picking against it

abstract Scene(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;
	public var activeCamera(never, set):Camera3D;

	/**
		Whether the scene tracks the pointer. An interactive scene picks under the
		pointer once per frame, before the frame's ticks, against where its members were
		last drawn, and keeps hover and press per member: 2D members first (topmost),
		then the nearest 3D one. Changing this resets that state. Default: off.
	**/
	public var interactive(get, set):Bool;

	/**
		Skip members the camera can't see, on by default. Each member's bounds are
		tested against the view before it is submitted, which is far cheaper than
		drawing it. Turn it off to see everything submitted — when checking whether a
		drawable's bounds are right. Members without bounds (2D ones) are never culled.
	**/
	public var culling(get, set):Bool;

	/** The topmost member under the pointer, enabled or not; none if there isn't one. **/
	public var hovered(get, never):SceneMember;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	public inline function new()
		this = (Raw.wgr_scene_create() : Handle);

	inline function set_activeCamera(v:Camera3D):Camera3D {
		Raw.wgr_scene_set_active_camera(this, v);
		return v;
	}

	inline function get_interactive():Bool
		return Raw.wgr_scene_is_interactive(this);

	inline function set_interactive(v:Bool):Bool {
		Raw.wgr_scene_set_interactive(this, v);
		return v;
	}

	inline function get_culling():Bool
		return Raw.wgr_scene_is_culling(this);

	inline function set_culling(v:Bool):Bool {
		Raw.wgr_scene_set_culling(this, v);
		return v;
	}

	inline function get_hovered():SceneMember
		return SceneMember.of(Raw.wgr_scene_get_hovered(this));

	public inline function add(member:SceneMember, layer:Int = 0):Bool
		return Raw.wgr_scene_add(this, member, layer);

	/** Move a member to another layer. **/
	public inline function setLayer(member:SceneMember, layer:Int):Bool
		return Raw.wgr_scene_set_layer(this, member, layer);

	/** Take it out; it keeps existing, and so does anything else holding it. **/
	public inline function remove(member:SceneMember):Bool
		return Raw.wgr_scene_remove(this, member);

	/** Take every member out. The members themselves are untouched. **/
	public inline function clear():Void
		Raw.wgr_scene_clear(this);

	/**
		Clip one layer's 2D members to a screen rectangle: what falls outside isn't
		drawn and isn't picked, which is what a scrolling list or a panel with content
		needs. A zero width or height removes the layer's rectangle. 3D members are
		never clipped. The rectangles belong to the scene, so they outlive `clear`; at
		most 8 layers per scene.
	**/
	public inline function setClip(layer:Int, x:Float, y:Float, width:Float, height:Float):Bool
		return Raw.wgr_scene_set_clip(this, layer, x, y, width, height);

	public inline function setAmbient(color:Color, intensity:Float):Bool
		return Raw.wgr_scene_set_ambient(this, color, intensity);

	/**
		Image-based lighting: reflections and diffuse light from `environment`, on top
		of lights and ambient, for the scene's PBR models. `intensity` scales it (1 is
		as authored) and `rotation` (radians) turns it around the world up axis. A none
		handle removes it. The scene holds its own reference.
	**/
	public inline function setEnvironment(environment:Environment, intensity:Float = 1, rotation:Float = 0):Bool
		return Raw.wgr_scene_set_environment(this, environment, intensity, rotation);

	/**
		Draw `environment` behind everything (a skybox), with the scene's environment
		intensity and rotation when it is the same environment, else plain. `blur` runs
		0 (sharp) to 1 (fully blurred). A none handle removes it.
	**/
	public inline function setBackground(environment:Environment, blur:Float = 0):Bool
		return Raw.wgr_scene_set_background(this, environment, blur);

	/** `exposure` is in stops: +1 doubles the brightness. Default: `Neutral`, 0. **/
	public inline function setTonemap(tonemap:Tonemap, exposure:Float = 0):Bool
		return Raw.wgr_scene_set_tonemap(this, tonemap, exposure);

	public inline function draw():Void
		Raw.wgr_scene_draw(this);

	/**
		Whether the pointer is over `member`: `Pressed` when it came over it, `Down`
		while it is, `Released` when it left. Needs `interactive`.
	**/
	public inline function getHover(member:SceneMember):ButtonState
		return Raw.wgr_scene_get_hover(this, member);

	/**
		The primary button, for a press that started on `member`: `Pressed` when it went
		down, `Down` while held — including after the pointer moved off — and `Released`
		when let go. Needs `interactive`.
	**/
	public inline function getPress(member:SceneMember):ButtonState
		return Raw.wgr_scene_get_press(this, member);

	/** Released while still over the member it was pressed on. Needs `interactive`. **/
	public inline function isClicked(member:SceneMember):Bool
		return Raw.wgr_scene_is_clicked(this, member);

	/**
		What is under (`x`, `y`) in screen space. A none `camera` uses the scene's
		active one. Compare the result with typed handles: `pick.handle == model`.
	**/
	public inline function pick(x:Float, y:Float, ?camera:Camera3D):PickResult
		return Scene.toPickResult(Raw.wgr_scene_pick(this, camera == null ? 0 : (camera : Handle), x, y));

	/** A scene doesn't own its members; destroying it leaves them alone. **/
	public inline function destroy():Void
		Raw.wgr_scene_destroy(this);

	@:allow(wgr)
	static function toPickResult(r:#if cpp CPickResult #else PickResult #end):PickResult {
		#if cpp
		return new PickResult(r.hit, (r.handle : Int), r.distance, Vec3.of(r.point_local), Vec3.of(r.point_world),
			Vec3.of(r.normal_local), Vec3.of(r.normal_world));
		#else
		return r;
		#end
	}
}
