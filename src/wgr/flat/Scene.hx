package wgr.flat;

// wgr_scene.h, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Scene`. **/
abstract Scene(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create():Scene
		return (Raw.wgr_scene_create() : Handle);

	public static inline function destroy(scene:Scene):Void
		Raw.wgr_scene_destroy(scene);

	/**
		One of the seven wgrender setters that return nothing, so this returns nothing
		either rather than inventing a `true`. Kept in the trial slice on purpose: the
		rule is "a `set*` returns what C returned", and here C returns void.
	**/
	public static inline function setActiveCamera(scene:Scene, camera:Camera3D):Void
		Raw.wgr_scene_set_active_camera(scene, camera);

	public static inline function add(scene:Scene, member:SceneMember, layer:Int = 0):Bool
		return Raw.wgr_scene_add(scene, member, layer);

	public static inline function remove(scene:Scene, member:SceneMember):Bool
		return Raw.wgr_scene_remove(scene, member);

	public static inline function setAmbient(scene:Scene, color:Color, intensity:Float):Bool
		return Raw.wgr_scene_set_ambient(scene, color, intensity);

	public static inline function setInteractive(scene:Scene, value:Bool):Bool
		return Raw.wgr_scene_set_interactive(scene, value);

	public static inline function isInteractive(scene:Scene):Bool
		return Raw.wgr_scene_is_interactive(scene);

	public static inline function draw(scene:Scene):Void
		Raw.wgr_scene_draw(scene);
}
