// wgrender's lights example, as a Haxe guest: directional, point and spot.
//
// A port of examples/lights.c. Five animated models on a grid under three lights that
// can each be switched off, so it is clear which one is doing what:
//
//   a dim warm sun         directional, no position, only a direction
//   a cyan lamp            point, orbiting the row and falling off with its range;
//                          the small sphere marks it, and is unlit so it shows the
//                          light's own colour rather than being lit by it
//   a white spotlight      sweeping across from above, a cone in radians
//
// Behind them stand billboards with a built-in material, which is what makes them take
// the scene's lights the way the models do -- a Sprite3D without one is drawn flat. Each
// shows one cell of the tilemap example's sprite sheet, and the sheet's normal map gives
// it relief: the normal map is sampled through the same region.
//
// A scene starts with no lights and no ambient. Everything here is explicit, and
// turning all three off leaves the ambient alone, which is the point of trying it.
//
//   1 2 3  toggle the sun, the lamp, the spotlight
//   ESC    quit
import wgr.*;

@:expose("WgrGuest")
class LightsDemo {
	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 600;
	static inline final CHARACTER_PATH = "models/woman_casual/woman_casual.glb";
	static inline final SPRITE_PATH = "textures/tiles.png";
	static inline final NORMAL_PATH = "textures/tiles_sheet_normal.png"; // wgrender's tools/gen_tiles.py

	static inline final ASSET_MESH = 1;
	static inline final ASSET_SPRITE = 2;
	static inline final ASSET_NORMAL = 3;

	static inline final MODEL_COUNT = 5;
	static inline final SPRITE_COUNT = 4;

	// the sprites' cells in the sheet (pixels, from wgrender's tools/gen_tiles.py) and
	// their world height; all 1.6 wide
	static final SPRITE_CELLS = [
		[62.0, 2, 16, 16, 1.6], // stone
		[2.0, 22, 16, 32, 3.2], // tree
		[42.0, 22, 16, 16, 1.6], // coin
		[62.0, 22, 16, 16, 1.6], // rock
	];

	static var background:Color;
	static var gridColor:Color;
	static var lampColor:Color;

	static var scene:Scene;
	static var camera:Camera3D;
	static var models:Array<Model> = [];
	static var sprites:Array<Sprite3D> = [];
	static var spriteMaterial:Material;
	static var sun:Light;
	static var lamp:Light;
	static var lampMarker:Shape3D;
	static var spot:Light;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "lights (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(12, 13, 18, 255);
		gridColor = Color.rgba(40, 42, 50, 255);
		lampColor = Color.rgba(60, 220, 255, 255);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(0, 4.5, 10), new Vec3(0, 1, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);
		Scene.setAmbient(scene, Color.rgba(90, 110, 160, 255), 0.05);

		addModels();
		addLights();
		addSprites();

		load(CHARACTER_PATH, ASSET_MESH);
		load(SPRITE_PATH, ASSET_SPRITE);
		load(NORMAL_PATH, ASSET_NORMAL);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function addModels():Void {
		for (i in 0...MODEL_COUNT) {
			final model = Model.create(Handle.NONE); // the mesh is attached when it loads
			Model.setPosition(model, new Vec3(-4.0 + 2.0 * i, 0, i % 2 == 1 ? -0.8 : 0.8));
			Model.setAnimation(model, 3);
			Model.setAnimationLoop(model, true);
			Scene.add(scene, model);
			models.push(model);
		}
	}

	static function addLights():Void {
		sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.4, -1.0, -0.6));
		Light.setColor(sun, Color.rgba(255, 210, 160, 255));
		Light.setIntensity(sun, 1.1);
		Scene.add(scene, sun);

		lamp = Light.create(Point);
		Light.setColor(lamp, lampColor);
		Light.setIntensity(lamp, 20.0);
		Light.setRange(lamp, 5.0);
		Scene.add(scene, lamp);

		// Unlit, so it shows the lamp's colour rather than being lit by it.
		lampMarker = Shape3D.create();
		Shape3D.setSphere(lampMarker, 0.12);
		Shape3D.setColor(lampMarker, lampColor);
		Scene.add(scene, lampMarker);

		spot = Light.create(Spot);
		Light.setPosition(spot, new Vec3(0, 6, 2));
		Light.setSpotCone(spot, 0.14, 0.28); // radians: about 8 and 16 degrees
		Light.setIntensity(spot, 125.0);
		Scene.add(scene, spot);
	}

	/** Lit billboards: a built-in material is what lets the scene's lights reach them. **/
	static function addSprites():Void {
		spriteMaterial = Material.create(Pbr);
		Material.setMetallic(spriteMaterial, 0.0);
		Material.setRoughness(spriteMaterial, 0.55);
		// cells sit side by side in the sheet: clamp, so none reaches into the next
		Material.setTextureSampling(spriteMaterial, "normal_texture", Clamp, Clamp, Linear);
		for (i in 0...SPRITE_COUNT) {
			final cell = SPRITE_CELLS[i];
			final sprite = Sprite3D.create(Handle.NONE);
			Sprite3D.setPosition(sprite, new Vec3(-3.0 + 2.0 * i, 0.2, -2.5));
			Sprite3D.setSource(sprite, cell[0], cell[1], cell[2], cell[3]);
			Sprite3D.setExtent(sprite, 1.6, cell[4]);
			Sprite3D.setPivot(sprite, 0.5, 1.0); // standing on their bottom edge
			Sprite3D.setAlphaMode(sprite, Mask, 0.5);
			Sprite3D.setMaterial(sprite, spriteMaterial);
			Scene.add(scene, sprite);
			sprites.push(sprite);
		}
		Material.release(spriteMaterial); // the sprites hold it
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_MESH:
				final mesh = Mesh.create(path);
				for (model in models)
					Model.setMesh(model, mesh);
				Mesh.release(mesh); // the models hold their own references

			case ASSET_SPRITE:
				final texture = Texture.create(path);
				Texture.setSampling(texture, Clamp, Clamp, Nearest);
				for (sprite in sprites)
					Sprite3D.setTexture(sprite, texture);
				Texture.release(texture);

			case ASSET_NORMAL:
				final texture = Texture.create(path);
				Material.setNormalTexture(spriteMaterial, texture);
				Texture.release(texture);
		}
	}

	static function onFrame(dt:Float):Void {
		final keys = Input.getKeyboardState();
		if (keys.isPressed(Digit1))
			Light.setEnabled(sun, !Light.isEnabled(sun));
		if (keys.isPressed(Digit2))
			Light.setEnabled(lamp, !Light.isEnabled(lamp));
		if (keys.isPressed(Digit3))
			Light.setEnabled(spot, !Light.isEnabled(spot));
		if (keys.isPressed(Escape))
			Wgr.requestQuit();

		elapsed += dt;
		for (model in models)
			Model.animate(model, dt);

		// the lamp orbits through the row; the spotlight sweeps left and right
		final lx = Math.sin(elapsed * 0.6) * 5.0;
		final lz = Math.cos(elapsed * 0.6) * 2.0;
		Light.setPosition(lamp, new Vec3(lx, 1.2, lz));
		Shape3D.setPosition(lampMarker, new Vec3(lx, 1.2, lz));
		Shape3D.setVisible(lampMarker, Light.isEnabled(lamp));
		Light.setDirection(spot, new Vec3(Math.sin(elapsed * 0.8) * 0.7, -1.0, -0.3));

		Render.beginFrame();
		Render.clearBackground(background);
		Render.beginMode3D();
		Shape3D.drawGrid(20, 1.0, gridColor);
		Render.endMode3D();
		Scene.draw(scene);

		Text.draw("wgrender lights: directional, point, spot", 12, 12, 20, Color.RAYWHITE);
		Text.draw('[1] sun ${on(sun)}   [2] point light ${on(lamp)}   [3] spotlight ${on(spot)}', 12, 40, 16,
			Color.LIGHTGRAY);
		Text.drawFps(12, 64);
		Render.endFrame();
	}

	static inline function on(light:Light):String
		return Light.isEnabled(light) ? "on " : "off";
}
