package wgr;

// wgr_asset.h

/**
	A pending "make this file local" task. Attach callbacks with `then`; wgrender
	fires exactly one of them on the main thread during a later frame, then frees
	the task.
**/
abstract AssetTask(Handle) from Handle to Handle {
	public var isNone(get, never):Bool;

	@:to inline function toRaw():WgrHandle
		return (this : Int);

	inline function get_isNone():Bool
		return (this : Handle).isNone;

	/**
		`wgr_asset_add_task`. False (and no callback) if the task is invalid or the
		queue is full.
	**/
	public inline function then(onSuccess:(path:String) -> Void, ?onFailure:(path:String) -> Void):Bool
		return Asset.addTask(cast this, onSuccess, onFailure);
}
