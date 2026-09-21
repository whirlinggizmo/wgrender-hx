package wgr;

// wgr_types.h

@:structInit
class Vec3 {
	public final x:Float;
	public final y:Float;
	public final z:Float;

	public inline function new(x:Float = 0, y:Float = 0, z:Float = 0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	/**
		The C struct as a `Vec3`. hxcpp gives us the struct itself; on js Raw has already
		read it out of the heap, so there is nothing left to do.
	**/
	@:allow(wgr)
	static inline function of(v:#if cpp CVec3 #else Vec3 #end):Vec3
		#if cpp
		return new Vec3(v.x, v.y, v.z);
		#else
		return v;
		#end

	public function toString():String
		return '($x, $y, $z)';
}
