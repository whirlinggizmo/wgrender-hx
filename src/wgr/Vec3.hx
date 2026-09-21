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

	public function toString():String
		return '($x, $y, $z)';
}
