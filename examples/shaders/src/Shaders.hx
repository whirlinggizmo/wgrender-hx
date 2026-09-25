// wgrender's custom shaders example, as a Haxe guest: materials drawn by your own.
//
// A port of examples/shaders.c. Four shaders, each showing a different thing a custom
// one can reach:
//
//   toon        lights in flat bands with a rim light, on the *animated* woman --
//               a custom shader works on a skinned model like any other
//   dissolve    a sphere eaten away and coming back through a noise texture, with a
//               glowing edge: time, a texture of its own, and discard
//   wave        a sphere of water rippling, because a vertex hook moves the surface,
//               reflecting the scene's environment
//   sprite_fx   one material outlining and flashing a logo, used by a 3D sprite in
//               the world *and* a 2D one in the corner -- its shader reads whatever
//               texture the sprite carries
//
// The `.wgrshader` files are compiled from examples/shaders/*.glsl for every backend
// by wgrender's tools/shaderpack.py (`tools/gen_shaders.py --examples`) and ship in its assets,
// so they load through the asset system like any other file. This example was parked
// on the assumption they needed generating first; they did not.
//
//   1 2  toggle the sun and the point light
//   ESC  quit
import wgr.*;

@:expose("WgrGuest")
class Shaders {
	static inline final SCREEN_WIDTH = 960;
	static inline final SCREEN_HEIGHT = 540;

	static inline final WOMAN_CASUAL_PATH = "models/woman_casual/woman_casual.glb";
	static inline final NOISE_PATH = "textures/noise.png";
	static inline final LOGO_PATH = "sprites/logo/wg-logo-white-alpha.png";
	static inline final ENVIRONMENT_PATH = "environments/venice_sunset_1k.hdr";

	static final SHADER_PATHS = [
		"shaders/toon.wgrshader", "shaders/dissolve.wgrshader",
		"shaders/wave.wgrshader", "shaders/sprite_fx.wgrshader"
	];
	// ids 1..4 are the shaders, in that order; then the rest
	static inline final ASSET_TOON = 1;
	static inline final ASSET_DISSOLVE = 2;
	static inline final ASSET_WAVE = 3;
	static inline final ASSET_SPRITE_FX = 4;
	static inline final ASSET_LOGO = 5;
	static inline final ASSET_ENVIRONMENT = 6;
	static inline final ASSET_WOMAN_CASUAL = 7;
	static inline final ASSET_NOISE = 8;

	static inline final FLOOR_Y = -0.3;
	static inline final SPHERE_Y = FLOOR_Y + 0.5; // spheres 1 m across, resting on the floor
	/** Slot 1 is the woman's body; slot 0 is her blob shadow, left alone. **/
	static inline final WOMAN_CASUAL_BODY_SLOT = 1;

	static var background:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var womanCasual:Model;
	static var dissolving:Model;
	static var rippling:Model;
	static var dissolve:Material; // borrowed: the model holds the reference
	static var sun:Light;
	static var lamp:Light;
	static var lampMarker:Shape3D;
	static var logo3d:Sprite3D;
	static var logo2d:Sprite2D;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "shaders (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(20, 22, 28, 255);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(0, 1.2, 5.0), new Vec3(0, 0.3, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);
		Scene.setAmbient(scene, Color.WHITE, 0.15);

		addLights();
		addModels();
		addSprites();

		for (i in 0...SHADER_PATHS.length)
			load(SHADER_PATHS[i], i + 1);
		load(LOGO_PATH, ASSET_LOGO);
		load(ENVIRONMENT_PATH, ASSET_ENVIRONMENT);
		load(WOMAN_CASUAL_PATH, ASSET_WOMAN_CASUAL);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function addLights():Void {
		sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.4, -0.7, -0.6));
		Light.setColor(sun, Color.rgba(255, 244, 228, 255));
		Light.setIntensity(sun, 1.5); // soft: the point light and the environment show too
		Scene.add(scene, sun);

		lamp = Light.create(Point);
		Light.setColor(lamp, Color.rgba(120, 190, 255, 255));
		Light.setIntensity(lamp, 9.0); // falls off with distance squared: about 2.3 at 2 m
		Light.setRange(lamp, 8.0);
		Scene.add(scene, lamp);

		lampMarker = Shape3D.create();
		Shape3D.setSphere(lampMarker, 0.05);
		Shape3D.setColor(lampMarker, Color.SKYBLUE);
		Scene.add(scene, lampMarker);
	}

	static function addModels():Void {
		// Generated meshes: a floor to stand on, and the spheres. The water's is finely
		// divided, because its waves move actual vertices.
		final plane = Mesh.plane(6.0, 6.0, 0);
		final sphere = Mesh.sphere(0.5, 32, 64);
		final fineSphere = Mesh.sphere(0.5, 96, 192);

		final floor = Model.create(plane);
		Model.setPosition(floor, new Vec3(0, FLOOR_Y, 0));
		final ground = Material.create(Pbr);
		Material.setBaseColor(ground, 0.04, 0.04, 0.045, 1.0); // dark, so the lights show on it
		Material.setMetallic(ground, 0.0);
		Material.setRoughness(ground, 0.8);
		Model.setMaterial(floor, -1, ground);
		Material.release(ground);
		Scene.add(scene, floor);

		womanCasual = Model.create(Handle.NONE); // the mesh attaches when it loads
		Model.setTransform(womanCasual, new Vec3(-1.9, FLOOR_Y, 0), new Vec3(0, 0.4, 0),
			new Vec3(0.5, 0.5, 0.5)); // feet at its origin
		Model.setAnimation(womanCasual, 3);
		Scene.add(scene, womanCasual);

		dissolving = Model.create(sphere);
		Model.setPosition(dissolving, new Vec3(0, SPHERE_Y, 0));
		Scene.add(scene, dissolving);

		rippling = Model.create(fineSphere);
		Model.setPosition(rippling, new Vec3(1.9, SPHERE_Y, 0));
		Scene.add(scene, rippling);

		Mesh.release(plane); // the models hold their own references
		Mesh.release(sphere);
		Mesh.release(fineSphere);
	}

	/** The logo twice: in the world above the middle, and in the screen's corner. **/
	static function addSprites():Void {
		logo3d = Sprite3D.create(Handle.NONE);
		Sprite3D.setPosition(logo3d, new Vec3(0, 1.55, -0.8));
		Sprite3D.setSize(logo3d, 0.9);
		Sprite3D.setTint(logo3d, Color.rgba(90, 190, 255, 255)); // so the white flash shows
		Scene.add(scene, logo3d);

		logo2d = Sprite2D.create(Handle.NONE);
		Sprite2D.setSize(logo2d, 96.0, 96.0);
		Sprite2D.setPivot(logo2d, 1.0, 1.0);
		Sprite2D.setTint(logo2d, Color.rgba(90, 190, 255, 255));
	}

	/** A shader has loaded: make its material and give it to whatever wears it. **/
	static function onShader(which:Int, path:String):Void {
		final shader = Shader.create(path);
		final material = Material.custom(shader);
		Shader.release(shader); // the material holds its own reference
		if (Material.isNone(material))
			return;

		switch which {
			case ASSET_TOON:
				Material.setColor(material, "color", Color.rgba(255, 196, 120, 255));
				Material.setFloat(material, "bands", 3.0);
				Material.setFloat(material, "rim", 0.35);
				Model.setMaterial(womanCasual, WOMAN_CASUAL_BODY_SLOT, material);

			case ASSET_DISSOLVE:
				Material.setVec4(material, "color", 0.55, 0.6, 0.7, 1.0); // the shader's own colour, linear
				Material.setVec3(material, "edge_color", 4.0, 1.2, 0.2);
				Material.setFloat(material, "speed", 0.15);
				Material.setDoubleSided(material, true); // the inside shows through the holes
				Model.setMaterial(dissolving, 0, material);
				dissolve = material; // the model holds a reference; ours goes below
				load(NOISE_PATH, ASSET_NOISE);

			case ASSET_WAVE:
				Material.setFloat(material, "amplitude", 0.03);
				Material.setFloat(material, "frequency", 2.5);
				Material.setFloat(material, "wave_speed", 3.0);
				Material.setVec4(material, "low_color", 0.0, 0.03, 0.1, 1.0); // deep water
				Material.setVec4(material, "high_color", 0.05, 0.3, 0.35, 1.0);
				Material.setFloat(material, "roughness", 0.05);
				Material.setFloat(material, "reflectivity", 0.35); // real water is 0.02; more, so it shows
				Model.setMaterial(rippling, 0, material);

			case ASSET_SPRITE_FX: // one material, a 3D sprite and a 2D one
				Material.setVec4(material, "outline_color", 1.0, 0.45, 0.1, 1.0);
				Material.setFloat(material, "outline_width", 2.5);
				Material.setFloat(material, "flash", 0.8);
				Material.setFloat(material, "pulse_speed", 5.0);
				Sprite3D.setMaterial(logo3d, material);
				Sprite2D.setMaterial(logo2d, material);
		}
		Material.release(material); // whatever wears it holds its own reference
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_TOON | ASSET_DISSOLVE | ASSET_WAVE | ASSET_SPRITE_FX:
				onShader(id, path);

			case ASSET_LOGO:
				final texture = Texture.create(path);
				Sprite3D.setTexture(logo3d, texture);
				Sprite2D.setTexture(logo2d, texture);
				Texture.release(texture); // the sprites hold their own references

			case ASSET_ENVIRONMENT:
				final environment = Environment.create(path);
				// lighting only: the background stays dark
				Scene.setEnvironment(scene, environment, 1.0, 0.0);
				Environment.release(environment); // the scene holds its own reference

			case ASSET_WOMAN_CASUAL:
				final mesh = Mesh.create(path);
				Model.setMesh(womanCasual, mesh);
				Mesh.release(mesh);

			case ASSET_NOISE:
				final texture = Texture.create(path);
				if (!Material.isNone(dissolve))
					Material.setTexture(dissolve, "noise_tex", texture);
				Texture.release(texture); // the material holds its own reference
		}
	}

	static function onFrame(dt:Float):Void {
		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();
		if (Input.isKeyPressed(Digit1))
			Light.setEnabled(sun, !Light.isEnabled(sun));
		if (Input.isKeyPressed(Digit2))
			Light.setEnabled(lamp, !Light.isEnabled(lamp));

		elapsed += dt;
		// circling in front of the models and facing the camera: always in view, and
		// 1.8 m or more from them -- closer, it would wash them out
		final lx = Math.cos(elapsed * 0.7) * 2.2;
		final ly = 0.8 + Math.sin(elapsed * 0.7) * 1.0;
		final lz = 1.8;
		Light.setPosition(lamp, new Vec3(lx, ly, lz));
		Shape3D.setPosition(lampMarker, new Vec3(lx, ly, lz));
		Shape3D.setVisible(lampMarker, Light.isEnabled(lamp));
		Model.setTransform(dissolving, new Vec3(0, SPHERE_Y, 0), new Vec3(0, elapsed * 0.4, 0), Vec3.ONE);
		Model.animate(womanCasual, dt);

		Render.beginFrame();
		Render.clearBackground(background);
		Scene.draw(scene);
		final screen = Window.getScreenSize();
		Sprite2D.setPosition(logo2d, new Vec2(screen.x - 16.0, screen.y - 16.0)); // bottom right
		Sprite2D.draw(logo2d);
		Text.draw("wgrender custom shaders: toon, dissolve, water, sprite effects", 12, 12, 20, Color.RAYWHITE);
		Text.draw("1 sun, 2 point light, ESC quit", 12, 40, 16, Color.LIGHTGRAY);
		Render.endFrame();
	}
}
