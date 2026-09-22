package wgr.flat;

// wgr_model.h — a placed instance of a Mesh, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Model`. See `wgr.flat.Material` for the shape and why. **/
abstract Model(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create(mesh:Mesh):Model
		return (Raw.wgr_model_create(mesh) : Handle);

	public static inline function destroy(model:Model):Void
		Raw.wgr_model_destroy(model);

	/** Swap the geometry, keeping this model's transform, tint and materials. **/
	public static inline function setMesh(model:Model, mesh:Mesh):Bool
		return Raw.wgr_model_set_mesh(model, mesh);

	/**
		Position, rotation (radians) and scale at once. Omitted parts are left as they
		were — the C takes all nine, so this reads them back first.
	**/
	public static inline function setTransform(model:Model, position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : new Vec3(0, 0, 0);
		final s = scale != null ? scale : new Vec3(1, 1, 1);
		return Raw.wgr_model_set_transform(model, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	public static inline function setTint(model:Model, color:Color):Bool
		return Raw.wgr_model_set_tint(model, color);

	public static inline function setMaterial(model:Model, slot:Int, material:Material):Bool
		return Raw.wgr_model_set_material(model, slot, material);

	public static inline function getMaterial(model:Model, slot:Int):Material
		return (Raw.wgr_model_get_material(model, slot) : Handle);

	public static inline function setVisible(model:Model, value:Bool):Bool
		return Raw.wgr_model_set_visible(model, value);

	public static inline function isVisible(model:Model):Bool
		return Raw.wgr_model_is_visible(model);

	public static inline function setPickable(model:Model, value:Bool):Bool
		return Raw.wgr_model_set_pickable(model, value);

	public static inline function isPickable(model:Model):Bool
		return Raw.wgr_model_is_pickable(model);

	public static inline function setEnabled(model:Model, value:Bool):Bool
		return Raw.wgr_model_set_enabled(model, value);

	public static inline function isEnabled(model:Model):Bool
		return Raw.wgr_model_is_enabled(model);

	// --- animation ---

	public static inline function setAnimation(model:Model, index:Int):Bool
		return Raw.wgr_model_set_animation(model, index);

	public static inline function setAnimationSpeed(model:Model, speed:Float):Bool
		return Raw.wgr_model_set_animation_speed(model, speed);

	public static inline function setAnimationLoop(model:Model, loop:Bool):Bool
		return Raw.wgr_model_set_animation_loop(model, loop);

	public static inline function getAnimationCount(model:Model):Int
		return Raw.wgr_model_get_animation_count(model);

	/** Advance the current animation by `dt` seconds. **/
	public static inline function animate(model:Model, dt:Float):Bool
		return Raw.wgr_model_animate(model, dt);

	public static inline function draw(model:Model):Void
		Raw.wgr_model_draw(model);
}
