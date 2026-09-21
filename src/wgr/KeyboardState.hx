package wgr;

// wgr_input.h

// Raw.js.hx does not marshal the 512-int keyboard struct yet.
#if cpp

/** Every key at once, plus this frame's pressed keys and characters. **/
abstract KeyboardState(CKeyboardState) from CKeyboardState {
	@:arrayAccess public inline function get(key:Key):ButtonState
		return this.keys[key];

	/** Went down this frame. **/
	public inline function isPressed(key:Key):Bool
		return get(key) == Pressed;

	/** Held, including the frame it went down. **/
	public inline function isDown(key:Key):Bool
		return get(key) == Pressed || get(key) == Down;

	/** Went up this frame. **/
	public inline function isReleased(key:Key):Bool
		return get(key) == Released;
}
#end
