// Touches every wrapper in wgr.Wgr, so the whole binding keeps compiling (and keeps
// type-checking against wgrender's headers) even though Simple.hx uses only part of
// it. `./build.py check` builds this; it is never run.
import wgr.Wgr;

class CheckBindings {
	static function main():Void {
		Wgr.initValues(320, 240, "check", Fullscreen | Resizable | Undecorated | Transparent | Msaa4x | VsyncOff
			| Hidden | LowDpi);
		Wgr.setInit(() -> {});
		Wgr.setFrame((dt, tickFraction) -> {});
		Wgr.setTargetFps(60);
		Wgr.requestQuit();
		trace(Wgr.getPlatform(), Wgr.run());

		Log.setLevel(Trace);
		for (message in [Log.trace, Log.debug, Log.info, Log.warn, Log.error, Log.fatal])
			message("check");

		Asset.setHost("assets");
		final task = Asset.ensureAsync("a.png", "https://example.invalid/a.png", ForceFetch | FileOnly);
		trace(task.isNone, task.then(path -> {}, path -> {}));

		final audio = Audio.create("a.mp3");
		final sound = new Sound(audio);
		audio.release();
		sound.loop = true;
		trace(audio.isNone, sound.isNone, sound.play());

		final mesh = Mesh.create("a.glb");
		final model = new Model(mesh);
		mesh.release();
		model.animation = 0;
		model.animationSpeed = 1;
		model.animationLoop = true;
		model.tint = Color.rgba(1, 2, 3, 4);
		model.setTransform(new Vec3(1, 2, 3), new Vec3(0, 1, 0), {x: 2.0, y: 2.0, z: 2.0});
		trace(mesh.isNone, model.isNone, model.animate(0.016));

		final texture = Texture.create("a.png");
		final sprite = new Sprite3D(texture);
		texture.release();
		sprite.facing = CameraFixedY;
		sprite.tint = Color.WHITE;
		sprite.setTransform(new Vec3(0, 1, 0));
		trace(texture.isNone, sprite.isNone, [Camera, CameraFixedY, YUp, Free]);

		final font = Font.create("a.ttf");
		font.draw3D("hi", new Vec3(0, 1, 0), 1, Color.WHITE);
		Text.drawFps(0, 0);
		Text.defaultFont = font;
		trace(Text.defaultFont, Text.defaultFont.isNone);

		// retained text: the string is set once and kept, not re-passed every frame
		final label = new Text2D(font);
		label.text = "hello";
		label.position = new Vec2(10, 20);
		label.size = 18;
		label.color = Color.BLACK;
		label.maxWidth = 200;
		label.visible = true;
		label.pickable = false;
		label.enabled = true;
		label.setAlign(Center, Middle);
		trace(label.isNone, label.visible, label.pickable, label.enabled, label.measure());
		label.draw();

		final sign = new Text3D(Handle.NONE); // no font yet: uses Text.defaultFont
		sign.font = font;
		sign.text = "world";
		sign.size = 1.5;
		sign.color = Color.BLUE;
		sign.maxWidth = 4;
		sign.facing = CameraFixedY;
		sign.visible = true;
		sign.pickable = true;
		sign.enabled = false;
		sign.setAlign(Left, Bottom);
		sign.setTransform(new Vec3(0, 2, 0), new Vec3(0, Math.PI, 0));
		trace(sign.isNone, sign.visible, sign.pickable, sign.enabled, sign.measure());
		sign.draw();
		trace(([Left, Center, Right] : Array<AlignX>), ([Top, Middle, Bottom] : Array<AlignY>));
		font.draw("hi", 0, 0, 12, Color.BLACK);
		font.drawFps(0, 0, 12, Color.BLUE);
		Text.draw("hi", 0, 0, 12, Color.RAYWHITE);
		trace(font.isNone, font.measure("hi", 12), Text.measure("hi", 12));

		final camera = new Camera3D(Orthographic);
		camera.setView(new Vec3(1, 1, 1), new Vec3(0, 0, 0), new Vec3(0, 1, 0));
		final light = new Light(Point);
		light.direction = new Vec3(0, -1, 0);
		light.intensity = 2;
		trace(camera.isNone, light.isNone, new Light(Spot), new Light(Directional), new Camera3D());

		final scene = new Scene();
		scene.activeCamera = camera;
		scene.add(model);
		scene.add(sprite, 1);
		scene.add(light);
		scene.setAmbient(Color.WHITE, 0.25);
		scene.draw();
		final pick = scene.pick(1, 2, camera);
		trace(scene.isNone, pick.hit, pick.handle == model, pick.handle.isNone, pick.distance, pick.pointLocal,
			pick.pointWorld, pick.normalLocal, pick.normalWorld, Handle.NONE);

		scene.add(label);
		scene.add(sign, 2);

		// objects are destroyed, resources released
		for (destroy in [label.destroy, sign.destroy, model.destroy, sprite.destroy, sound.destroy, light.destroy,
			camera.destroy, scene.destroy])
			destroy();
		font.release();

		Render.begin();
		Render.clearBackground(Color.BLACK);
		Render.end();
		trace(Window.getScreenSize());

		final mouse = Input.getMouseState();
		trace(mouse.x, mouse.y, mouse.wheel, mouse.wheelX, mouse.left, mouse.right, mouse.middle, mouse.buttons,
			mouse.dx, mouse.dy);
		trace(Input.getKey(A), Input.isKeyPressed(Escape), Input.isKeyDown(LeftShift), Input.isKeyReleased(F12));
		final keyboard = Input.getKeyboardState();
		trace(keyboard[Space], keyboard.isPressed(Digit0), keyboard.isDown(GraveAccent), keyboard.isReleased(Enter));
		trace(([Up, Pressed, Down, Released] : Array<ButtonState>));
	}
}
