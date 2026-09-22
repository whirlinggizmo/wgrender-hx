package wgr;

#if cpp
import cpp.ConstCharStar;
#end

// wgr_asset.h — making a file local before it is loaded

class Asset {
	// The key every callback carries in its `void *`, and the tables it looks up in.
	// Shared, because a ping crosses on both targets now; `pending` and `fetcher`
	// belong to the two calls that are still hxcpp only.
	static var nextId = 1;
	static var pings = new Map<Int, (host:String, ms:Float) -> Void>();

	#if cpp
	static var pending = new Map<Int, {onSuccess:(path:String) -> Void, onFailure:(path:String) -> Void}>();
	static var fetcher:(request:Handle, url:String, destPath:String) -> Void;
	#end

	/**
		Where relative asset paths resolve from. A URL ("https://host/assets") is a
		fetch origin on both platforms: a missing file is downloaded from it and cached,
		by the browser on the web and by your fetcher on desktop. Anything else is a
		local directory. Pass the same logical paths everywhere; only the base differs.
	**/
	public static var host(get, set):String;

	/**
		Milliseconds per frame spent finishing loads on the main thread — GPU uploads.
		4 by default. At least one step runs each frame, so one large texture can
		overrun it: a 4096x4096 texture is a single upload of about 45 ms.
	**/
	public static var uploadBudget(never, set):Float;

	static inline function get_host():String
		return Raw.wgr_asset_get_host();

	static inline function set_host(v:String):String {
		Raw.wgr_asset_set_host(v);
		return v;
	}

	static inline function set_uploadBudget(v:Float):Float {
		Raw.wgr_asset_set_upload_budget(v);
		return v;
	}

	/** Where relative asset paths resolve from: a directory or a URL base. **/
	public static inline function setHost(host:String):Void
		Raw.wgr_asset_set_host(host);

	/**
		Where downloads land on desktop, and where later runs find them — created as
		needed. `.wgr-cache` by default. Ignored on the web, which caches in the
		browser. Set it before the first `host` that is a URL.
	**/
	public static inline function setCacheDir(dir:String):Bool
		return Raw.wgr_asset_set_cache_dir(dir);

	/**
		Forget a cached asset, so the next ensure fetches it again. A cache can hold a
		file that is wrong rather than missing — a host that compresses once served gzip
		bytes under an asset's name — and a wrong file is read in preference to the
		network for good unless something drops it. wgrender drops an entry itself when
		a loader rejects a cached file, so this is for a program that knows better: a
		new version of an asset, or a user asking to free the space.
	**/
	public static inline function evict(path:String):Bool
		return Raw.wgr_asset_evict(path);

	/**
		Tell wgrender a fetch finished. Only a fetcher set with `setFetcher` is handed a
		`request` to report on, so this is for hxcpp; finishing on a later tick is
		expected, and nothing blocks meanwhile.
	**/
	public static inline function fetchDone(request:Handle, ok:Bool):Bool
		return Raw.wgr_asset_fetch_done(request, ok);

	public static inline function clearCache():Void
		Raw.wgr_asset_clear_cache();

	/**
		Load files whose path starts with `prefix` from under `target` instead — mods,
		translations, a CDN. A `target` containing "://" is where the file downloads
		from — the browser on the web, your fetcher on desktop — and it is still cached
		and loaded under its own path.

		Path rules stack: every one matching a file is tried, the one added last first,
		then the file's own path, so later rules sit on top. A miss under a path rule
		isn't an error, just the next rule (on the web that costs a request). Download
		rules don't stack — the newest one matching wins. Prefixes are plain text
		matched at the start of the path, not globs. Up to 32 rules.
	**/
	public static inline function addRedirect(prefix:String, target:String):Bool
		return Raw.wgr_asset_add_redirect(prefix, target);

	public static inline function clearRedirects():Void
		Raw.wgr_asset_clear_redirects();

	/**
		Roughly how far a task or group has got, 0 to 1, for a loading screen. A file
		counts a quarter each for being fetched, for its dependencies, for being
		prepared and for being finished, and reads 1 once the task has completed and
		its handle is no longer live.
	**/
	public static inline function getProgress(task:AssetTask):Float
		return Raw.wgr_asset_get_progress(task);

	/**
		One task standing for many files — a level, or a loading screen. It completes
		when all its members have, successfully only if they all did, and then fires its
		own callbacks with an empty path. Members keep their own callbacks if they have
		any. The group holds its members' resources until its callbacks have run, so
		they can be created there.
	**/
	public static inline function createGroup():AssetTask
		return (Raw.wgr_asset_group_create() : Handle);

	/** Add a file task to a group. False for anything else, or a task already in one. **/
	public static inline function groupAdd(group:AssetTask, task:AssetTask):Bool
		return Raw.wgr_asset_group_add(group, task);

	/**
		Make a file local, then report. Returns a task to watch or attach callbacks to,
		or none on failure.

		`path` is the logical key: the cache path on the web, the read path under the
		host on desktop, and where a fetched file lands. `fetchUrl` overrides only where
		it downloads *from* — a mirror or a signed link, used verbatim — and leaving it
		null means the host plus the path, with redirects and per-device variants
		applied. Null is not the same as "": passing a URL tells wgrender the caller
		chose this exact file.

		On desktop a `fetchUrl` needs a fetcher (`setFetcher`) but not a URL host: a
		task told where to download from downloads from there.
	**/
	public static inline function ensureAsync(path:String, ?fetchUrl:String, ?flags:AssetFlag):AssetTask
		return (Raw.wgr_asset_ensure_async(path, #if cpp Native.cstr(fetchUrl) #else fetchUrl #end,
			flags == null ? 0 : (flags : Int)) : Handle);

	/**
		Time the round trip to an asset host: `onDone` fires on a later frame with the
		milliseconds, or a negative number when it couldn't be reached inside
		`timeoutMs` (0 or less means 5000). A null `host` pings the current one.

		On the web it is a HEAD request, and any response counts, even a 404. On desktop
		the host is a local directory: 0 if it exists, negative if not — a URL host
		can't be pinged there, since the fetcher hook deals in files rather than round
		trips, so time an `ensureAsync` instead. False when eight pings are already
		waiting.
	**/
	public static function pingHost(?host:String, timeoutMs:Int = 0, onDone:(host:String, ms:Float) -> Void):Bool {
		final id = nextId++;
		pings.set(id, onDone);
		final ok = Raw.wgr_asset_ping_host(#if cpp Native.cstr(host) #else host #end, timeoutMs,
			Trampoline.ping(pingTrampoline), Native.toUser(id));
		if (!ok)
			pings.remove(id);
		return ok;
	}

	// One ping per call, so drop the closure as it fires.
	static function pingTrampoline(host:CStr, milliseconds:F32, user:VoidStar):Void {
		final id = Native.fromUser(user);
		final cb = pings.get(id);
		if (cb == null)
			return;
		pings.remove(id);
		try
			cb(#if cpp host.toString() #else Raw.str(host) #end, milliseconds)
		catch (e:haxe.Exception)
			Wgr.report("an asset ping callback", e);
	}

	#if cpp
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

	/**
		Download a missing asset. wgrender calls `fetch` when a file isn't local yet,
		there is somewhere to download it from, and the platform has no downloader of
		its own — which is every desktop build. Somewhere to download from means a URL
		`host`, or a source this task was handed outright: a `fetchUrl` passed to
		`ensureAsync`, or a redirect target containing "://". Fetch the URL into the
		destination path, then call `fetchDone` with the same request and whether it
		worked; finishing on a later tick is expected, and nothing blocks meanwhile.

		Bytes never cross this boundary: a downloader deals in files, which is what
		curl, WinHTTP and NSURLSession all hand you anyway, and the directories above
		the destination already exist.

		Without one, a miss on desktop fails as it always has. hxcpp only — the web has
		the browser.
	**/
	public static function setFetcher(fetch:(request:Handle, url:String, destPath:String) -> Void):Bool {
		fetcher = fetch;
		return Raw.wgr_asset_set_fetcher(cpp.Callable.fromStaticFunction(fetchTrampoline), Native.nullPtr());
	}

	static function fetchTrampoline(request:WgrHandle, url:ConstCharStar, destPath:ConstCharStar,
			user:VoidStar):Void {
		if (fetcher == null)
			return;
		try
			fetcher((request : Handle), url.toString(), destPath.toString())
		catch (e:haxe.Exception) {
			Wgr.report('the asset fetcher for "${url.toString()}"', e);
			Raw.wgr_asset_fetch_done(request, false);
		}
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
