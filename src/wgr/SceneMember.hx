package wgr;

// wgr_scene.h

/** What `Scene.add` takes: a `Model`, `Sprite3D`, `Text2D`, `Text3D` or `Light`. **/
abstract SceneMember(Handle) to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	@:from static inline function ofModel(v:Model):SceneMember
		return cast v;

	@:from static inline function ofSprite3D(v:Sprite3D):SceneMember
		return cast v;

	@:from static inline function ofLight(v:Light):SceneMember
		return cast v;

	@:from static inline function ofText2D(v:Text2D):SceneMember
		return cast v;

	@:from static inline function ofText3D(v:Text3D):SceneMember
		return cast v;
}
