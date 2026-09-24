// wgrender's postprocess example, as a Haxe guest: screen effects over the frame.
//
// A port of examples/postprocess.c. Two effects, each a custom shader wrapped in a
// material and handed to `Render.addEffect`, applied to the finished frame in the
// order they were added:
//
//   vignette    darkens the edges, with a strength you can change every frame
//   scanlines   a CRT-ish overlay
//
// The point is that an effect is just a `Material`: its parameters are set the same
// way a model's are, so `strength` can breathe with a sine wave and nothing special
// has to happen. `Render.clearEffects` and re-adding is how the chain is rebuilt.
//
//   1 2      toggle each effect
//   UP/DOWN  vignette strength
//   SPACE    make the strength breathe
//   O        stop the camera
//   ESC      quit
//
// The shaders are `.wgrshader` files, compiled from examples/shaders/*.glsl by
// wgrender's tools/shaderpack.py (`make example-shaders`) and shipped in its assets.
import wgr.*;

@:expose("WgrGuest")
class Postprocess {
	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 640;
	static inline final GUMSHOE_PATH = "models/gumshoe/gumshoe.glb";
	static inline final VIGNETTE_PATH = "shaders/vignette.wgrshader";
	static inline final SCANLINES_PATH = "shaders/scanlines.wgrshader";

	static inline final ASSET_GUMSHOE = 1;
	static inline final ASSET_VIGNETTE = 2;
	static inline final ASSET_SCANLINES = 3;

	static var scene:Scene;
	static var camera:Camera3D;
	static var target:Vec3;
	static var lamp:Light;
	static var lampMarker:Shape3D;
	static var gumshoe:Model;
	static var torus:Model;
	static var vignette:Material;
	static var scanlines:Material;

	static var vignetteOn = true;
	static var scanlinesOn = true;
	static var breathing = true;
	static var orbit = true;
	static var strength = 0.75;
	static var angle = 0.0;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "postprocess (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		target = new Vec3(0, 1.0, 0);
		camera = Camera3D.create(Perspective);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);
		Scene.setAmbient(scene, Color.rgba(90, 110, 160, 255), 0.12);

		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.4, -1.0, -0.5));
		Light.setColor(sun, Color.rgba(255, 215, 170, 255));
		Light.setIntensity(sun, 2.2);
		Scene.add(scene, sun);

		lamp = Light.create(Point);
		Light.setColor(lamp, Color.rgba(80, 220, 255, 255));
		Light.setIntensity(lamp, 18.0);
		Light.setRange(lamp, 6.0);
		Scene.add(scene, lamp);
		lampMarker = Shape3D.create();
		Shape3D.setSphere(lampMarker, 0.1);
		Shape3D.setColor(lampMarker, Color.rgba(80, 220, 255, 255));
		Scene.add(scene, lampMarker);

		addScenery();

		gumshoe = Model.create(Handle.NONE);
		Model.setPosition(gumshoe, new Vec3(0, 0, 0));
		Scene.add(scene, gumshoe);

		load(GUMSHOE_PATH, ASSET_GUMSHOE);
		load(VIGNETTE_PATH, ASSET_VIGNETTE);
		load(SCANLINES_PATH, ASSET_SCANLINES);
		Debug.enableFps(12, 10, 16);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function addScenery():Void {
		final plane = Mesh.plane(16.0, 16.0, 0);
		final floor = Model.create(plane);
		Mesh.release(plane);
		final ground = Material.create(Pbr);
		Material.setBaseColor(ground, 0.07, 0.07, 0.08, 1.0);
		Material.setRoughness(ground, 0.85);
		Model.setMaterial(floor, -1, ground);
		Material.release(ground);
		Scene.add(scene, floor);

		final shapes = [
			{mesh: Mesh.sphere(0.5, 24, 48), x: -2.2, y: 0.5, r: 0.2, g: 0.55, b: 0.9},
			{mesh: Mesh.torus(0.45, 0.16, 48, 24), x: 2.2, y: 0.7, r: 0.95, g: 0.6, b: 0.25},
			{mesh: Mesh.cube(0.8, 0.8, 0.8), x: 3.6, y: 0.4, r: 0.35, g: 0.85, b: 0.5}
		];
		for (i in 0...shapes.length) {
			final s = shapes[i];
			final model = Model.create(s.mesh);
			Mesh.release(s.mesh);
			Model.setPosition(model, new Vec3(s.x, s.y, -0.6));
			final material = Material.create(Pbr);
			Material.setBaseColor(material, s.r, s.g, s.b, 1.0);
			Material.setRoughness(material, 0.4);
			Model.setMaterial(model, 0, material);
			Material.release(material);
			Scene.add(scene, model);
			if (i == 1)
				torus = model; // the one that tumbles
		}
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_GUMSHOE:
				final mesh = Mesh.create(path);
				Model.setMesh(gumshoe, mesh);
				Mesh.release(mesh);
				Model.setAnimation(gumshoe, 3);
				Model.setAnimationLoop(gumshoe, true);

			case ASSET_VIGNETTE:
				final shader = Shader.create(path);
				vignette = Material.custom(shader);
				Shader.release(shader); // the material holds its own reference
				Material.setFloat(vignette, "strength", strength);
				Material.setFloat(vignette, "radius", 0.25);
				Material.setVec4(vignette, "tint", 1.04, 1.0, 0.94, 1.0);
				rebuildEffects();

			case ASSET_SCANLINES:
				final shader = Shader.create(path);
				scanlines = Material.custom(shader);
				Shader.release(shader);
				Material.setFloat(scanlines, "lines", 220.0);
				Material.setFloat(scanlines, "darkness", 0.35);
				Material.setFloat(scanlines, "offset", 1.5);
				Material.setFloat(scanlines, "flicker", 1.0);
				rebuildEffects();
		}
	}

	/** The chain is rebuilt whole rather than edited: clear, then add what is on. **/
	static function rebuildEffects():Void {
		Render.clearEffects();
		if (vignetteOn && !Material.isNone(vignette))
			Render.addEffect(vignette);
		if (scanlinesOn && !Material.isNone(scanlines))
			Render.addEffect(scanlines);
	}

	static function handleKeys(dt:Float):Void {
		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();
		if (Input.isKeyPressed(Digit1)) {
			vignetteOn = !vignetteOn;
			rebuildEffects();
		}
		if (Input.isKeyPressed(Digit2)) {
			scanlinesOn = !scanlinesOn;
			rebuildEffects();
		}
		if (Input.isKeyPressed(Space))
			breathing = !breathing;
		if (Input.isKeyPressed(O))
			orbit = !orbit;
		if (Input.isKeyDown(Up))
			strength = Math.min(strength + dt, 1.0);
		if (Input.isKeyDown(Down))
			strength = Math.max(strength - dt, 0.0);
	}

	static function onFrame(dt:Float):Void {
		handleKeys(dt);

		elapsed += dt;
		Model.animate(gumshoe, dt);
		if (orbit)
			angle += dt * 0.25;
		Camera3D.setView(camera, new Vec3(9.0 * Math.sin(angle), 3.2, 9.0 * Math.cos(angle)), target);

		final lampX = 3.0 * Math.sin(elapsed * 0.9);
		final lampZ = 2.2 + 1.2 * Math.cos(elapsed * 0.9);
		Light.setPosition(lamp, new Vec3(lampX, 1.4, lampZ));
		Shape3D.setPosition(lampMarker, new Vec3(lampX, 1.4, lampZ));
		// isNone, not != null: Model is an abstract over Int, so on a static target
		// there is no null to compare against.
		if (!Model.isNone(torus))
			Model.setTransform(torus, new Vec3(2.2, 0.7, -0.6), new Vec3(0, elapsed * 40.0, elapsed * 25.0), Vec3.ONE);

		// An effect's parameters are its material's: change them any frame you like.
		final live = breathing ? strength * (0.55 + 0.45 * Math.sin(elapsed * 0.8)) : strength;
		if (!Material.isNone(vignette))
			Material.setFloat(vignette, "strength", live);

		Render.beginFrame();
		Render.clearBackground(Color.rgba(16, 18, 24, 255));
		Scene.draw(scene);
		Text.draw("wgrender post-processing: screen effects over the finished frame", 12, 36, 20, Color.RAYWHITE);
		Text.draw('[1] vignette ${vignetteOn ? "on" : "off"}   [2] scanlines ${scanlinesOn ? "on" : "off"}   '
			+ 'effects: ${Render.effectCount()}', 12, 64, 16, Color.LIGHTGRAY);
		Text.draw('UP/DOWN strength ${fixed(strength, 2)}   SPACE ${breathing ? "stop breathing" : "breathe"}   '
			+ "O camera   ESC quit", 12, 86, 16, Color.GRAY);
		Render.endFrame();
	}

	/** The same by-hand formatter the other examples carry; Haxe has no printf. **/
	static function fixed(value:Float, decimals:Int):String {
		final negative = value < 0;
		var digits = Std.string(Math.round(Math.abs(value) * Math.pow(10, decimals)));
		while (digits.length <= decimals)
			digits = "0" + digits;
		final point = digits.length - decimals;
		return (negative ? "-" : "") + digits.substr(0, point) + (decimals > 0 ? "." + digits.substr(point) : "");
	}
}
