// wgrender's model example, as a Haxe guest: a glTF model, loaded async and animated.
//
// A port of examples/model.c. The order is the point: the Model is created empty and
// added to the scene straight away, and the mesh is attached when it arrives -- so
// nothing in the frame loop has to ask whether it is there yet, and the model simply
// appears. Every animation setting is made before the mesh exists and is a no-op until
// it does.
//
// The C carries the model handle through the callback's `void *`, since a local would
// dangle by the time it fires. The guest ABI has no user pointer -- the asset op hands
// back an id -- so here it is a static and the question does not arise.
//
//   ESC  quit
//
// The class is `ModelDemo` because a module named `Model` would shadow `wgr.Model`.
import wgr.*;

@:expose("WgrGuest")
class ModelDemo {
	static inline final SCREEN_WIDTH = 900;
	static inline final SCREEN_HEIGHT = 700;
	static inline final MODEL_PATH = "models/gumshoe/gumshoe.glb";
	static inline final ASSET_MESH = 1;

	static inline final ORBIT_SPEED = 0.4;
	static inline final ORBIT_RADIUS = 9.0;

	static var background:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var model:Model;
	static var target:Vec3;
	static var loaded = false;
	static var orbitCamera = true;
	static var spinModel = false;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "model (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(30, 32, 40, 255);
		target = new Vec3(0, 3, 0);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(8, 8, 8), target);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		// A scene starts unlit: it needs a sun and some ambient before anything shows.
		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.6, -1.0, -0.5));
		Light.setIntensity(sun, 3.0); // about pi: a white surface facing it shows its full colour
		Scene.add(scene, sun);
		Scene.setAmbient(scene, Color.WHITE, 0.3);
		Debug.enableFps(12, 10, 16);

		model = Model.create(Handle.NONE); // empty: the mesh is attached when it loads
		Model.setPosition(model, new Vec3(0, 0, 0));
		Model.setTint(model, Color.RAYWHITE);
		// Skeletal animation, if the glTF has any; a no-op until the mesh arrives.
		Model.setAnimation(model, 3);
		Model.setAnimationSpeed(model, 1.0);
		Model.setAnimationLoop(model, true);
		Scene.add(scene, model);

		if (!GuestAbi.loadAsset(MODEL_PATH, ASSET_MESH))
			Log.error('failed to queue asset: $MODEL_PATH');
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('model load failed: $path');
			return;
		}
		if (id != ASSET_MESH)
			return;
		final mesh = Mesh.create(path);
		Model.setMesh(model, mesh);
		Mesh.release(mesh); // the model holds its own reference
		loaded = true;
	}

	static function onFrame(dt:Float):Void {
		final t = Wgr.getTime();

		if (orbitCamera)
			Camera3D.setView(camera, new Vec3(Math.cos(t * ORBIT_SPEED) * ORBIT_RADIUS, 7.0,
				Math.sin(t * ORBIT_SPEED) * ORBIT_RADIUS), target);
		if (spinModel)
			Model.setTransform(model, new Vec3(0, 0, 0), new Vec3(0, t * 0.5, 0), Vec3.ONE);
		Model.animate(model, dt);

		Render.beginFrame();
		Render.clearBackground(background);

		Render.beginMode3D();
		Shape3D.drawGrid(20, 1.0, Color.DARKGRAY);
		Render.endMode3D();

		Scene.draw(scene);

		Text.draw("wgrender + sokol — model (glTF/cgltf)", 12, 36, 22, Color.RAYWHITE);
		Text.draw(loaded ? "gumshoe.glb — skeletal animation (glTF skin)" : "loading model...", 12, 68, 16,
			Color.LIGHTGRAY);
		Render.endFrame();

		if (Input.getKeyboardState().isPressed(Escape))
			Wgr.requestQuit();
	}
}
