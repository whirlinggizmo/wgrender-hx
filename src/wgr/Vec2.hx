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

	/**
		The C struct as a `Vec2`. hxcpp gives us the struct itself; on js Raw has already
		read it out of the heap, so there is nothing left to do.
	**/
	@:allow(wgr)
	static inline function of(v:#if cpp CVec2 #else Vec2 #end):Vec2
		#if cpp
		return new Vec2(v.x, v.y);
		#else
		return v;
		#end

	public function toString():String
		return '($x, $y)';
}
