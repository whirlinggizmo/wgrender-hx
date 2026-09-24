// wgrender simple, as a guest module: the same scene as ../simple/src/Simple.hx, but
// compiled to JS and run on top of the wgrender wasm host rather than inside it.
//
// The differences from the hxcpp port are all at the edges — how the lifecycle is
// entered (the guest ABI, not wgr_set_init/wgr_set_frame), and how assets are
// requested (an id the host hands back, not a closure). The scene code between those
// edges is the same, against the same wgr.Wgr layer.
import wgr.*;

@:expose("WgrGuest")
class Guest {
	static inline final DEBUG_FONT_PATH = "fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
	static inline final KOMIKA_FONT_PATH = "fonts/Komika/KOMIKAH_.ttf";
	static inline final MODEL_PATH = "models/gumshoe/gumshoe.glb";
	static inline final SPRITE_PATH = "sprites/logo/wg-logo-bw-alpha.png";
	static inline final BGM_PATH = "music/ethernight_club.mp3";

	// The host hands these back on the asset op, in place of a callback.
	static inline final ASSET_BGM = 1;
	static inline final ASSET_MODEL = 2;
	static inline final ASSET_SPRITE = 3;
	static inline final ASSET_DEBUG_FONT = 4;
	static inline final ASSET_KOMIKA_FONT = 5;

	static inline final SCREEN_WIDTH = 1024;
	static inline final SCREEN_HEIGHT = 1280;
	static inline final DEBUG_FONT_SIZE = 18;
	static inline final KOMIKA_FONT_SIZE = 24;

	static inline final SPRITE_Y_OFFSET = 3.0;
	static inline final BOB_SPEED = 1.0;
	static inline final BOB_HEIGHT = 1.5;

	static var elapsed = 0.0;
	static var countdownTimer = 0.0;
	static var debugFont:Font;
	static var greyAlpha:Color = Color.BLACK;
	static var komikaFont:Font;
	static var sprite:Sprite3D;
	static var model:Model;
	static var bgm:Sound;
	static var camera:Camera3D;
	static var scene:Scene;
	static var backgroundColor:Color = Color.RAYWHITE;
	static var message = "";
	static var platformText = "";

	/**
		On desktop this is the entry point and `autostart` runs the guest now; on the
		web the page owns startup, so `autostart` does nothing and web/boot.js calls
		`start` once the host module has loaded.
	**/
	static function main():Void {
		GuestAbi.autostart(start);
	}

	// --- the guest ABI (host/wgr_guest.h) ---

	/**
		Register the ops, then start the host. `wgr.GuestAbi` is per-target — the JS
		one installs them through `addFunction` on the Emscripten module, the hxcpp one
		through plain function pointers — so nothing below this line is target-specific.
	**/
	public static function start(host:Dynamic):Void {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "simple (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	// --- lifecycle ---

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		Log.setLevel(Warn);
		Wgr.setTargetFps(60);

		countdownTimer = 30.0;
		message = "Hello from wgrender simple (Haxe guest)!";
		platformText = 'Platform: ${Wgr.getPlatform()}';

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(12, 12, 12), new Vec3(0, 1, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.6, -1.0, -0.5));
		Light.setIntensity(sun, 3.0);
		Scene.add(scene, sun);
		Scene.setAmbient(scene, Color.WHITE, 0.25);
		backgroundColor = Color.rgba(245, 245, 245, 255);
		greyAlpha = Color.rgba(0, 0, 0, 128);

		load(BGM_PATH, ASSET_BGM);
		load(MODEL_PATH, ASSET_MODEL);
		load(SPRITE_PATH, ASSET_SPRITE);
		load(DEBUG_FONT_PATH, ASSET_DEBUG_FONT);
		load(KOMIKA_FONT_PATH, ASSET_KOMIKA_FONT);
	}

	// The path is local and ready; create the resource, then the object.
	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('failed to import asset: $path');
			return;
		}
		switch id {
			case ASSET_BGM:
				final audio = Audio.create(path);
				bgm = Sound.create(audio);
				Audio.release(audio); // the sound holds its own reference
				Sound.setLoop(bgm, true);
				Sound.play(bgm);

			case ASSET_MODEL:
				final mesh = Mesh.create(path);
				model = Model.create(mesh);
				Mesh.release(mesh); // the model holds its own reference
				Model.setAnimation(model, 1);
				Model.setAnimationSpeed(model, 1.0);
				Model.setAnimationLoop(model, true);
				Model.setPosition(model, new Vec3(0, 0, 0));
				Model.setTint(model, Color.RAYWHITE);
				Scene.add(scene, model);

			case ASSET_SPRITE:
				final texture = Texture.create(path);
				sprite = Sprite3D.create(texture);
				Texture.release(texture); // the sprite holds its own reference
				Sprite3D.setFacing(sprite, Free);
				Sprite3D.setPosition(sprite, new Vec3(0, SPRITE_Y_OFFSET, 0));
				Sprite3D.setTint(sprite, Color.RAYWHITE);
				Scene.add(scene, sprite);

			case ASSET_DEBUG_FONT:
				debugFont = Font.create(path);

			case ASSET_KOMIKA_FONT:
				komikaFont = Font.create(path);
		}
	}

	static function update(dt:Float):Void {
		elapsed += dt;
		countdownTimer -= dt;

		if (!Model.isNone(model))
			Model.animate(model, dt);
		if (!Sprite3D.isNone(sprite)) {
			final y = Math.sin(elapsed * BOB_SPEED) * BOB_HEIGHT + SPRITE_Y_OFFSET;
			Sprite3D.setPosition(sprite, new Vec3(0, y, 0));
		}
	}

	static function updatePickMessage(mouse:MouseState):Void {
		final pick = Scene.pick(scene, mouse.x, mouse.y);
		final what = if (!pick.hit) "" else if (pick.handle == model) "Model" else if (pick.handle == sprite)
			"Sprite" else "";
		if (what == "") {
			message = "Nothing picked!";
			return;
		}
		message = '$what pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) '
			+ 'pick result y: ${fixed(pick.pointWorld.y, 6)}';
	}

	static function drawText(font:Font, text:String, x:Float, y:Float, size:Int, color:Color):Void {
		if (!Font.isNone(font))
			Font.draw(font, text, x, y, size, color);
		else
			Text.draw(text, Std.int(x), Std.int(y), size, color);
	}

	static function drawCenteredMessage():Void {
		final screen = Window.getScreenSize();
		final size = !Font.isNone(komikaFont) ? Font.measure(komikaFont, message,
			KOMIKA_FONT_SIZE) : new Vec2(Text.measure(message, KOMIKA_FONT_SIZE), KOMIKA_FONT_SIZE);
		drawText(komikaFont, message, (screen.x - size.x) / 2, (screen.y - size.y) / 2, KOMIKA_FONT_SIZE, Color.BLUE);
	}

	static function drawOverlay(mouse:MouseState):Void {
		drawText(debugFont, 'Remaining: ${fixed(countdownTimer, 2)}', 10, 36, DEBUG_FONT_SIZE, Color.BLACK);
		drawText(debugFont, 'Elapsed: ${fixed(elapsed, 2)}', 10, 56, DEBUG_FONT_SIZE, Color.BLACK);
		drawText(debugFont, 'Mouse: (${mouse.x}, ${mouse.y}) w:${fixed(mouse.wheel, 1)} '
			+ 'b:[${mouse.left}, ${mouse.right}, ${mouse.middle}]', 10, 76, DEBUG_FONT_SIZE, Color.BLACK);
		drawText(debugFont, platformText, 10, 96, DEBUG_FONT_SIZE, Color.BLACK);

		Font.drawFps(debugFont, 10, 10, DEBUG_FONT_SIZE, greyAlpha);
	}

	static function onFrame(dt:Float):Void {
		final mouse = Input.getMouseState();

		update(dt);
		updatePickMessage(mouse);

		Render.beginFrame();
		Render.clearBackground(backgroundColor);
		Scene.draw(scene);
		drawCenteredMessage();
		drawOverlay(mouse);
		Render.endFrame();
	}

	/** The same by-hand formatter ../simple uses, so the two read alike. **/
	static function fixed(value:Float, decimals:Int):String {
		final negative = value < 0;
		var digits = Std.string(Math.round(Math.abs(value) * Math.pow(10, decimals)));
		while (digits.length <= decimals)
			digits = "0" + digits;
		final point = digits.length - decimals;
		return (negative ? "-" : "") + digits.substr(0, point) + (decimals > 0 ? "." + digits.substr(point) : "");
	}
}
