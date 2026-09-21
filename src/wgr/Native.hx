package wgr;

#if cpp
import cpp.ConstCharStar;
#end

// shared plumbing: the null pointers, the user-pointer table key, and cstr

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
