// wgrender's particles example as a guest module — a port of examples/particles.c.
//
// Three 3D emitters in a scene: a fountain of blended drops under gravity, additive
// sparks from a source circling it (thrown along by it, slowed by drag, stretched
// along their motion), and a campfire — flipbook flames under smoke driven by size and
// colour curves. Click for a 2D confetti burst; space pauses the steady ones; O stops
// and restarts the camera's orbit.
//
// The second example on the wgrender-hx binding, and the reason for most of what it
// knows about emitters.
import wgr.*;

@:expose("WgrGuest")
class Particles {
	static inline final PARTICLE_PATH = "textures/particle.png";
	static inline final FLAME_PATH = "textures/flame.png"; // a 4x4 flipbook

	static inline final ASSET_PARTICLE = 1;
	static inline final ASSET_FLAME = 2;

	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 700;
	static inline final ORBIT_RADIUS = 16.0;
	static inline final ORBIT_SPEED = 0.15; // radians per second

	static var scene:Scene;
	static var camera:Camera3D;
	static var fountain:Emitter3D;
	static var sparks:Emitter3D;
	static var smoke:Emitter3D;
	static var flame:Emitter3D;
	static var confetti:Emitter2D;

	static var paused = false;
	static var orbit = true;
	static var orbitAngle = 0.0;
	static var elapsed = 0.0;
	static var background:Color = Color.BLACK;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Void {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "particles (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	// --- lifecycle ---

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		Log.setLevel(Warn);
		background = Color.rgba(14, 16, 24, 255);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(0, 6, 16), new Vec3(0, 3, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		load(PARTICLE_PATH, ASSET_PARTICLE);
		load(FLAME_PATH, ASSET_FLAME);
		Debug.enableFps(12, 10, 16);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('asset load failed: $path');
			return;
		}
		final texture = Texture.create(path);
		if (Texture.isNone(texture))
			return;
		switch id {
			case ASSET_PARTICLE:
				makeFountain(texture);
				makeSparks(texture);
				makeSmoke(texture);
				makeConfetti(texture);
				final screen = Window.getScreenSize();
				burst(new Vec2(screen.x * 0.5, screen.y * 0.4)); // one to start with

			case ASSET_FLAME:
				makeFlame(texture);
		}
		Texture.release(texture); // each emitter holds its own reference
	}

	// --- the emitters ---

	static function makeFountain(texture:Texture):Void {
		fountain = Emitter3D.create(texture);
		Emitter3D.setMax(fountain, 4096);
		Emitter3D.setRate(fountain, 1200);
		Emitter3D.setLife(fountain, 1.4, 1.9);
		Emitter3D.setPosition(fountain, new Vec3(0, 0.2, 0));
		Emitter3D.setSpawnBox(fountain, new Vec3(0.15, 0, 0.15));
		Emitter3D.setVelocity(fountain, new Vec3(0, 9, 0), 0.22, 0.15);
		Emitter3D.setGravity(fountain, new Vec3(0, -9.8, 0));
		Emitter3D.setSize(fountain, 0.22, 0.12, 0.4);
		Emitter3D.setColor(fountain, Color.rgba(150, 210, 255, 230), Color.rgba(60, 120, 255, 0));
		Emitter3D.setAlphaMode(fountain, Blend);
		Emitter3D.prewarm(fountain, 2.0); // already running when the page opens
		Scene.add(scene, fountain);
	}

	static function makeSparks(texture:Texture):Void {
		sparks = Emitter3D.create(texture);
		Emitter3D.setMax(sparks, 2048);
		Emitter3D.setRate(sparks, 600);
		Emitter3D.setLife(sparks, 0.5, 1.2);
		Emitter3D.setVelocity(sparks, new Vec3(0, 4, 0), 1.2, 0.6);
		Emitter3D.setGravity(sparks, new Vec3(0, -6, 0));
		Emitter3D.setDrag(sparks, 1.5); // they slow down
		Emitter3D.setInheritVelocity(sparks, 0.4); // thrown along by the moving source
		Emitter3D.setStretch(sparks, 0.04); // streaks along their motion
		Emitter3D.setSize(sparks, 0.08, 0.02, 0.5);
		Emitter3D.setColor(sparks, Color.rgba(255, 220, 120, 255), Color.rgba(255, 60, 10, 0));
		// Add is the default
		Scene.add(scene, sparks);
	}

	static function makeSmoke(texture:Texture):Void {
		smoke = Emitter3D.create(texture);
		Emitter3D.setMax(smoke, 512);
		Emitter3D.setRate(smoke, 30);
		Emitter3D.setLife(smoke, 3.0, 4.5);
		Emitter3D.setPosition(smoke, new Vec3(-5, 1.5, -2)); // above the fire
		Emitter3D.setSpawnSphere(smoke, 0.3);
		Emitter3D.setVelocity(smoke, new Vec3(0, 1.4, 0), 0.35, 0.3);
		Emitter3D.setGravity(smoke, new Vec3(0.35, 0, 0)); // a breeze
		Emitter3D.setSpin(smoke, -0.8, 0.8);
		// curves: a quick puff that keeps spreading; dark, then light, then gone
		Emitter3D.clearSizeKeys(smoke);
		Emitter3D.addSizeKey(smoke, 0.0, 0.3);
		Emitter3D.addSizeKey(smoke, 0.15, 1.4);
		Emitter3D.addSizeKey(smoke, 1.0, 3.6);
		Emitter3D.clearColorKeys(smoke);
		Emitter3D.addColorKey(smoke, 0.0, Color.rgba(40, 36, 34, 0));
		Emitter3D.addColorKey(smoke, 0.1, Color.rgba(50, 46, 44, 190));
		Emitter3D.addColorKey(smoke, 0.5, Color.rgba(130, 130, 140, 120));
		Emitter3D.addColorKey(smoke, 1.0, Color.rgba(170, 170, 180, 0));
		Emitter3D.setAlphaMode(smoke, Blend);
		Emitter3D.prewarm(smoke, 5.0);
		Scene.add(scene, smoke);
	}

	static function makeFlame(texture:Texture):Void {
		flame = Emitter3D.create(texture);
		Emitter3D.setFrames(flame, 4, 4);
		Emitter3D.setRate(flame, 40);
		Emitter3D.setLife(flame, 0.7, 1.1);
		Emitter3D.setPosition(flame, new Vec3(-5, 0.3, -2));
		Emitter3D.setSpawnSphere(flame, 0.3);
		Emitter3D.setVelocity(flame, new Vec3(0, 1.8, 0), 0.2, 0.3);
		Emitter3D.setDrag(flame, 0.8);
		Emitter3D.setSpin(flame, -1.5, 1.5);
		Emitter3D.clearSizeKeys(flame);
		Emitter3D.addSizeKey(flame, 0.0, 0.6);
		Emitter3D.addSizeKey(flame, 0.3, 1.1);
		Emitter3D.addSizeKey(flame, 1.0, 0.4);
		Emitter3D.clearColorKeys(flame);
		Emitter3D.addColorKey(flame, 0.0, Color.rgba(255, 235, 190, 0));
		Emitter3D.addColorKey(flame, 0.08, Color.rgba(255, 235, 190, 110));
		Emitter3D.addColorKey(flame, 0.25, Color.rgba(255, 150, 40, 100));
		Emitter3D.addColorKey(flame, 0.65, Color.rgba(200, 50, 15, 60));
		Emitter3D.addColorKey(flame, 1.0, Color.rgba(80, 15, 5, 0));
		Emitter3D.prewarm(flame, 1.0);
		Scene.add(scene, flame); // added: Add, the default
	}

	static function makeConfetti(texture:Texture):Void {
		confetti = Emitter2D.create(texture);
		Emitter2D.setSource(confetti, 24, 24, 16, 16); // the dot's solid middle: squares
		Emitter2D.setMax(confetti, 4096);
		Emitter2D.setLife(confetti, 1.2, 2.2);
		Emitter2D.setVelocity(confetti, new Vec2(0, -420), 1.3, 0.7);
		Emitter2D.setGravity(confetti, new Vec2(0, 700));
		Emitter2D.setDrag(confetti, 0.8); // flutters down instead of dropping
		Emitter2D.setSize(confetti, 12, 6, 0.5);
		Emitter2D.setSpin(confetti, -8, 8);
		Emitter2D.setColor(confetti, Color.WHITE, Color.rgba(255, 255, 255, 0));
		// each piece picks one of these at birth
		for (color in [Color.RED, Color.GOLD, Color.LIME, Color.SKYBLUE, Color.VIOLET])
			Emitter2D.addPaletteColor(confetti, color);
		Emitter2D.setAlphaMode(confetti, Blend);
		Scene.add(scene, confetti, 1);
	}

	static function burst(at:Vec2):Void {
		Emitter2D.jump(confetti, at);
		Emitter2D.burst(confetti, 300);
	}

	static function setPaused(value:Bool):Void {
		paused = value;
		for (emitter in [fountain, sparks, smoke, flame])
			if (!Emitter3D.isNone(emitter))
				Emitter3D.setEmitting(emitter, !value);
	}

	// --- frame ---

	static function onFrame(dt:Float):Void {
		elapsed += dt;

		// the sparks' source circles the fountain; the sparks stay where they were born
		if (!Emitter3D.isNone(sparks))
			Emitter3D.setPosition(sparks, new Vec3(3.5 * Math.cos(elapsed * 1.3), 1.5 + 0.8 * Math.sin(elapsed * 2.1),
				3.5 * Math.sin(elapsed * 1.3)));

		final mouse = Input.getMouseState();
		if (mouse.left == ButtonState.Pressed && !Emitter2D.isNone(confetti))
			burst(new Vec2(mouse.x, mouse.y));
		if (Input.isKeyPressed(Space) && !Emitter3D.isNone(fountain))
			setPaused(!paused);
		if (Input.isKeyPressed(O))
			orbit = !orbit;
		if (orbit)
			orbitAngle += dt * ORBIT_SPEED;
		Camera3D.setView(camera, new Vec3(ORBIT_RADIUS * Math.sin(orbitAngle), 6, ORBIT_RADIUS * Math.cos(orbitAngle)),
			new Vec3(0, 3, 0));

		Render.beginFrame();
		Render.clearBackground(background);

		Render.beginMode3D();
		Shape3D.drawGrid(24, 1.0, Color.DARKGRAY);
		Render.endMode3D();

		Scene.draw(scene);

		Text.draw("wgrender + sokol — particles, from Haxe", 12, 36, 24, Color.RAYWHITE);
		Text.draw('click / tap: confetti   space: ${paused ? "resume" : "pause"}   '
			+ 'O: ${orbit ? "stop" : "turn"} the camera', 12, 70, 16, Color.LIGHTGRAY);
		Text.draw('fountain ${Emitter3D.getCount(fountain)}   sparks ${Emitter3D.getCount(sparks)}   flame ${Emitter3D.getCount(flame)}   '
			+ 'smoke ${Emitter3D.getCount(smoke)}   confetti ${Emitter2D.getCount(confetti)}', 12, 94, 16, Color.LIGHTGRAY);

		Render.endFrame();

		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();
	}
}
