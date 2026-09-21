package wgr.impl;

import cpp.ConstCharStar;
import cpp.UInt32;
import wgr.impl.Raw.VoidStar;
import wgr.impl.Raw.WgrHandle;

/**
	The guest ABI (`host/wgr_guest.h`) as C function pointers.

	Hand-written, and deliberately not in `Raw.cpp.hx`: that file is generated whole
	from wgrender's own headers, so anything added to it is lost on the next run. This
	header is ours, not wgrender's.
**/
typedef GuestInitFn = cpp.Callable<() -> Int>;
typedef GuestFrameFn = cpp.Callable<(dt:Single, frameId:UInt32) -> Int>;
typedef GuestAssetFn = cpp.Callable<(id:UInt32, path:ConstCharStar, ok:Int) -> Int>;
typedef GuestShutdownFn = cpp.Callable<() -> Int>;

@:keep @:unreflective @:include("wgr_guest.h")
extern class GuestRaw {
	@:native("wgr_guest_register")
	static function wgr_guest_register(init:GuestInitFn, frame:GuestFrameFn, asset:GuestAssetFn,
		shutdown:GuestShutdownFn):Void;
	@:native("wgr_guest_set_fault_policy")
	static function wgr_guest_set_fault_policy(policy:Int):Void;
	@:native("wgr_guest_start")
	static function wgr_guest_start(width:Int, height:Int, title:ConstCharStar, flags:UInt32):Int;
	@:native("wgr_guest_asset_load")
	static function wgr_guest_asset_load(path:ConstCharStar, id:UInt32):Int;
	@:native("wgr_guest_frame_id")
	static function wgr_guest_frame_id():UInt32;
	@:native("wgr_guest_faulted")
	static function wgr_guest_faulted():Int;
}
