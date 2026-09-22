// wgrender's sprite3d example, as a Haxe guest: a textured billboard in a scene.
//
// A port of examples/sprite3d.c, and the shortest statement of wgrender's resource
// rule: the asset op hands back a local path, `Texture.create` makes the resource,
// `Sprite3D.create(texture)` makes the object, and the texture is released because the
// object now holds its own reference. Nothing here is a Haxe idiom -- it is the C flow
// with the casts gone.
//
//   ESC  quit
//
// The class is `Sprite3DDemo` because a module named `Sprite3D` would shadow
// `wgr.Sprite3D` inside itself.
import wgr.*;

@:expose("WgrGuest")
class Sprite3DDemo {
	static inline final SCREEN_WIDTH = 900;
	static inline final SCREEN_HEIGHT = 700;
	static inline final LOGO_PATH = "sprites/logo/wg-logo-bw-alpha.png";
	static inline final ASSET_LOGO = 1;

	static inline final ORBIT_SPEED = 0.3;
	static inline final ORBIT_RADIUS = 13.0;
	static inline final BOB_SPEED = 1.5;
	static inline final BOB_HEIGHT = 0.8;
	static inline final BOB_CENTRE = 3.5;

	static var background:Color;
	static var scene:Scene;
	static var camera:Camera3D;
	static var sprite:Sprite3D;
	static var target:Vec3;
	static var up:Vec3;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "sprite3d (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(20, 22, 30, 255);
		target = new Vec3(0, 2.5, 0);
		up = new Vec3(0, 1, 0);

		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(12, 7, 12), target, up);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);

		// a pedestal, for somewhere to sit above and something to judge depth by
		final pedestal = Shape3D.create();
		Shape3D.setCube(pedestal, new Vec3(3.0, 0.5, 3.0));
		Shape3D.setTransform(pedestal, new Vec3(0, 0.25, 0));
		Shape3D.setColor(pedestal, Color.DARKGRAY);
		Scene.add(scene, pedestal);

		if (!GuestAbi.loadAsset(LOGO_PATH, ASSET_LOGO))
			Log.error('failed to queue asset: $LOGO_PATH');
		Debug.enableFps(12, 10, 16);
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('could not load $path');
			return;
		}
		if (id != ASSET_LOGO)
			return;
		final texture = Texture.create(path);
		sprite = Sprite3D.create(texture);
		Texture.release(texture); // the sprite holds its own reference
		if (Sprite3D.isNone(sprite))
			return;
		Sprite3D.setSize(sprite, 6.0);
		Sprite3D.setFacing(sprite, Camera);
		Sprite3D.setTint(sprite, Color.WHITE);
		Scene.add(scene, sprite);
	}

	static function onFrame(dt:Float):Void {
		final t = Wgr.getTime();

		Camera3D.setView(camera, new Vec3(Math.cos(t * ORBIT_SPEED) * ORBIT_RADIUS, 7.0,
			Math.sin(t * ORBIT_SPEED) * ORBIT_RADIUS), target, up);

		if (!Sprite3D.isNone(sprite))
			Sprite3D.setTransform(sprite, new Vec3(0, BOB_CENTRE + Math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0));

		Render.begin();
		Render.clearBackground(background);

		Render.beginMode3D();
		Shape3D.drawGrid(20, 1.0, Color.DARKGRAY);
		Render.endMode3D();

		Scene.draw(scene);

		Text.draw("wgrender + sokol — sprite3d (Haxe guest)", 12, 36, 24, Color.RAYWHITE);
		Text.draw(Sprite3D.isNone(sprite) ? "loading logo..." : "logo: load -> Texture.create -> new Sprite3D", 12, 70, 16,
			Color.LIGHTGRAY);

		Render.end();

		if (Input.getKeyboardState().isPressed(Escape))
			Wgr.requestQuit();
	}
}
