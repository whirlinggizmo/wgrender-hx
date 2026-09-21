package wgr;

// wgr_asset.h

/** Asset flags, or-ed together. **/
enum abstract AssetFlag(Int) to Int {
	/** Re-download even if cached. **/
	var ForceFetch = 1 << 0;

	/** Only make the file local; don't load the resource it names. **/
	var FileOnly = 1 << 1;

	@:op(A | B)
	public static inline function or(a:AssetFlag, b:AssetFlag):AssetFlag
		return cast((a : Int) | (b : Int));
}
