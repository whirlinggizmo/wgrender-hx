package wgr;

// wgr_types.h

@:structInit
class Vec2 {
	public final x:Float;
	public final y:Float;

	public inline function new(x:Float = 0, y:Float = 0) {
		this.x = x;
		this.y = y;
	}

	public function toString():String
		return '($x, $y)';
}
