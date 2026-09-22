// wgrender's instancing example, as a Haxe guest: many models that share a mesh.
//
// A port of examples/instancing.c, and the thing to notice is that nothing here asks
// for instancing. It is what wgrender does when models agree on everything but where
// they stand: a field of 400 cubes shares one mesh and one material and differs only
// in transform and tint, so it goes up as one draw. Six gumshoes share one skinned
// mesh and animate out of step, so their joints are per instance. A few cubes are
// see-through and keep their back-to-front order. The sun casts, so the same batching
// happens again into its shadow map.
//
//   SPACE  give every cube its own material -- the same picture, drawn one at a time
//   ESC    quit
import wgr.*;

@:expose("WgrGuest")
class Instancing {
	static inline final SCREEN_WIDTH = 1024;
	static inline final SCREEN_HEIGHT = 720;
	static inline final MODEL_PATH = "models/gumshoe/gumshoe.glb";

	static inline final FIELD_SIDE = 20;
	static inline final FIELD_COUNT = FIELD_SIDE * FIELD_SIDE;
	static inline final WALKERS = 6;
	static inline final GLASS = 5;

	static var scene:Scene;
	static var camera:Camera3D;
	static var target:Vec3;
	static var cubes:Array<Model> = [];
	static var walkers:Array<Model> = [];
	static var sharedMaterial:Material;
	static var ownMaterials = false;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "instancing (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		target = new Vec3(0, 1.0, 0);
		camera = Camera3D.create(Perspective);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.5, -1.0, -0.4));
		Light.setIntensity(sun, 3.0);
		Light.setShadowDistance(sun, 60.0);
		Light.setCastsShadows(sun, true); // the depth pass batches the same way
		Scene.add(scene, sun);
		Scene.setAmbient(scene, Color.rgba(160, 180, 220, 255), 0.35);
		Debug.enableFps(12, 10, 16);

		addFloor();
		addField();
		addWalkers();
	}

	/** Something for the shadows to land on. **/
	static function addFloor():Void {
		final mesh = Mesh.plane(60.0, 60.0, 0);
		final material = Material.create(Pbr);
		Material.setBaseColor(material, 0.45, 0.47, 0.5, 1.0);
		Material.setRoughness(material, 0.9);
		final floor = Model.create(mesh);
		Model.setMaterial(floor, -1, material);
		Model.setTransform(floor, new Vec3(0, -0.6, 0));
		Scene.add(scene, floor);
		Mesh.release(mesh);
		Material.release(material);
	}

	static function fieldTint(i:Int, alpha:Int):Color {
		final hue = i / FIELD_COUNT;
		return Color.rgba(Std.int(120 + 135 * Math.sin(hue * 6.28)), Std.int(120 + 135 * Math.sin(hue * 6.28 + 2.1)),
			Std.int(120 + 135 * Math.sin(hue * 6.28 + 4.2)), alpha);
	}

	static function addField():Void {
		// One mesh and one material for the lot; only the transform and tint differ.
		final cube = Mesh.cube(0.6, 0.6, 0.6);
		sharedMaterial = Material.create(Pbr);
		Material.setRoughness(sharedMaterial, 0.5);
		for (i in 0...FIELD_COUNT) {
			final model = Model.create(cube);
			Model.setTint(model, fieldTint(i, 255));
			Scene.add(scene, model);
			cubes.push(model);
		}
		setMaterials(false);

		// See-through copies of the same cube: same mesh, same material, alpha in the
		// tint, and they keep their back-to-front order rather than joining the batch.
		for (i in 0...GLASS) {
			final glass = Model.create(cube);
			Model.setMaterial(glass, -1, sharedMaterial);
			Model.setTint(glass, Color.rgba(255, 255, 255, 110));
			Model.setTransform(glass, new Vec3(i * 2.0 - 4.0, 5.2, 5.0), null, new Vec3(2, 2, 2));
			Scene.add(scene, glass);
		}
		Mesh.release(cube);
	}

	/** Six walkers sharing one skinned mesh, each at its own point in the walk. **/
	static function addWalkers():Void {
		for (i in 0...WALKERS) {
			final walker = Model.create(Handle.NONE);
			Model.setTransform(walker, new Vec3(i * 2.4 - 6.0, 0.0, -2.0), new Vec3(0, Math.PI, 0));
			Model.setAnimation(walker, 3);
			Model.setAnimationLoop(walker, true);
			Scene.add(scene, walker);
			walkers.push(walker);
			// One load per walker, as the C does: the id is the index, where the C
			// passes the handle through the callback's void *.
			GuestAbi.loadAsset(MODEL_PATH, i + 1);
		}
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		// A bounds check, not a null one: Model is an abstract over Int, so there is
		// no null to compare against on a static target.
		if (id < 1 || id > walkers.length)
			return;
		final walker = walkers[id - 1];
		final mesh = Mesh.create(path); // the same resource for every walker
		Model.setMesh(walker, mesh);
		Mesh.release(mesh);
	}

	/** One material for every cube, or one each: the same picture, batched or not. **/
	static function setMaterials(own:Bool):Void {
		for (cube in cubes) {
			if (own) {
				final material = Material.create(Pbr);
				Material.setRoughness(material, 0.5);
				Model.setMaterial(cube, -1, material);
				Material.release(material); // the model keeps its reference
			} else {
				Model.setMaterial(cube, -1, sharedMaterial);
			}
		}
		ownMaterials = own;
	}

	static function onFrame(dt:Float):Void {
		final t = Wgr.getTime();
		Camera3D.setView(camera, new Vec3(Math.sin(t * 0.15) * 22.0, 12.0, Math.cos(t * 0.15) * 22.0), target);

		for (i in 0...FIELD_COUNT) {
			final x = ((i % FIELD_SIDE) - FIELD_SIDE * 0.5 + 0.5) * 1.5;
			final z = (Std.int(i / FIELD_SIDE) - FIELD_SIDE * 0.5 + 0.5) * 1.5;
			final wave = Math.sin(t * 1.5 + x * 0.6 + z * 0.4);
			// Well clear of the floor, so every cube throws its own shadow onto it.
			Model.setTransform(cubes[i], new Vec3(x, 2.4 + wave * 0.5, z), new Vec3(0, t * 0.3 + i, 0));
		}
		// The same walk, out of step: a shared mesh, but each its own pose.
		for (i in 0...WALKERS)
			Model.setAnimationTime(walkers[i], t + i * 0.35);

		Render.begin();
		Render.clearBackground(Color.rgba(28, 30, 38, 255));
		Scene.draw(scene);
		Text.draw("wgrender instancing: models that share a mesh and a material go up as one draw", 12, 36, 20,
			Color.RAYWHITE);
		Text.draw('$FIELD_COUNT cubes, ${ownMaterials ? "a material each (one draw each)" : "one material (one draw)"}'
			+ "   SPACE toggles   ESC quit", 12, 64, 16, Color.LIGHTGRAY);
		Render.end();

		final keys = Input.getKeyboardState();
		if (keys.isPressed(Space))
			setMaterials(!ownMaterials);
		if (keys.isPressed(Escape))
			Wgr.requestQuit();
	}
}
