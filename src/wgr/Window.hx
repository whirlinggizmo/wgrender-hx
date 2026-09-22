package wgr;

// wgr_window.h — the window, and the monitors it can sit on

/**
	The window is owned by the runtime: `Wgr.initValues` configures it, `Wgr.run`
	opens it, and the cleanup callback runs as it closes. Everything here adjusts it
	while it is open.

	Sizes are logical pixels; positions are the desktop's coordinates with a top-left
	origin. A call returns false where the platform can't do what was asked, and logs
	why once:

	- web: the canvas is the window. Setting its size works unless the page's CSS
	  overrides it; there is no position, and one monitor — the screen.
	- Linux under XWayland: compositors usually ignore a program moving its own
	  window, and may ignore resizing, though the call still succeeds.
	- fullscreen on the web only takes effect during a user gesture.
**/
class Window {
	public static var title(never, set):String;

	/** Whether the user has asked to close it — the X, or the window manager. **/
	public static var closeRequested(get, never):Bool;

	/** The drawable area in logical pixels. **/
	public static var screenSize(get, never):Vec2;

	/** Where it sits on the desktop; (0, 0) where there is no such thing. **/
	public static var position(get, never):Vec2;

	/**
		Refused where the platform has no fullscreen, and said so in the log -- so the
		property loses nothing. `setFullscreen` returns the answer for a caller that
		wants it.

		The web does support it: sokol calls `canvas.requestFullscreen()`, and the
		browser allows that because the transient activation from the key or click that
		led here is still live a frame later. What is *not* immediate is the reading --
		the change arrives as a `fullscreenchange` event, so this still reports the old
		value on the frame it was set.
	**/
	public static var fullscreen(get, set):Bool;

	/** Hiding it doesn't stop the loop — the program keeps running either way. **/
	public static var visible(get, set):Bool;

	public static var focused(get, never):Bool;

	/** Monitors the platform reports; 1 on the web. **/
	public static var monitorCount(get, never):Int;

	/** Which one the window is on. **/
	public static var monitor(get, set):Int;

	static inline function set_title(v:String):String {
		Raw.wgr_window_set_title(v);
		return v;
	}

	static inline function get_closeRequested():Bool
		return Raw.wgr_window_close_requested() != 0;

	static inline function get_screenSize():Vec2
		return Vec2.of(Raw.wgr_window_get_screen_size());

	static inline function get_position():Vec2
		return Vec2.of(Raw.wgr_window_get_position());

	static inline function get_fullscreen():Bool
		return Raw.wgr_window_is_fullscreen();

	static inline function set_fullscreen(v:Bool):Bool {
		Raw.wgr_window_set_fullscreen(v);
		return v;
	}

	/**
		The property, with the answer. wgrender logs a refusal either way, so this is
		for a caller that wants to act on it rather than read about it -- wgrender's own
		window example prints it on screen.
	**/
	public static inline function setFullscreen(fullscreen:Bool):Bool
		return Raw.wgr_window_set_fullscreen(fullscreen);

	static inline function get_visible():Bool
		return Raw.wgr_window_is_visible();

	static inline function set_visible(v:Bool):Bool {
		Raw.wgr_window_set_visible(v);
		return v;
	}

	/** The property, with the answer. wgrender has no platform that refuses this yet. **/
	public static inline function setVisible(visible:Bool):Bool
		return Raw.wgr_window_set_visible(visible);

	static inline function get_focused():Bool
		return Raw.wgr_window_is_focused();

	static inline function get_monitorCount():Int
		return Raw.wgr_window_get_monitor_count();

	static inline function get_monitor():Int
		return Raw.wgr_window_get_monitor();

	static inline function set_monitor(v:Int):Int {
		Raw.wgr_window_set_monitor(v);
		return v;
	}

	/** The drawable area in logical pixels. **/
	public static inline function getScreenSize():Vec2
		return Vec2.of(Raw.wgr_window_get_screen_size());

	public static inline function setSize(width:Int, height:Int):Bool
		return Raw.wgr_window_set_size(width, height);

	/**
		Move it. Only where the platform lets a program place its own windows — not the
		web, and not a Wayland desktop, where the compositor places them.
	**/
	public static inline function setPosition(x:Int, y:Int):Bool
		return Raw.wgr_window_set_position(x, y);

	/** Move the window to that monitor, centered. **/
	public static inline function setMonitor(monitor:Int):Bool
		return Raw.wgr_window_set_monitor(monitor);

	public static inline function getMonitorSize(monitor:Int):Vec2
		return Vec2.of(Raw.wgr_window_get_monitor_size(monitor));

	public static inline function getMonitorPosition(monitor:Int):Vec2
		return Vec2.of(Raw.wgr_window_get_monitor_position(monitor));

	/** The monitor's name, or "" if the platform doesn't know it. **/
	public static inline function getMonitorName(monitor:Int):String
		return Raw.wgr_window_get_monitor_name(monitor);
}
