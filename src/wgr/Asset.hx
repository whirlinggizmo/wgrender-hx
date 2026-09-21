package wgr;

#if cpp
import cpp.ConstCharStar;
#end

// wgr_asset.h — making a file local before it is loaded

class Asset {
	#if cpp
	static var pending = new Map<Int, {onSuccess:(path:String) -> Void, onFailure:(path:String) -> Void}>();
	static var nextId = 1;

	#end

	/** Where relative asset paths resolve from: a directory or a URL base. **/
	public static inline function setHost(host:String):Void
		Raw.wgr_asset_set_host(host);

	#if cpp
	/** A task to attach callbacks to (`AssetTask.then`); none on failure. **/
	public static inline function ensureAsync(path:String, ?fetchUrl:String, ?flags:AssetFlag):AssetTask
		return (Raw.wgr_asset_ensure_async(path, Native.cstr(fetchUrl), flags == null ? 0 : (flags : Int)) : Handle);

	@:allow(wgr.AssetTask)
	static function addTask(task:Handle, onSuccess:(path:String) -> Void, ?onFailure:(path:String) -> Void):Bool {
		final id = nextId++;
		pending.set(id, {onSuccess: onSuccess, onFailure: onFailure});
		final ok = Raw.wgr_asset_add_task(task, cpp.Callable.fromStaticFunction(successTrampoline),
			cpp.Callable.fromStaticFunction(failureTrampoline), Native.toUser(id)) == 0;
		if (!ok)
			pending.remove(id);
		return ok;
	}

	// One callback per task, then the task is gone — so drop the closures here.
	static function finish(user:VoidStar, path:ConstCharStar, success:Bool):Void {
		final id = Native.fromUser(user);
		final entry = pending.get(id);
		if (entry == null)
			return;
		pending.remove(id);
		final cb = success ? entry.onSuccess : entry.onFailure;
		if (cb == null)
			return;
		try
			cb(path.toString())
		catch (e:haxe.Exception)
			Wgr.report('an asset callback for "${path.toString()}"', e);
	}

	static function successTrampoline(path:ConstCharStar, user:VoidStar):Void
		finish(user, path, true);

	static function failureTrampoline(path:ConstCharStar, user:VoidStar):Void
		finish(user, path, false);
	#end
}
