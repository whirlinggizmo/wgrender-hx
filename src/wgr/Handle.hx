package wgr;

// wgr_handle.h — the untyped handle every typed kind is an abstract over

/** An untyped wgrender handle (what a pick result hits); 0 is none. **/
abstract Handle(Int) from Int to Int {
	/** The zero handle: not created (yet), or creation failed. Assignable to any kind. **/
	public static final NONE:Handle = 0;

	/**
		Whether this is the zero handle. **The only test that is correct on both
		targets** — `h == 0` and `h == Handle.NONE` are not.

		On js an uninitialised field is `undefined`, and `undefined == 0` is `false`, so
		both comparisons report a handle for something never assigned. They compile, and
		they are right on hxcpp and right on js for a field that *was* assigned, which
		is what makes them worth naming here. Promoting the 0 happens at the typed
		abstract (`Int` -> `Handle` -> `Model`), so an operator overload on `Handle`
		cannot intercept it; there is nothing to fix but the habit.
	**/
	public var isNone(get, never):Bool;

	inline function get_isNone():Bool
		// On js an uninitialised static is `undefined`, and `undefined == 0` is false,
		// so a field declared without `= Handle.NONE` would claim to hold a handle.
		// `== null` catches both there; on a static target 0 is the only possibility.
		#if js
		return this == null || this == 0;
		#else
		return this == 0;
		#end

	/** What this handle refers to; `None` for a none handle. **/
	public var kind(get, never):HandleKind;

	inline function get_kind():HandleKind
		return HandleKind.of(Raw.wgr_handle_get_kind(this));

	/** wgrender's C `wgr_handle_t`. **/
	@:to inline function toRaw():WgrHandle
		return this;

	public inline function toString():String
		return Std.string(this);
}
