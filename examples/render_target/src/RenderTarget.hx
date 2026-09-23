// wgrender's render target example, as a Haxe guest: drawing into textures.
//
// A port of examples/render_target.c. Three targets, each showing a different reason
// to have one:
//
//   pixel view  the scene into a 160x100 texture, shown 4x larger with nearest
//               filtering -- a low-resolution look that costs a quarter of the pixels
//   minimap     the same scene from a top-down orthographic camera, 256x256
//   label       text in two fonts into a 256x128 texture, which is then the base
//               colour texture of the spinning globe's material, and shown on its own
//
// The order in the frame matters and is the point of the example: the label is drawn
// first, so the views that use it show *this* frame's text rather than last frame's.
//
//   ESC  quit
import wgr.*;

@:expose("WgrGuest")
class RenderTarget {
	static inline final SCREEN_WIDTH = 1024;
	static inline final SCREEN_HEIGHT = 700;
	static inline final GUMSHOE_PATH = "models/gumshoe/gumshoe.glb";
	static inline final SPHERE_PATH = "models/sphere/sphere.glb";
	static inline final FONT_PATH = "fonts/Komika/KOMIKAH_.ttf";

	static inline final ASSET_GUMSHOE = 1;
	static inline final ASSET_SPHERE = 2;
	static inline final ASSET_FONT = 3;

	static inline final PIXEL_W = 160;
	static inline final PIXEL_H = 100;
	static inline final PIXEL_SCALE = 4;
	static inline final MINIMAP = 256;
	static inline final LABEL_W = 256;
	static inline final LABEL_H = 128;

	static var background:Color;
	static var labelBackground:Color;
	static var minimapBackground:Color;
	static var frameColor:Color;

	static var scene:Scene;
	static var camera:Camera3D;
	static var topCamera:Camera3D;
	static var pixelView:Texture;
	static var minimap:Texture;
	static var label:Texture;
	static var font:Font;
	static var gumshoe:Model;
	static var globe:Model;
	static var ground:Model;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "render_target (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		background = Color.rgba(24, 26, 34, 255);
		labelBackground = Color.rgba(30, 60, 140, 255);
		minimapBackground = Color.rgba(12, 14, 18, 255);
		frameColor = Color.rgba(90, 96, 110, 255);

		pixelView = Texture.createTarget(PIXEL_W, PIXEL_H);
		// nearest, so enlarging it keeps the pixels square rather than smearing them
		Texture.setSampling(pixelView, Clamp, Clamp, Nearest);
		minimap = Texture.createTarget(MINIMAP, MINIMAP);
		label = Texture.createTarget(LABEL_W, LABEL_H);

		scene = Scene.create();
		camera = Camera3D.create(Perspective);
		Camera3D.setView(camera, new Vec3(0, 6.0, 10.0), new Vec3(0, 0.8, 0));
		topCamera = Camera3D.create(Orthographic);
		// looking down, with -z up the map
		Camera3D.setView(topCamera, new Vec3(0, 12, 0), new Vec3(0, 0, 0), new Vec3(0, 0, -1));
		Camera3D.setOrthoHeight(topCamera, 9.0);

		final sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.5, -1.0, -0.4));
		Light.setIntensity(sun, 3.0);
		Scene.add(scene, sun);
		Scene.setAmbient(scene, Color.WHITE, 0.25);

		addModels();
		load(GUMSHOE_PATH, ASSET_GUMSHOE);
		load(SPHERE_PATH, ASSET_SPHERE);
		load(FONT_PATH, ASSET_FONT);
	}

	static function load(path:String, id:Int):Void {
		if (!GuestAbi.loadAsset(path, id))
			Log.error('failed to queue asset: $path');
	}

	static function model(position:Vec3, scaleY:Float, scale:Float, material:Material):Model {
		final m = Model.create(Handle.NONE); // the mesh arrives later
		Model.setTransform(m, position, Vec3.ZERO, new Vec3(scale, scaleY, scale));
		if (!Material.isNone(material)) {
			Model.setMaterial(m, 0, material);
			Material.release(material); // the model keeps its own reference
		}
		Scene.add(scene, m);
		return m;
	}

	static function addModels():Void {
		// ground: a flattened sphere
		final groundMaterial = Material.create(Pbr);
		Material.setBaseColor(groundMaterial, 0.25, 0.3, 0.25, 1.0);
		Material.setMetallic(groundMaterial, 0.0);
		ground = model(new Vec3(0, -0.05, 0), 0.1, 8.0, groundMaterial);

		gumshoe = Model.create(Handle.NONE);
		Model.setAnimation(gumshoe, 3);
		Scene.add(scene, gumshoe);

		// The globe wears the label: a target texture used like any other texture.
		final globeMaterial = Material.create(Unlit);
		Material.setTexture(globeMaterial, "base_color_texture", label);
		Material.setVec2(globeMaterial, "base_color_texture_scale", 2.0, 1.0); // twice around
		globe = model(new Vec3(2.2, 1.2, 0), 1.6, 1.6, globeMaterial);
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		switch id {
			case ASSET_GUMSHOE:
				final mesh = Mesh.create(path);
				Model.setMesh(gumshoe, mesh);
				Mesh.release(mesh);

			case ASSET_SPHERE:
				final mesh = Mesh.create(path);
				Model.setMesh(globe, mesh);
				Model.setMesh(ground, mesh);
				Mesh.release(mesh);

			case ASSET_FONT:
				font = Font.create(path);
		}
	}

	/** A texture with a 2px frame and a caption above it. **/
	static function panel(texture:Texture, x:Float, y:Float, w:Float, h:Float, caption:String):Void {
		Shape2D.drawRectangle(x - 2, y - 2, w + 4, h + 4, frameColor);
		Texture.draw(texture, x, y, w, h, Color.WHITE);
		Text.draw(caption, Std.int(x), Std.int(y) - 20, 16, Color.LIGHTGRAY);
	}

	static function onFrame(dt:Float):Void {
		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();

		elapsed += dt;
		final gx = Math.cos(elapsed * 0.6) * 2.5;
		final gz = Math.sin(elapsed * 0.6) * 2.5;
		Model.setTransform(gumshoe, new Vec3(gx, 0, gz), new Vec3(0, -elapsed * 0.6, 0),
			new Vec3(0.6, 0.6, 0.6)); // walks in a circle
		Model.animate(gumshoe, dt);
		Model.setTransform(globe, new Vec3(-2.2, 1.2, 0), new Vec3(0, elapsed * 0.8, 0), new Vec3(1.6, 1.6, 1.6));

		Render.begin();

		// 1. the label first, so the views below use this frame's text
		if (Render.beginTexture(label)) {
			Render.clearBackground(labelBackground);
			if (!Font.isNone(font))
				Font.draw(font, "wgrender", 20, 14, 64, Color.RAYWHITE);
			Text.draw('t = ${fixed(elapsed, 1)}', 24, 92, 16, Color.GOLD);
			Render.endTexture();
		}

		// 2. a low-resolution view of the scene
		if (Render.beginTexture(pixelView)) {
			Render.clearBackground(background);
			Scene.setActiveCamera(scene, camera);
			Scene.draw(scene);
			Render.endTexture();
		}

		// 3. the minimap, from above
		if (Render.beginTexture(minimap)) {
			Render.clearBackground(minimapBackground);
			Scene.setActiveCamera(scene, topCamera);
			Scene.draw(scene);
			Render.endTexture();
		}

		// the screen
		Render.clearBackground(background);
		panel(pixelView, 24, 64, PIXEL_W * PIXEL_SCALE, PIXEL_H * PIXEL_SCALE, "pixel view (160x100, nearest)");
		panel(minimap, 700, 64, MINIMAP, MINIMAP, "minimap (orthographic, from above)");
		panel(label, 700, 380, LABEL_W, LABEL_H, "label (text drawn into a texture)");
		Text.draw("wgrender render targets: Texture.createTarget + Render.beginTexture", 12, 12, 16, Color.RAYWHITE);
		Render.end();
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
