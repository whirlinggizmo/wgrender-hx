package wgr.flat;

// wgr_model.h — the geometry resource, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Mesh`: loaded model geometry, reference counted and shared. **/
abstract Mesh(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create(path:String):Mesh
		return (Raw.wgr_mesh_create(path) : Handle);

	public static inline function release(mesh:Mesh):Void
		Raw.wgr_mesh_release(mesh);

	/** One slot per glTF material. **/
	public static inline function getMaterialCount(mesh:Mesh):Int
		return Raw.wgr_mesh_get_material_count(mesh);

	/**
		The material in `slot`, borrowed: it stays valid while the mesh lives, and
		changing it changes every model using the mesh. To change one model, give that
		model an override with `Model.setMaterial`.
	**/
	public static inline function getMaterial(mesh:Mesh, slot:Int):Material
		return (Raw.wgr_mesh_get_material(mesh, slot) : Handle);
}
