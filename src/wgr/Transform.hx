package wgr;

// shared by Model, Sprite3D and Text3D

/** The defaults `setTransform` fills in for an omitted rotation or scale. **/
@:noCompletion
class Transform {
	public static final NO_ROTATION = new Vec3(0, 0, 0);
	public static final UNIT_SCALE = new Vec3(1, 1, 1);
}
