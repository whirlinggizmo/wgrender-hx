package wgr;

// wgr_window.h

class Window {
	public static inline function getScreenSize():Vec2
		return Text.toVec2(Raw.wgr_window_get_screen_size());
}
