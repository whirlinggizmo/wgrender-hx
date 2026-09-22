package wgr.flat;

// wgr_shape3d.h — retained 3D shapes, flat

import wgr.impl.Raw;

/** The flat form of `wgr.Shape3D`'s retained half. **/
abstract Shape3D(Handle) from Handle to Handle {
	@:to inline function toRaw():WgrHandle
		return (this : Int);

	public static inline function create():Shape3D
		return (Raw.wgr_shape3d_create() : Handle);

	public static inline function destroy(shape:Shape3D):Void
		Raw.wgr_shape3d_destroy(shape);

	public static inline function setSphere(shape:Shape3D, radius:Float):Bool
		return Raw.wgr_shape3d_set_sphere(shape, radius);

	public static inline function setCube(shape:Shape3D, size:Vec3):Bool
		return Raw.wgr_shape3d_set_cube(shape, size.x, size.y, size.z);

	public static inline function setTransform(shape:Shape3D, position:Vec3, ?rotation:Vec3, ?scale:Vec3):Bool {
		final r = rotation != null ? rotation : new Vec3(0, 0, 0);
		final s = scale != null ? scale : new Vec3(1, 1, 1);
		return Raw.wgr_shape3d_set_transform(shape, position.x, position.y, position.z, r.x, r.y, r.z, s.x, s.y, s.z);
	}

	public static inline function setColor(shape:Shape3D, color:Color):Bool
		return Raw.wgr_shape3d_set_color(shape, color);

	public static inline function setVisible(shape:Shape3D, value:Bool):Bool
		return Raw.wgr_shape3d_set_visible(shape, value);

	public static inline function isVisible(shape:Shape3D):Bool
		return Raw.wgr_shape3d_is_visible(shape);
}
