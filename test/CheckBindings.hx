// Touches every wrapper in wgr.Wgr, so the whole binding keeps compiling (and keeps
// type-checking against wgrender's headers) even though Simple.hx uses only part of
// it. `./build.py check` builds this; it is never run.
import wgr.*;

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
		for (message in [Log.verbose, Log.debug, Log.info, Log.warn, Log.error, Log.fatal])
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
		trace(texture.isNone, sprite.isNone, ([Camera, CameraFixedY, YUp, Free] : Array<SpriteFacing>));

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

		trace(Wgr.getTime());

		final material = new Material(Pbr);
		material.shading = Unlit;
		material.doubleSided = true;
		material.metallic = 0.5;
		material.roughness = 0.5;
		material.normalScale = 1;
		material.occlusionStrength = 1;
		material.baseColorTexture = texture;
		material.metallicRoughnessTexture = texture;
		material.normalTexture = texture;
		material.occlusionTexture = texture;
		material.emissiveTexture = texture;
		material.setBaseColor(1, 1, 1);
		material.setEmissive(0, 0, 0);
		material.setAlphaMode(Blend);
		material.setInt("i", 1);
		material.setVec2("v2", 1, 2);
		material.setColor("c", Color.WHITE);
		material.setTextureSampling("base_color_texture", Repeat, Clamp, Nearest);
		texture.setSampling(Mirror, Repeat, Linear);
		trace(material.isNone, material.shading, material.doubleSided, material.getShader(),
			Material.custom(Handle.NONE));
		model.setMaterial(0, material);
		model.setMesh(mesh);
		material.release();

		light.color = Color.WHITE;
		light.position = new Vec3(1, 2, 3);
		light.range = 10;
		light.enabled = true;
		light.castsShadows = true;
		light.shadowDistance = 50;
		light.shadowMapSize = 1024;
		light.shadowStrength = 0.8;
		light.shadowColor = Color.BLACK;
		light.setSpotCone(0.2, 0.4);
		light.setShadowBias(0.002, 2);
		trace(light.enabled, light.castsShadows, ([Pbr, Unlit, Custom] : Array<MaterialShading>),
			([Repeat, Clamp, Mirror] : Array<TextureWrap>), ([Linear, Nearest] : Array<TextureFilter>));

		Render.beginMode3D();
		Shape3D.drawGrid(8, 1, Color.DARKGRAY);
		Shape3D.drawLine(new Vec3(0, 0, 0), new Vec3(1, 1, 1), Color.LIME);
		Shape3D.drawCube(new Vec3(0, 0, 0), new Vec3(1, 2, 3), Color.SKYBLUE);
		Shape3D.drawCubeWires(new Vec3(0, 0, 0), new Vec3(1, 2, 3), Color.WHITE);
		Shape3D.drawSphere(new Vec3(0, 1, 0), 0.5, Color.GOLD);
		Shape3D.drawRectangle(new Vec3(0, 0, 0), 2, 1, Color.RED);
		Shape3D.drawRectangle(new Vec3(0, 0, 0), 2, 1, Color.RED, new Vec3(0, Math.PI, 0));
		Shape3D.drawCircle(new Vec3(0, 0, 0), 1, Color.VIOLET);
		Shape3D.drawCircle(new Vec3(0, 0, 0), 1, Color.VIOLET, new Vec3(0, Math.PI, 0));
		Render.endMode3D();

		Shape2D.drawRectangle(0, 0, 10, 10, Color.SKYBLUE);
		Shape2D.drawRectangleLines(0, 0, 10, 10, Color.LIME);
		Shape2D.drawLine(new Vec2(0, 0), new Vec2(10, 10), Color.WHITE);
		Shape2D.drawCircle(new Vec2(5, 5), 4, Color.GOLD);
		Shape2D.drawCircleLines(new Vec2(5, 5), 4, Color.VIOLET);
		Shape2D.drawTriangle(new Vec2(0, 0), new Vec2(10, 0), new Vec2(5, 8), Color.RED);
		Shape2D.drawRoundedRectangle(0, 0, 20, 10, 3, Color.SKYBLUE);
		Shape2D.drawRoundedRectangleCorners(0, 0, 20, 10, 1, 2, 3, 4, Color.GOLD);
		Shape2D.drawBorder(0, 0, 20, 10, 1, 1, 1, 1, 2, 2, 2, 2, Color.LIGHTGRAY);

		Render.begin();
		Render.clearBackground(Color.BLACK);
		Render.end();
		trace(Window.getScreenSize());

		final mouse = Input.getMouseState();
		trace(mouse.x, mouse.y, mouse.wheel, mouse.wheelX, mouse.left, mouse.right, mouse.middle, mouse.buttons,
			mouse.dx, mouse.dy);
		trace(Input.getKey(A), Input.isKeyPressed(Escape), Input.isKeyDown(LeftShift), Input.isKeyReleased(F12));
		final keyboard = Input.getKeyboardState();
		trace(keyboard[(Space : Key)], keyboard.isPressed(Digit0), keyboard.isDown(GraveAccent), keyboard.isReleased(Enter));
		trace(([Up, Pressed, Down, Released] : Array<ButtonState>));
	}
}
