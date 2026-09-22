// wgrender's fetch example, as a Haxe guest: the desktop build downloads what the
// browser downloads.
//
// A port of examples/fetch.c. On the web the browser fetches a missing asset and
// caches it. On desktop wgrender ships no HTTP client and no TLS, so it asks the
// program for one: set a URL as the asset host, hand it a fetcher, and a cache miss
// becomes a download.
//
//     Asset.setCacheDir("build/asset-cache");
//     Asset.setHost("https://.../examples/assets");
//     Asset.setFetcher((request, url, destPath) -> ...);
//
// This one is `haxe.Http`, which does HTTPS on hxcpp out of the standard library:
// hxcpp builds its bundled mbedtls for `sys.ssl.Socket` the first time something asks
// for it. No subprocess and nothing on PATH, so it behaves the same on Windows.
//
// It costs a megabyte. Measured on Linux x64: 3,526,728 bytes with curl against
// 4,595,952 with mbedtls linked, +30%. That trade is the reason the hook exists at
// all -- wgrender links no HTTP and no TLS, so the program decides whether to pay for
// a TLS stack, shell out to something that already has one (what examples/fetch.c
// does, since C has nothing in the box), or use a platform client like WinHTTP or
// NSURLSession. None of those choices reaches the library.
//
// It is synchronous, which is fine for a few small files and would hitch a frame on a
// big one; the hook is built for the other way round -- start a download, call
// `Asset.fetchDone` from a later tick, block nothing meanwhile.
//
// Bytes never cross the boundary. wgrender names a URL and a destination file and the
// fetcher writes that file, which is what curl, WinHTTP and NSURLSession all hand you
// anyway. Downloads land in the cache directory and the next run finds them there,
// which is the job the browser's cache does on the web.
//
// The guards here are Haxe's, not wgrender's, and that distinction is the point.
// `Asset.setFetcher` compiles on both targets and answers false on the web, where
// there is nothing to install -- the browser is the downloader. What needs `#if sys`
// is reading an environment variable and running curl, which are facts about the
// standard library rather than about the binding.
//
//   ESC  quit
import wgr.*;

@:expose("WgrGuest")
class Fetch {
	static inline final SCREEN_WIDTH = 1024;
	static inline final SCREEN_HEIGHT = 640;
	static inline final TEXTURE_PATH = "sprites/logo/wg-logo-white-alpha.png";
	static inline final ASSET_TEXTURE = 1;
	static inline final CACHE_DIR = "build/asset-cache";
	static inline final DEFAULT_HOST =
		"https://raw.githubusercontent.com/whirlinggizmo/wgrender-c/main/examples/assets";

	static var background:Color;
	static var sprite:Sprite2D;
	static var camera:Camera3D;
	static var host = "";
	static var remote = false;
	static var downloads = 0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(hostModule:Dynamic):Bool {
		GuestAbi.attach(hostModule);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "fetch (wgrender host, Haxe guest)", Resizable);
	}

	static function onInit():Void {
		background = Color.rgba(28, 30, 38, 255);
		camera = new Camera3D(Perspective);
		sprite = new Sprite2D(Handle.NONE); // the texture is attached when it loads
		sprite.position = new Vec2(512, 380);
		Debug.enableFps(12, 10, 16);

		#if sys
		// Native: pick a host, check something is serving there, and install a
		// downloader. Sys.getEnv and Sys.command are what need the guard -- they are
		// Haxe's, not wgrender's -- while Asset.setFetcher compiles either way.
		final wanted = Sys.getEnv("WGRENDER_ASSET_HOST");
		host = wanted != null ? wanted : DEFAULT_HOST;
		remote = hostIsUp(host);
		if (remote) {
			Asset.setCacheDir(CACHE_DIR);
			Asset.setFetcher(fetchWithHttp);
		} else {
			host = Assets.defaultBase(); // the local directory
		}
		#else
		host = Assets.defaultBase(); // the browser fetches
		remote = true;
		#end
		Asset.setHost(host);

		if (!GuestAbi.loadAsset(TEXTURE_PATH, ASSET_TEXTURE))
			Log.error('failed to queue asset: $TEXTURE_PATH');
	}

	#if sys
	/** Download `url` to `destPath`, then say how it went. A real one would not block. **/
	static function fetchWithHttp(request:Handle, url:String, destPath:String):Void {
		var ok = false;
		final http = new haxe.Http(url);
		// onBytes, not onData: onData is a String and these are images and audio.
		http.onBytes = bytes -> {
			sys.io.File.saveBytes(destPath, bytes);
			downloads++;
			ok = true;
		};
		http.onError = e -> Log.error('fetch failed: $url ($e)');
		http.request(false);
		// wgrender is told either way; a false is what makes the asset fail rather
		// than wait forever.
		Asset.fetchDone(request, ok);
	}

	/** Is anything serving there? Keeps an offline run, and a forgetful human, honest. **/
	static function hostIsUp(host:String):Bool {
		var up = false;
		final http = new haxe.Http('$host/$TEXTURE_PATH');
		http.cnxTimeout = 2; // per request, so an offline run gives up quickly
		http.onStatus = status -> up = status >= 200 && status < 400;
		http.onError = _ -> up = false;
		try
			http.request(false)
		catch (_:Dynamic)
			up = false;
		return up;
	}
	#end

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('could not get $path');
			return;
		}
		if (id != ASSET_TEXTURE)
			return;
		final texture = Texture.create(path);
		sprite.setTexture(texture);
		texture.release(); // the sprite holds its own reference
	}

	static function onFrame(dt:Float):Void {
		Render.begin();
		Render.clearBackground(background);
		sprite.draw();
		Text.draw("wgrender fetch: the desktop build downloads what the browser downloads", 12, 36, 20,
			Color.RAYWHITE);
		Text.draw('host: $host', 12, 64, 16, Color.LIGHTGRAY);
		#if sys
		Text.draw(remote ? 'downloaded $downloads file(s) into $CACHE_DIR   (delete it and re-run: they come back)'
			: 'no host reachable — reading ${Assets.defaultBase()} locally instead', 12, 86, 16, Color.LIGHTGRAY);
		#end
		Render.end();

		if (Input.getKeyboardState().isPressed(Escape))
			Wgr.requestQuit();
	}
}
