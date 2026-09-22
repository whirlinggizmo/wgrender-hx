package wgr.flat;

/**
	`isNone` as a free static, which a flat API needs and an abstract's property cannot
	give it.

	`h == 0` and `h == Handle.NONE` are both wrong on js for a field that was never
	assigned: an uninitialised field is `undefined`, and `undefined == 0` is `false`, so
	both report a handle for something that holds nothing. They compile, and they are
	right on hxcpp and right on js for a field that *was* assigned, which is exactly
	what makes them worth naming. The typed abstract does not prevent it either — the 0
	promotes at `Int` -> `Handle` -> `Model`, so an operator overload on `Handle` never
	sees the comparison.

	So flattening costs discoverability here, not correctness: `m.isNone` shows up in
	autocomplete after a dot and `Handles.isNone(m)` does not. Both compile to the same
	two comparisons.

	Named `Handles` only because `wgr.Handle` still carries the instance property during
	the trial, and Haxe will not take a static of the same name beside it. If the flat
	shape wins, this is `Handle.isNone(h)`.
**/
class Handles {
	public static inline function isNone(handle:Handle):Bool
		#if js
		return (handle : Int) == null || (handle : Int) == 0;
		#else
		return (handle : Int) == 0;
		#end

	public static inline function isValid(handle:Handle):Bool
		return !isNone(handle);

	/** What this handle refers to; `None` for a none handle. **/
	public static inline function kind(handle:Handle):HandleKind
		return handle.kind;
}
