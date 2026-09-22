package wgr;

#if cpp
import cpp.ConstCharStar;
#end

// shared plumbing: the null pointers, the user-pointer table key, and cstr
//
// Both targets, because the callback plumbing above it is written once. On js every
// one of these is the identity or a constant -- a pointer is an Int there -- so the
// js half exists to let a shared signature compile, not to do anything.

#if cpp

/** Small helpers the wrappers need to reach C from Haxe. **/
@:noCompletion
@:cppFileCode('#include <stdint.h>')
class Native {
	/** A `void *` / `const char *` null that survives hxcpp's type checking. **/
	public static inline function nullPtr():VoidStar {
		return untyped __cpp__("nullptr");
	}

	public static inline function nullStr():ConstCharStar {
		return untyped __cpp__("(const char *)nullptr");
	}

	/** wgrender's callbacks carry a `void *`; we carry a table key in it. **/
	public static inline function toUser(id:Int):VoidStar {
		return untyped __cpp__("(void *)(intptr_t)({0})", id);
	}

	public static inline function fromUser(user:VoidStar):Int {
		return untyped __cpp__("(int)(intptr_t)({0})", user);
	}

	public static inline function cstr(s:String):ConstCharStar {
		return s == null ? nullStr() : ConstCharStar.fromString(s);
	}
}

#else

/** The js half: on wasm a pointer is an Int, so none of this has work to do. **/
@:noCompletion
class Native {
	public static inline function nullPtr():VoidStar
		return 0;

	public static inline function nullStr():CStr
		return 0;

	/** The table key rides in the `void *` as itself. **/
	public static inline function toUser(id:Int):VoidStar
		return id;

	public static inline function fromUser(user:VoidStar):Int
		return user;

	/** `Raw.cstr` does this on js, into the op's arena; this is for a shared signature. **/
	public static inline function cstr(s:String):CStr
		return Raw.cstr(s);
}
#end
