package wgr;

// wgr_event.h

/** What `Event.on` hands back, for `Event.off` to take. A zero token never listened. **/
abstract EventListener(Int) from Int to Int {
	public var isNone(get, never):Bool;

	inline function get_isNone():Bool
		#if js
		return this == null || this == 0;
		#else
		return this == 0;
		#end
}
