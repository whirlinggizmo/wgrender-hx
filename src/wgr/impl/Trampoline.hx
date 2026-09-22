package wgr.impl;

/**
	One C function pointer per callback kind, for a Haxe static, per target.

	wgrender's callbacks are `(void *payload, void *user)` and the like, so a Haxe
	closure cannot be one. The answer is the same shape on both targets, and it is the
	one librl's bindings use: register a *single* dispatcher with the C, carry an
	integer key in its `user_data`, and keep a table from key to closure. Only the way
	a static becomes a pointer differs.

	- hxcpp: `cpp.Callable.fromStaticFunction`, which costs nothing.
	- js: `addFunction`, which puts the function in the wasm table and returns its
	  index -- **once**, lazily, for the whole program, not once per listener. That is
	  what the key is for: a thousand listeners cost one table slot. The slot is never
	  returned, because the dispatcher outlives everything that uses it; `Raw` exports
	  `removeFunction` for callers who allocate their own.
**/
@:noCompletion
class Trampoline {
	#if js
	static var eventPointer = 0;
	static var pingPointer = 0;
	#end

	/** `wgr_event_listener_fn`: `(void *payload, void *user)`, which is `vii` on wasm. **/
	public static inline function event(dispatch:(payload:VoidStar, user:VoidStar) -> Void):EventListenerFn {
		#if cpp
		return cpp.Callable.fromStaticFunction(dispatch);
		#else
		if (eventPointer == 0)
			eventPointer = Raw.addFunction(dispatch, "vii");
		return eventPointer;
		#end
	}

	/** `wgr_asset_ping_fn`: `(const char *host, float ms, void *user)`, `vifi` on wasm. **/
	public static inline function ping(dispatch:(host:CStr, milliseconds:F32, user:VoidStar) -> Void):AssetPingFn {
		#if cpp
		return cpp.Callable.fromStaticFunction(dispatch);
		#else
		if (pingPointer == 0)
			pingPointer = Raw.addFunction(dispatch, "vifi");
		return pingPointer;
		#end
	}
}
