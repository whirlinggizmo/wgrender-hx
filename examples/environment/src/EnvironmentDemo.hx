// wgrender's environment example, as a Haxe guest: image-based lighting.
//
// A port of examples/environment.c. The material spheres (red plastic and gold,
// roughness 0 to 1 left to right), a normal-mapped sphere and the character, lit *only*
// by an environment map — no lights and no ambient anywhere in this file. Metals
// reflect the map; rough surfaces blur it.
//
//   E            environment: sunset, studio, none
//   B            background blur: sharp, soft, blurred, off
//   T            tone mapping: Neutral, ACES, none
//   UP/DOWN      exposure, half a stop at a time
//   LEFT/RIGHT   rotate the environment
//   ESC          quit
//
// `Environment.create` does real work — it prepares the lighting from the HDR, a
// fraction of a second — so it happens once per map on the asset op and the three
// scene settings are re-applied together whenever anything changes.
//
// The class is `EnvironmentDemo` because a module named `Environment` would shadow
// `wgr.Environment` inside itself.
import wgr.*;

@:expose("WgrGuest")
class EnvironmentDemo {
	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 640;
	static inline final SPHERE_PATH = "models/sphere/sphere.glb";
	static inline final CHARACTER_PATH = "models/woman_casual/woman_casual.glb";
	static inline final NORMAL_MAP_PATH = "textures/tiles_normal.png";

	static final ENVIRONMENT_PATHS = ["environments/venice_sunset_1k.hdr", "environments/studio_small_09_1k.hdr"];
	static final ENVIRONMENT_NAMES = ["sunset", "studio", "none"];
	static final TONEMAPS = [Tonemap.Neutral, Tonemap.Aces, Tonemap.None];
	static final TONEMAP_NAMES = ["Neutral", "ACES", "none"];
	static final BLURS = [0.0, 0.35, 0.8];
	static final BLUR_NAMES = ["sharp", "soft", "blurred", "off"];

	// ids: 1..2 the environments, then the three scene assets
	static inline final ASSET_SPHERE = 3;
	static inline final ASSET_CHARACTER = 4;
	static inline final ASSET_NORMAL_MAP = 5;

	static inline final COLUMNS = 5;
	static inline final SPACING = 1.3;

	static var background:Color;
	static var bar:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var target:Vec3;
	static var environments:Array<Environment> = [Handle.NONE, Handle.NONE];
	static var spheres:Array<Model> = [];
	static var character:Model;
	static var tiles:Material;

	static var environmentIndex = 0; // ENVIRONMENT_PATHS.length means "none"
	static var blurIndex = 0; // BLURS.length means "no background"
	static var tonemapIndex = 0;
	static var exposure = 0.0;
	static var rotation = 0.0;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "environment (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		Asset.setManifest(Assets.MANIFEST);
		background = Color.rgba(20, 22, 28, 255);
		bar = Color.rgba(0, 0, 0, 150);
		target = new Vec3(0, 0.3, 0);

		camera = Camera3D.create(Perspective);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		addSpheres();

		character = Model.create(Handle.NONE);
		Model.setTransform(character, new Vec3(1.3, -1.3, 0), new Vec3(0, 0.4, 0), new Vec3(0.3, 0.3, 0.3));
		Model.setAnimation(character, 3);
		Scene.add(scene, character);

		applyEnvironment();
		for (i in 0...ENVIRONMENT_PATHS.length)
			load(ENVIRONMENT_PATHS[i], i + 1);
		load(SPHERE_PATH, ASSET_SPHERE);
		load(CHARACTER_PATH, ASSET_CHARACTER);
		load(NORMAL_MAP_PATH, ASSET_NORMAL_MAP);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function sphere(x:Float, y:Float, r:Float, g:Float, b:Float, metallic:Float, roughness:Float):Model {
		final model = Model.create(Handle.NONE); // the mesh arrives later
		Model.setPosition(model, new Vec3(x, y, 0));
		final material = Material.create(Pbr);
		Material.setBaseColor(material, r, g, b, 1.0);
		Material.setMetallic(material, metallic);
		Material.setRoughness(material, roughness);
		Model.setMaterial(model, 0, material);
		Material.release(material);
		Scene.add(scene, model);
		spheres.push(model);
		return model;
	}

	static function addSpheres():Void {
		for (c in 0...COLUMNS) {
			final x = (c - (COLUMNS - 1) * 0.5) * SPACING;
			final roughness = c / (COLUMNS - 1);
			sphere(x, 1.9, 0.8, 0.05, 0.04, 0.0, roughness); // red plastic
			sphere(x, 0.6, 1.0, 0.77, 0.34, 1.0, roughness); // gold
		}
		final normalMapped = sphere(-1.3, -0.7, 0.9, 0.9, 0.9, 0.0, 0.3);
		tiles = Model.getMaterial(normalMapped, 0); // borrowed: the model's own material
	}

	/** All three settings together, because any of them changing re-applies the lot. **/
	static function applyEnvironment():Void {
		final env = environmentIndex < environments.length ? environments[environmentIndex] : Handle.NONE;
		Scene.setEnvironment(scene, env, 1.0, rotation);
		final showBackground = blurIndex < BLURS.length;
		Scene.setBackground(scene, showBackground ? env : Handle.NONE, showBackground ? BLURS[blurIndex] : 0.0);
		Scene.setTonemap(scene, TONEMAPS[tonemapIndex], exposure);
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_SPHERE:
				final mesh = Mesh.create(path);
				for (model in spheres)
					Model.setMesh(model, mesh);
				Mesh.release(mesh);

			case ASSET_CHARACTER:
				final mesh = Mesh.create(path);
				Model.setMesh(character, mesh);
				Mesh.release(mesh);

			case ASSET_NORMAL_MAP:
				final texture = Texture.create(path);
				Material.setNormalTexture(tiles, texture);
				Texture.release(texture);

			default:
				// an environment: preparing its lighting is the slow part, done once
				environments[id - 1] = Environment.create(path);
				applyEnvironment();
		}
	}

	static function handleKeys(dt:Float):Bool {
		final keys = Input.getKeyboardState();
		var changed = false;
		if (keys.isPressed(Escape))
			Wgr.requestQuit();
		if (keys.isPressed(E)) {
			environmentIndex = (environmentIndex + 1) % (ENVIRONMENT_PATHS.length + 1);
			changed = true;
		}
		if (keys.isPressed(B)) {
			blurIndex = (blurIndex + 1) % (BLURS.length + 1);
			changed = true;
		}
		if (keys.isPressed(T)) {
			tonemapIndex = (tonemapIndex + 1) % TONEMAPS.length;
			changed = true;
		}
		if (keys.isPressed(Up)) {
			exposure += 0.5;
			changed = true;
		}
		if (keys.isPressed(Down)) {
			exposure -= 0.5;
			changed = true;
		}
		if (keys.isDown(Left)) {
			rotation -= dt;
			changed = true;
		}
		if (keys.isDown(Right)) {
			rotation += dt;
			changed = true;
		}
		return changed;
	}

	static function onFrame(dt:Float):Void {
		if (handleKeys(dt))
			applyEnvironment();

		elapsed += dt;
		Camera3D.setView(camera, new Vec3(Math.sin(elapsed * 0.15) * 7.5, 1.2, Math.cos(elapsed * 0.15) * 7.5), target);
		Model.animate(character, dt);

		Render.beginFrame();
		Render.clearBackground(background);
		Scene.draw(scene);
		Shape2D.drawRectangle(0, 0, Window.getScreenSize().x, 60, bar);
		Text.draw("wgrender environment lighting: reflections, background and tone mapping", 12, 12, 16,
			Color.RAYWHITE);
		Text.draw('[E] ${ENVIRONMENT_NAMES[environmentIndex]}   [B] background ${BLUR_NAMES[blurIndex]}   '
			+ '[T] tone mapping ${TONEMAP_NAMES[tonemapIndex]}   '
			+ '[UP/DOWN] exposure ${exposure >= 0 ? "+" : ""}${fixed(exposure, 1)} EV', 12, 36, 16, Color.LIGHTGRAY);
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
