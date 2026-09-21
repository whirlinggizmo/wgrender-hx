package wgr;

// wgr_handle.h — the untyped handle every typed kind is an abstract over

/** An untyped wgrender handle (what a pick result hits); 0 is none. **/
abstract Handle(Int) from Int to Int {
	/** The zero handle: not created (yet), or creation failed. Assignable to any kind. **/
	public static final NONE:Handle = 0;

	public var isNone(get, never):Bool;

	inline function get_isNone():Bool
		return this == 0;

	/** wgrender's C `wgr_handle_t`. **/
	@:to inline function toRaw():WgrHandle
		return this;

	public inline function toString():String
		return Std.string(this);
}
