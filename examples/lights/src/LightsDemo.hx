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
// the scene's lights the way the models do -- a Sprite3D without one is drawn flat.
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
	static inline final MODEL_PATH = "models/gumshoe/gumshoe.glb";
	static inline final SPRITE_PATH = "textures/tiles.png";
	static inline final NORMAL_PATH = "textures/tiles_normal.png";

	static inline final ASSET_MESH = 1;
	static inline final ASSET_SPRITE = 2;
	static inline final ASSET_NORMAL = 3;

	static inline final MODEL_COUNT = 5;
	static inline final SPRITE_COUNT = 4;

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

		camera = new Camera3D(Perspective);
		camera.setView(new Vec3(0, 4.5, 10), new Vec3(0, 1, 0));
		scene = new Scene();
		scene.activeCamera = camera;
		scene.setAmbient(Color.rgba(90, 110, 160, 255), 0.05);

		addModels();
		addLights();
		addSprites();

		load(MODEL_PATH, ASSET_MESH);
		load(SPRITE_PATH, ASSET_SPRITE);
		load(NORMAL_PATH, ASSET_NORMAL);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function addModels():Void {
		for (i in 0...MODEL_COUNT) {
			final model = new Model(Handle.NONE); // the mesh is attached when it loads
			model.setTransform(new Vec3(-4.0 + 2.0 * i, 0, i % 2 == 1 ? -0.8 : 0.8));
			model.animation = 3;
			model.animationLoop = true;
			scene.add(model);
			models.push(model);
		}
	}

	static function addLights():Void {
		sun = new Light(Directional);
		sun.direction = new Vec3(-0.4, -1.0, -0.6);
		sun.color = Color.rgba(255, 210, 160, 255);
		sun.intensity = 1.1;
		scene.add(sun);

		lamp = new Light(Point);
		lamp.color = lampColor;
		lamp.intensity = 20.0;
		lamp.range = 5.0;
		scene.add(lamp);

		// Unlit, so it shows the lamp's colour rather than being lit by it.
		lampMarker = new Shape3D();
		lampMarker.setSphere(0.12);
		lampMarker.color = lampColor;
		scene.add(lampMarker);

		spot = new Light(Spot);
		spot.position = new Vec3(0, 6, 2);
		spot.setSpotCone(0.14, 0.28); // radians: about 8 and 16 degrees
		spot.intensity = 125.0;
		scene.add(spot);
	}

	/** Lit billboards: a built-in material is what lets the scene's lights reach them. **/
	static function addSprites():Void {
		spriteMaterial = new Material(Pbr);
		spriteMaterial.metallic = 0.0;
		spriteMaterial.roughness = 0.55;
		for (i in 0...SPRITE_COUNT) {
			final sprite = new Sprite3D(Handle.NONE);
			sprite.setTransform(new Vec3(-3.0 + 2.0 * i, 1.0, -2.5));
			sprite.size = 1.6;
			sprite.setAlphaMode(Mask, 0.5);
			sprite.setMaterial(spriteMaterial);
			scene.add(sprite);
			sprites.push(sprite);
		}
		spriteMaterial.release(); // the sprites hold it
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
					model.setMesh(mesh);
				mesh.release(); // the models hold their own references

			case ASSET_SPRITE:
				final texture = Texture.create(path);
				for (sprite in sprites)
					sprite.setTexture(texture);
				texture.release();

			case ASSET_NORMAL:
				final texture = Texture.create(path);
				spriteMaterial.normalTexture = texture;
				texture.release();
		}
	}

	static function onFrame(dt:Float):Void {
		final keys = Input.getKeyboardState();
		if (keys.isPressed(Digit1))
			sun.enabled = !sun.enabled;
		if (keys.isPressed(Digit2))
			lamp.enabled = !lamp.enabled;
		if (keys.isPressed(Digit3))
			spot.enabled = !spot.enabled;
		if (keys.isPressed(Escape))
			Wgr.requestQuit();

		elapsed += dt;
		for (model in models)
			model.animate(dt);

		// the lamp orbits through the row; the spotlight sweeps left and right
		final lx = Math.sin(elapsed * 0.6) * 5.0;
		final lz = Math.cos(elapsed * 0.6) * 2.0;
		lamp.position = new Vec3(lx, 1.2, lz);
		lampMarker.setTransform(new Vec3(lx, 1.2, lz));
		lampMarker.visible = lamp.enabled;
		spot.direction = new Vec3(Math.sin(elapsed * 0.8) * 0.7, -1.0, -0.3);

		Render.begin();
		Render.clearBackground(background);
		Render.beginMode3D();
		Shape3D.drawGrid(20, 1.0, gridColor);
		Render.endMode3D();
		scene.draw();

		Text.draw("wgrender lights: directional, point, spot", 12, 12, 20, Color.RAYWHITE);
		Text.draw('[1] sun ${on(sun)}   [2] point light ${on(lamp)}   [3] spotlight ${on(spot)}', 12, 40, 16,
			Color.LIGHTGRAY);
		Text.drawFps(12, 64);
		Render.end();
	}

	static inline function on(light:Light):String
		return light.enabled ? "on " : "off";
}
