package wgr;

// wgr_debug.h

class Debug {
	/** Draw the frame rate every frame, without the program asking each time. **/
	public static inline function enableFps(x:Int, y:Int, fontSize:Int):Void
		Raw.wgr_debug_enable_fps(x, y, fontSize);
}
