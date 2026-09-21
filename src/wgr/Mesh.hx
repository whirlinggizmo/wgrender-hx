package wgr;

// wgr_model.h — the geometry resource

/** Loaded model geometry: reference counted, shared. **/
abstract Mesh(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/** One slot per glTF material. **/
	public var materialCount(get, never):Int;

	public static inline function create(path:String):Mesh
		return (Raw.wgr_mesh_create(path) : Handle);

	inline function get_materialCount():Int
		return Raw.wgr_mesh_get_material_count(this);

	/**
		The material in `slot`, borrowed: it stays valid while the mesh lives, and
		changing it changes every model using the mesh. To change one model, give that
		model an override with `Model.setMaterial`.
	**/
	public inline function getMaterial(slot:Int):Material
		return (Raw.wgr_mesh_get_material(this, slot) : Handle);

	/** Drop this reference; the data goes when the last one does. **/
	public inline function release():Void
		Raw.wgr_mesh_release(this);

	// --- generated meshes ---------------------------------------------------
	//
	// Shapes made in code, with normals, both sets of texture coordinates and
	// tangents, so any material lights them — normal maps and custom shaders
	// included. Centered on the origin, y up, in meters. Like a loaded mesh they are
	// resources: deduplicated (the same parameters return the same mesh, with one
	// more reference) and never changed once made. To size one model differently,
	// scale the model rather than making another mesh. One material slot: white, not
	// metallic, roughness 0.5 — replace it with `Model.setMaterial`. A size at or
	// below 0 gives a none handle, and is logged; counts are clamped to their ranges.

	/** Flat in XZ facing +Y. `subdivisions` 0..256 adds that many cells each way. **/
	public static inline function plane(width:Float, length:Float, subdivisions:Int = 0):Mesh
		return (Raw.wgr_mesh_create_plane(width, length, subdivisions) : Handle);

	/** Each face its own vertices, so the edges stay sharp; textured 0..1 per face. **/
	public static inline function cube(width:Float, height:Float, length:Float):Mesh
		return (Raw.wgr_mesh_create_cube(width, height, length) : Handle);

	/** `rings` 2..256 pole to pole, `segments` 3..512 around. **/
	public static inline function sphere(radius:Float, rings:Int = 16, segments:Int = 32):Mesh
		return (Raw.wgr_mesh_create_sphere(radius, rings, segments) : Handle);

	/** Capped; `segments` 3..512 around. **/
	public static inline function cylinder(radius:Float, height:Float, segments:Int = 32):Mesh
		return (Raw.wgr_mesh_create_cylinder(radius, height, segments) : Handle);

	/** Tip up, capped base. **/
	public static inline function cone(radius:Float, height:Float, segments:Int = 32):Mesh
		return (Raw.wgr_mesh_create_cone(radius, height, segments) : Handle);

	/** `height` is end to end, at least twice `radius`; less than that gives a sphere. **/
	public static inline function capsule(radius:Float, height:Float, rings:Int = 8, segments:Int = 32):Mesh
		return (Raw.wgr_mesh_create_capsule(radius, height, rings, segments) : Handle);

	/** Around y. `radius` reaches the middle of the tube, `thickness` is its radius. **/
	public static inline function torus(radius:Float, thickness:Float, rings:Int = 16, segments:Int = 32):Mesh
		return (Raw.wgr_mesh_create_torus(radius, thickness, rings, segments) : Handle);
}
