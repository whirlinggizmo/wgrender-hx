// wgrender's picking example, as a Haxe guest: all three drawable kinds, ray-picked.
//
// A port of examples/pick.c. `scene.pick` does a world-AABB broadphase and then a
// narrow phase per kind: shapes get exact ray/cube and ray/sphere tests, models exact
// ray/triangle against the bind-pose mesh, and sprites test the billboard quad and —
// with alpha-test picking on — reject transparent texels through a CPU mask built from
// the texture on demand. So clicking the hole in the logo misses it.
//
// The camera is fixed, so aiming is predictable, and the readout says what was hit,
// where in world and local space, and how far.
//
//   click  a cube, a sphere, a sprite or a model
//   ESC    quit
//
// The class is `PickDemo` because a module named `Pick` would shadow `wgr.Pick`.
import wgr.*;

@:expose("WgrGuest")
class PickDemo {
	static inline final SCREEN_WIDTH = 900;
	static inline final SCREEN_HEIGHT = 700;
	static inline final LOGO_PATH = "sprites/logo/wg-logo-bw-alpha.png";
	static inline final MODEL_PATH = "models/gumshoe/gumshoe.glb";
	static inline final ASSET_LOGO = 1;
	static inline final ASSET_MODEL = 2;

	static var background:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var cube:Shape3D;
	static var sphere:Shape3D;
	static var sprite:Sprite3D;
	static var model:Model;
	static var selected:Handle = Handle.NONE;
	static var last:PickResult;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "pick (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(24, 26, 34, 255);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(11.0, 9.0, 11.0), new Vec3(0, 2.0, 0));
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		// scenes start unlit: a sun and some ambient, so the model can be seen
		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.6, -1.0, -0.5));
		Light.setIntensity(sun, 3.0);
		Scene.add(scene, sun);
		Scene.setAmbient(scene, Color.WHITE, 0.3);

		cube = Shape3D.create();
		Shape3D.setCube(cube, new Vec3(2.0, 2.0, 2.0));
		Shape3D.setTransform(cube, new Vec3(-3.5, 1.0, 0), new Vec3(0, 0.6, 0), Vec3.ONE);
		Shape3D.setColor(cube, Color.ORANGE);
		Scene.add(scene, cube);

		sphere = Shape3D.create();
		Shape3D.setSphere(sphere, 1.5);
		Shape3D.setPosition(sphere, new Vec3(3.5, 1.5, 0));
		Shape3D.setColor(sphere, Color.GOLD);
		Scene.add(scene, sphere);

		load(LOGO_PATH, ASSET_LOGO);
		load(MODEL_PATH, ASSET_MODEL);
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
		switch id {
			case ASSET_LOGO:
				final texture = Texture.create(path);
				sprite = Sprite3D.create(texture);
				Texture.release(texture); // the sprite holds its own reference
				if (Sprite3D.isNone(sprite))
					return;
				Sprite3D.setSize(sprite, 4.0);
				Sprite3D.setFacing(sprite, Camera);
				Sprite3D.setTint(sprite, Color.WHITE);
				Sprite3D.setPosition(sprite, new Vec3(0, 3.0, 4.0));
				// the transparent parts of the logo let the click through
				Sprite3D.setPickAlphaTest(sprite, true, 0.5);
				Scene.add(scene, sprite, 1);

			case ASSET_MODEL:
				final mesh = Mesh.create(path);
				model = Model.create(mesh);
				Mesh.release(mesh); // the model holds its own reference
				if (Model.isNone(model))
					return;
				Model.setPosition(model, new Vec3(0, 0, -4.0));
				Model.setTint(model, Color.RAYWHITE);
				Scene.add(scene, model);
		}
	}

	static function kindName(handle:Handle):String {
		return switch Handle.getKind(handle) {
			case Shape3D: "shape";
			case Sprite3D: "sprite3d";
			case Model: "model";
			case _: "?";
		}
	}

	/** Shapes can be recoloured to show selection; the other kinds just get reported. **/
	static function restingColor(shape:Handle):Color {
		if (shape == cube)
			return Color.ORANGE;
		if (shape == sphere)
			return Color.GOLD;
		return Color.RAYWHITE;
	}

	static function select(hit:Handle):Void {
		if (hit == selected)
			return;
		// The kind is the test, not a list of known handles: only a shape can be
		// recoloured, and `kind` answers that for any handle at all.
		if (Handle.getKind(selected) == Shape3D)
			Shape3D.setColor((selected : Shape3D), restingColor(selected));
		selected = hit;
		if (Handle.getKind(selected) == Shape3D)
			Shape3D.setColor((selected : Shape3D), Color.RAYWHITE);
	}

	static function onFrame(dt:Float):Void {
		final mouse = Input.getMouseState();
		if (mouse.left == ButtonState.Pressed) {
			last = Scene.pick(scene, mouse.x, mouse.y);
			select(last.hit ? last.handle : Handle.NONE);
		}

		Render.begin();
		Render.clearBackground(background);
		Render.beginMode3D();
		Shape3D.drawGrid(24, 1.0, Color.DARKGRAY);
		Render.endMode3D();
		Scene.draw(scene);

		Text.draw("wgrender + sokol — picking", 12, 36, 24, Color.RAYWHITE);
		Text.draw("click cube / sphere / sprite / model", 12, 70, 16, Color.LIGHTGRAY);
		if (last != null && last.hit) {
			Text.draw('hit ${kindName(last.handle)} (handle ${last.handle})', 12, 94, 16, Color.LIME);
			Text.draw('world ${vec(last.pointWorld)}   dist ${fixed(last.distance, 2)}', 12, 114, 16,
				Color.LIGHTGRAY);
			Text.draw('local ${vec(last.pointLocal)}', 12, 134, 16, Color.LIGHTGRAY);
		} else {
			Text.draw("no hit", 12, 94, 16, Color.LIGHTGRAY);
		}
		Render.end();

		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();
	}

	static inline function vec(v:Vec3):String
		return '${fixed(v.x, 2)}, ${fixed(v.y, 2)}, ${fixed(v.z, 2)}';

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
