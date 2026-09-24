// wgrender's materials example, as a Haxe guest: glTF metallic-roughness, in code.
//
// A port of examples/materials.c.
//
//   top row      dielectric spheres (metallic 0), roughness 0 to 1 left to right
//   middle row   metal spheres (metallic 1), the same roughness steps
//   bottom row   unlit, emissive, normal mapped, alpha blended, and the gumshoe with
//                his body material replaced by gold -- on this model only
//
// Two things in here are the actual subject. One sphere mesh backs every sphere and
// each model overrides the mesh's material, so the material belongs to the instance
// rather than the geometry. And every material is assigned before the mesh has
// finished loading, which works because a model holds the assignment and applies it
// when the mesh arrives.
//
//   1 2  toggle the sun and the lamp
//   ESC  quit
import wgr.*;

@:expose("WgrGuest")
class MaterialsDemo {
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

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "materials (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(20, 22, 28, 255);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(0, 1.6, 7.5), new Vec3(0, 1.2, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);
		Scene.setAmbient(scene, Color.WHITE, 0.12);

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
		Light.setDirection(sun, new Vec3(-0.4, -0.7, -0.6));
		Light.setColor(sun, Color.rgba(255, 244, 228, 255));
		Light.setIntensity(sun, 3.0);
		Scene.add(scene, sun);

		lamp = Light.create(Point);
		Light.setColor(lamp, Color.rgba(120, 190, 255, 255));
		Light.setIntensity(lamp, 8.0);
		Light.setRange(lamp, 10.0);
		Scene.add(scene, lamp);

		// Shapes are unlit, so this shows the light's own colour.
		lampMarker = Shape3D.create();
		Shape3D.setSphere(lampMarker, 0.06);
		Shape3D.setColor(lampMarker, Color.SKYBLUE);
		Scene.add(scene, lampMarker);
	}

	/** Linear rgb, glTF's factor -- not an sRGB `Color`. **/
	static function pbr(r:Float, g:Float, b:Float, metallic:Float, roughness:Float):Material {
		final material = Material.create(Pbr);
		Material.setBaseColor(material, r, g, b, 1.0);
		Material.setMetallic(material, metallic);
		Material.setRoughness(material, roughness);
		return material;
	}

	/** Place a sphere and give it `material`; the model keeps its own reference. **/
	static function sphere(x:Float, y:Float, material:Material):Model {
		final model = Model.create(Handle.NONE); // the mesh is attached when it loads
		Model.setPosition(model, new Vec3(x, y, 0));
		Model.setMaterial(model, 0, material);
		Material.release(material);
		Scene.add(scene, model);
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
		Material.setColor(unlit, "base_color", Color.SKYBLUE);
		bottomRow.push(sphere(-2 * SPACING, 0.0, unlit));

		// emissive: glows whatever the lighting does
		final emissive = pbr(0.05, 0.05, 0.05, 0.0, 0.6);
		Material.setEmissive(emissive, 1.0, 0.35, 0.05);
		bottomRow.push(sphere(-SPACING, 0.0, emissive));

		// normal mapped: bevelled tiles, tangents generated at load
		tiles = pbr(0.6, 0.6, 0.62, 0.0, 0.45);
		Material.setNormalScale(tiles, 1.0);
		bottomRow.push(sphere(0.0, 0.0, tiles)); // releases our reference; the model keeps one

		// alpha blended glass
		final glass = pbr(0.3, 0.9, 0.5, 0.0, 0.1);
		Material.setBaseColor(glass, 0.3, 0.9, 0.5, 0.35);
		Material.setAlphaMode(glass, Blend, 0.5);
		bottomRow.push(sphere(SPACING, 0.0, glass));
	}

	static function addGumshoe():Void {
		gumshoe = Model.create(Handle.NONE);
		Model.setTransform(gumshoe, new Vec3(2 * SPACING, -0.55, 0), new Vec3(0, -0.6, 0), new Vec3(0.3, 0.3, 0.3));
		Model.setAnimation(gumshoe, 3);
		final gold = pbr(1.0, 0.77, 0.34, 1.0, 0.3);
		Model.setMaterial(gumshoe, GUMSHOE_BODY_SLOT, gold);
		Material.release(gold);
		Scene.add(scene, gumshoe);
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
				Mesh.release(mesh); // the models hold their own references

			case ASSET_GUMSHOE:
				final mesh = Mesh.create(path);
				Model.setMesh(gumshoe, mesh);
				Mesh.release(mesh);

			case ASSET_NORMAL_MAP:
				final texture = Texture.create(path);
				Material.setNormalTexture(tiles, texture);
				Texture.release(texture); // the material holds its own reference
		}
	}

	static function onFrame(dt:Float):Void {
		final keys = Input.getKeyboardState();
		if (keys.isPressed(Escape))
			Wgr.requestQuit();
		if (keys.isPressed(Digit1))
			Light.setEnabled(sun, !Light.isEnabled(sun));
		if (keys.isPressed(Digit2))
			Light.setEnabled(lamp, !Light.isEnabled(lamp));

		elapsed += dt;
		final lx = Math.cos(elapsed * 0.7) * 4.0;
		final ly = 1.4 + Math.sin(elapsed * 0.9) * 1.2;
		final lz = Math.sin(elapsed * 0.7) * 1.5 + 2.0;
		Light.setPosition(lamp, new Vec3(lx, ly, lz));
		Shape3D.setPosition(lampMarker, new Vec3(lx, ly, lz));
		Shape3D.setVisible(lampMarker, Light.isEnabled(lamp));

		// turn the bottom row, so the normal map has something to catch
		for (i in 0...bottomRow.length)
			Model.setTransform(bottomRow[i], new Vec3((i - 2.0) * SPACING, 0.0, 0), new Vec3(0, elapsed * 0.5, 0), Vec3.ONE);
		Model.animate(gumshoe, dt);

		Render.beginFrame();
		Render.clearBackground(background);
		Scene.draw(scene);
		Text.draw("wgrender materials: metallic-roughness, unlit, emissive, normal map, blend", 12, 12, 16,
			Color.RAYWHITE);
		Text.draw('roughness 0 -> 1 (left to right)   rows: plastic, gold   '
			+ '[1] sun ${Light.isEnabled(sun) ? "on" : "off"}  [2] lamp ${Light.isEnabled(lamp) ? "on" : "off"}', 12, 36, 16,
			Color.LIGHTGRAY);
		Render.endFrame();
	}
}
