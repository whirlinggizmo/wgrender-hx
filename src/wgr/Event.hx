package wgr;

// wgr_event.h — a named event bus

/**
	A bus of named events. wgrender never emits on it itself: it is there so the
	parts of a program — and any C-side component alongside them — can tell each
	other things without knowing about each other.

	`emit` can carry a payload, because the bus does: a C-side component may be
	listening and may know what is behind the pointer. A Haxe listener is not handed
	it. That is partly because a `void *` is nothing a Haxe program can safely read,
	and partly because a Haxe closure taking a raw pointer does not compile on hxcpp
	4.3.2 -- the generated `__Run(Array<Dynamic>)` needs a `Dynamic` to `void *`
	conversion that it finds ambiguous. Reach for `wgr.impl.Raw` if you genuinely need
	the pointer; that is what it is for.

	Listening needs a C function pointer, so `on`, `once`, `off` and `emit` are hxcpp
	only — on js the guest ABI takes that role, and a guest that wants a bus of its
	own is better off with a Haxe one. `offAll` and `listenerCount` work on both.
**/
class Event {
	#if cpp
	static var listeners = new Map<Int, Registered>();
	static var nextId = 1;
	#end

	/** Drop every listener on `name`. Returns how many went, or -1 if there is no bus. **/
	public static inline function offAll(name:String):Int
		return Raw.wgr_event_off_all(name);

	/** How many listeners `name` has. **/
	public static inline function listenerCount(name:String):Int
		return Raw.wgr_event_listener_count(name);

	#if cpp
	/**
		Listen on `name` until dropped. The token that comes back is what `off` takes —
		not the function, because two Haxe closures over the same method are not
		reliably the same value on every target, and unsubscribing the wrong listener
		silently is worse than a token to keep.
	**/
	public static function on(name:String, listener:() -> Void):EventListener
		return register(name, listener, false);

	/** The same, dropped after it fires once. **/
	public static function once(name:String, listener:() -> Void):EventListener
		return register(name, listener, true);

	/** Drop one listener, by the token `on` or `once` returned. **/
	public static function off(listener:EventListener):Bool {
		final id = (listener : Int);
		final entry = listeners.get(id);
		if (entry == null)
			return false;
		listeners.remove(id);
		// off returns how many it removed, and -1 when there is no bus at all
		return Raw.wgr_event_off(entry.name, cpp.Callable.fromStaticFunction(trampoline),
			Native.toUser(id)) > 0;
	}

	/** Fire `name`. Returns how many listeners ran. **/
	public static inline function emit(name:String, ?payload:VoidStar):Int
		return Raw.wgr_event_emit(name, payload == null ? Native.nullPtr() : payload);

	static function register(name:String, listener:() -> Void, once:Bool):EventListener {
		final id = nextId++;
		listeners.set(id, new Registered(name, listener, once));
		// Branch rather than pick the function into a local: a reference to an extern
		// static is called dynamically on hxcpp, and `name` then reaches C boxed
		// instead of as a const char *, so the listener registers under a junk name.
		// These return 0 for success and -1 for failure, not a count like the rest.
		final fn = cpp.Callable.fromStaticFunction(trampoline);
		final added = once ? Raw.wgr_event_once(name, fn, Native.toUser(id)) : Raw.wgr_event_on(name, fn,
			Native.toUser(id));
		if (added != 0) {
			listeners.remove(id);
			return (0 : EventListener);
		}
		return (id : EventListener);
	}

	static function trampoline(payload:VoidStar, user:VoidStar):Void {
		// payload is deliberately not passed on; see the class docs

		final id = Native.fromUser(user);
		final entry = listeners.get(id);
		if (entry == null)
			return;
		// a `once` listener is gone from wgrender's side already, so drop ours with it
		if (entry.once)
			listeners.remove(id);
		try
			entry.fn()
		catch (e:haxe.Exception)
			Wgr.report('an event listener for "${entry.name}"', e);
	}
	#end
}

#if cpp
/**
	One registered listener. A named class rather than an anonymous structure: on
	hxcpp an anon's fields are read through `Dynamic`, and `entry.name` then reaches
	the C call as a `cpp::Variant` that won't convert to `const char *`.
**/
private class Registered {
	public final name:String;
	public final fn:() -> Void;
	public final once:Bool;

	public function new(name:String, fn:() -> Void, once:Bool) {
		this.name = name;
		this.fn = fn;
		this.once = once;
	}
}
#end
