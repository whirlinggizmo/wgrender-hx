package wgr;

// wgr_input.h — mouse and keyboard

class Input {
	public static function getMouseState():MouseState {
		// hxcpp unpacks the C struct; Raw.js.hx reads it out of the heap for us.
		#if cpp
		final m = Raw.wgr_input_get_mouse_state();
		return new MouseState(m.x, m.y, m.wheel, m.wheel_x, m.left, m.right, m.middle,
			[m.buttons[0], m.buttons[1], m.buttons[2]], m.dx, m.dy);
		#else
		return Raw.wgr_input_get_mouse_state();
		#end
	}

	public static inline function getKey(key:Key):ButtonState
		return Raw.wgr_input_get_key(key);

	/** Went down this frame. **/
	public static inline function isKeyPressed(key:Key):Bool
		return getKey(key) == Pressed;

	/** Held, including the frame it went down. **/
	public static inline function isKeyDown(key:Key):Bool
		return getKey(key) == Pressed || getKey(key) == Down;

	/** Went up this frame. **/
	public static inline function isKeyReleased(key:Key):Bool
		return getKey(key) == Released;

	/**
		The whole keyboard at once. For one key, `getKey` / `isKeyPressed` are simpler.
		On js the result is a heap view good only for this frame — see `KeyboardState`.
	**/
	public static inline function getKeyboardState():KeyboardState
		return Raw.wgr_input_get_keyboard_state();
}
