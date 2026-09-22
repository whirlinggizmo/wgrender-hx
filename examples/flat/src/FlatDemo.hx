// examples/materials, rewritten against `wgr.flat` — the same scene, the flat way.
//
// Nothing about the scene changed. Every difference below is API shape, so the two
// files can be diffed and the trial judged on readability, size and frame cost:
//
//   m.roughness = 0.35            ->  Material.setRoughness(m, 0.35)
//   sun.enabled = !sun.enabled    ->  Light.setEnabled(sun, !Light.isEnabled(sun))
//   scene.activeCamera = camera   ->  Scene.setActiveCamera(scene, camera)
//
// This example is deliberately NOT in examples/build.py's GUESTS, so a trial that goes
// wrong cannot break the 32 that work. Build and drive it directly:
//
//   cd examples/flat && ./build.py all && node ../../tools/drive.mjs --site=out/web
//
// `import wgr.flat.*` comes second so its nine names win over `wgr`'s for Material,
// Model, Scene, Light, Shape3D, Camera3D, Mesh, Texture and SceneMember. Everything
// else — Render, Text, Input, Color, Vec3, Handle, GuestAbi — is `wgr`'s and unchanged,
// because those are already statics. That is worth noticing: most of wgrender-hx is
// flat already, and this shape only ever touches the handle-bearing types.
//
// See src/wgr/flat/README.md for the rules being tested.
import wgr.*;
import wgr.flat.*;

@:expose("WgrGuest")
class FlatDemo {
	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 700;
	static inline final SPHERE_PATH = "models/sphere/sphere.glb";
	static inline final GUMSHOE_PATH = "models/gumshoe/gumshoe.glb";
	static inline final NORMAL_MAP_PATH = "textures/tiles_normal.png";

	static inline final ASSET_SPHERE = 1;
	static inline final ASSET_GUMSHOE = 2;
	static inline final ASSET_NORMAL_MAP = 3;

	static inline final COLUMNS = 5;
	static inline final SPACING = 1.35;
	/** Slot 1 is the gumshoe's body; slot 0 is his blob shadow, which is left alone. **/
	static inline final GUMSHOE_BODY_SLOT = 1;

	static var background:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var spheres:Array<Model> = [];
	static var bottomRow:Array<Model> = [];
	static var gumshoe:Model;
	static var tiles:Material; // the normal-mapped one; its texture arrives later
	static var sun:Light;
	static var lamp:Light;
	static var lampMarker:Shape3D;
	static var elapsed = 0.0;

	/** Every refusal the flat API reports, so the return values are not decoration. **/
	static var refusals = 0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "flat (wgrender host, Haxe guest)", Msaa4x | Resizable);
	}

	/**
		The point of returning `Bool`: a refused call can be seen at the call site.

		`wgr.Material`'s property setters cannot do this — Haxe makes `set_roughness`
		return `Float`, so the `Bool` from `wgr_material_set_float` is dropped. Four
		float properties and five texture properties drop it today.
	**/
	static inline function ok(result:Bool, what:String):Bool {
		if (!result) {
			refusals++;
			Log.error('refused: $what'); // the C has already logged why
		}
		return result;
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(20, 22, 28, 255);

		camera = Camera3D.create(Perspective);
		ok(Camera3D.setView(camera, new Vec3(0, 1.6, 7.5), new Vec3(0, 1.2, 0)), "camera view");
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera); // one of the seven void setters
		ok(Scene.setAmbient(scene, Color.WHITE, 0.12), "ambient");

		addLights();
		addRoughnessRows();
		addBottomRow();
		addGumshoe();

		load(SPHERE_PATH, ASSET_SPHERE);
		load(GUMSHOE_PATH, ASSET_GUMSHOE);
		load(NORMAL_MAP_PATH, ASSET_NORMAL_MAP);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function addLights():Void {
		sun = Light.create(Directional);
		ok(Light.setDirection(sun, new Vec3(-0.4, -0.7, -0.6)), "sun direction");
		ok(Light.setColor(sun, Color.rgba(255, 244, 228, 255)), "sun colour");
		ok(Light.setIntensity(sun, 3.0), "sun intensity");
		ok(Scene.add(scene, sun), "add sun");

		lamp = Light.create(Point);
		ok(Light.setColor(lamp, Color.rgba(120, 190, 255, 255)), "lamp colour");
		ok(Light.setIntensity(lamp, 8.0), "lamp intensity");
		ok(Light.setRange(lamp, 10.0), "lamp range");
		ok(Scene.add(scene, lamp), "add lamp");

		// Shapes are unlit, so this shows the light's own colour.
		lampMarker = Shape3D.create();
		ok(Shape3D.setSphere(lampMarker, 0.06), "lamp marker");
		ok(Shape3D.setColor(lampMarker, Color.SKYBLUE), "lamp marker colour");
		ok(Scene.add(scene, lampMarker), "add lamp marker");
	}

	/** Linear rgb, glTF's factor -- not an sRGB `Color`. **/
	static function pbr(r:Float, g:Float, b:Float, metallic:Float, roughness:Float):Material {
		final material = Material.create(Pbr);
		ok(Material.setBaseColor(material, r, g, b, 1.0), "base colour");
		ok(Material.setMetallic(material, metallic), "metallic");
		ok(Material.setRoughness(material, roughness), "roughness");
		return material;
	}

	/** Place a sphere and give it `material`; the model keeps its own reference. **/
	static function sphere(x:Float, y:Float, material:Material):Model {
		final model = Model.create(Handle.NONE); // the mesh is attached when it loads
		ok(Model.setTransform(model, new Vec3(x, y, 0)), "sphere transform");
		ok(Model.setMaterial(model, 0, material), "sphere material");
		Material.release(material);
		ok(Scene.add(scene, model), "add sphere");
		spheres.push(model);
		return model;
	}

	static function addRoughnessRows():Void {
		for (c in 0...COLUMNS) {
			final x = (c - (COLUMNS - 1) * 0.5) * SPACING;
			final roughness = c / (COLUMNS - 1);
			sphere(x, 2.7, pbr(0.8, 0.05, 0.04, 0.0, roughness)); // red plastic
			sphere(x, 1.35, pbr(1.0, 0.77, 0.34, 1.0, roughness)); // gold
		}
	}

	static function addBottomRow():Void {
		// unlit: ignores the lights entirely
		final unlit = Material.create(Unlit);
		ok(Material.setColor(unlit, "base_color", Color.SKYBLUE), "unlit colour");
		bottomRow.push(sphere(-2 * SPACING, 0.0, unlit));

		// emissive: glows whatever the lighting does
		final emissive = pbr(0.05, 0.05, 0.05, 0.0, 0.6);
		ok(Material.setEmissive(emissive, 1.0, 0.35, 0.05), "emissive");
		bottomRow.push(sphere(-SPACING, 0.0, emissive));

		// normal mapped: bevelled tiles, tangents generated at load
		tiles = pbr(0.6, 0.6, 0.62, 0.0, 0.45);
		ok(Material.setNormalScale(tiles, 1.0), "normal scale");
		bottomRow.push(sphere(0.0, 0.0, tiles)); // releases our reference; the model keeps one

		// alpha blended glass
		final glass = pbr(0.3, 0.9, 0.5, 0.0, 0.1);
		ok(Material.setBaseColor(glass, 0.3, 0.9, 0.5, 0.35), "glass colour");
		ok(Material.setAlphaMode(glass, Blend, 0.5), "glass alpha mode");
		bottomRow.push(sphere(SPACING, 0.0, glass));
	}

	static function addGumshoe():Void {
		gumshoe = Model.create(Handle.NONE);
		ok(Model.setTransform(gumshoe, new Vec3(2 * SPACING, -0.55, 0), new Vec3(0, -0.6, 0),
			new Vec3(0.3, 0.3, 0.3)), "gumshoe transform");
		ok(Model.setAnimation(gumshoe, 3), "gumshoe animation");
		final gold = pbr(1.0, 0.77, 0.34, 1.0, 0.3);
		ok(Model.setMaterial(gumshoe, GUMSHOE_BODY_SLOT, gold), "gumshoe body material");
		Material.release(gold);
		ok(Scene.add(scene, gumshoe), "add gumshoe");
	}

	static function onAsset(id:Int, path:String, isOk:Bool):Void {
		if (!isOk) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_SPHERE:
				final mesh = Mesh.create(path);
				for (model in spheres)
					ok(Model.setMesh(model, mesh), "sphere mesh");
				Mesh.release(mesh); // the models hold their own references

			case ASSET_GUMSHOE:
				final mesh = Mesh.create(path);
				ok(Model.setMesh(gumshoe, mesh), "gumshoe mesh");
				Mesh.release(mesh);

			case ASSET_NORMAL_MAP:
				final texture = Texture.create(path);
				// The sharp API drops this Bool. This is the one line the trial exists
				// to make visible.
				ok(Material.setNormalTexture(tiles, texture), "normal texture");
				Texture.release(texture); // the material holds its own reference
		}
	}

	static function onFrame(dt:Float):Void {
		final keys = Input.getKeyboardState();
		if (keys.isPressed(Escape))
			Wgr.requestQuit();
		if (keys.isPressed(Digit1))
			ok(Light.setEnabled(sun, !Light.isEnabled(sun)), "sun toggle");
		if (keys.isPressed(Digit2))
			ok(Light.setEnabled(lamp, !Light.isEnabled(lamp)), "lamp toggle");

		elapsed += dt;
		final lx = Math.cos(elapsed * 0.7) * 4.0;
		final ly = 1.4 + Math.sin(elapsed * 0.9) * 1.2;
		final lz = Math.sin(elapsed * 0.7) * 1.5 + 2.0;
		Light.setPosition(lamp, new Vec3(lx, ly, lz));
		Shape3D.setTransform(lampMarker, new Vec3(lx, ly, lz));
		Shape3D.setVisible(lampMarker, Light.isEnabled(lamp));

		// turn the bottom row, so the normal map has something to catch
		for (i in 0...bottomRow.length)
			Model.setTransform(bottomRow[i], new Vec3((i - 2.0) * SPACING, 0.0, 0), new Vec3(0, elapsed * 0.5, 0));
		Model.animate(gumshoe, dt);

		Render.begin();
		Render.clearBackground(background);
		Scene.draw(scene);
		Text.draw("wgr.flat: the materials scene, written as statics taking the handle", 12, 12, 16, Color.RAYWHITE);
		Text.draw('roughness 0 -> 1 (left to right)   rows: plastic, gold   '
			+ '[1] sun ${Light.isEnabled(sun) ? "on" : "off"}  [2] lamp ${Light.isEnabled(lamp) ? "on" : "off"}', 12,
			36, 16, Color.LIGHTGRAY);
		Text.draw('refused calls: $refusals   (the sharp API cannot report these)', 12, 60, 14,
			refusals > 0 ? Color.GOLD : Color.LIGHTGRAY);
		Render.end();
	}
}
