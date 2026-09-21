// Runs the binding against a headless wgrender and asserts what it gets back.
//
// It used to only compile, which proves the API exists but not that it is wired to the
// right C call — a grouped wrapper with two arguments transposed compiles perfectly.
// These assertions catch that class: field order in the struct reads, property
// round-trips, packing, and the handful of behaviours that are cheap to state exactly.
//
// `./build.py check` builds this against build/headless/libwgrender.a (no window, GPU
// or audio) and runs it for a few frames. Non-zero exit means a failure.
import wgr.*;

class CheckBindings {
	static inline final WIDTH = 640;
	static inline final HEIGHT = 480;

	static var checks = 0;
	static var failures = 0;
	static var frames = 0;

	static var scene:Scene;
	static var camera:Camera3D;
	static var model:Model;
	static var confetti:Emitter2D;
	static var label:Text2D;
	static var debugFont:Font;

	/** Deliberately never assigned: a field needs no initialiser (a local does). **/
	static var neverSet:Model;

	static function check(ok:Bool, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (!ok) {
			failures++;
			Sys.println('FAIL ${pos.fileName}:${pos.lineNumber}  $what');
		}
	}

	static function eq(actual:Dynamic, expected:Dynamic, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (actual != expected) {
			failures++;
			Sys.println('FAIL ${pos.fileName}:${pos.lineNumber}  $what: got $actual, expected $expected');
		}
	}

	static function near(actual:Float, expected:Float, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (Math.abs(actual - expected) > 0.001) {
			failures++;
			Sys.println('FAIL ${pos.fileName}:${pos.lineNumber}  $what: got $actual, expected ~$expected');
		}
	}

	// --- values and packing -------------------------------------------------

	static function checkValues():Void {
		// a field with no initialiser is none — the thing that is quietly wrong on js
		// if isNone only tests == 0
		check(neverSet.isNone, "an uninitialised handle field is none");
		check(Handle.NONE.isNone, "Handle.NONE is none");

		// 0xRRGGBBAA, which is what every colour constant in wgr_color.h is
		eq((Color.rgba(0x12, 0x34, 0x56, 0x78) : Int), 0x12345678, "Color.rgba packs RRGGBBAA");
		eq((Color.rgba(255, 255, 255, 255) : Int), (Color.WHITE : Int), "rgba(255,255,255,255) is WHITE");
		eq((Color.rgba(0, 0, 0, 255) : Int), (Color.BLACK : Int), "rgba(0,0,0,255) is BLACK");
		eq((Color.rgba(245, 245, 245, 255) : Int), (Color.RAYWHITE : Int), "RAYWHITE");

		// enum values against wgr_types.h / wgr_keys.h
		eq((ButtonState.Up : Int), 0, "ButtonState.Up");
		eq((ButtonState.Pressed : Int), 1, "ButtonState.Pressed");
		eq((ButtonState.Released : Int), 3, "ButtonState.Released");
		eq((SpriteFacing.Free : Int), 3, "SpriteFacing.Free");
		eq((AlphaMode.Add : Int), 3, "AlphaMode.Add is the default mode");
		eq((Key.Escape : Int), 256, "Key.Escape");
		eq((Key.Space : Int), 32, "Key.Space");
		eq((AlignX.Left : Int), 0, "AlignX.Left");
		eq((AlignY.Middle : Int), 4, "AlignY.Middle — the two align enums share one C enum");
		eq((WindowFlag.Msaa4x | WindowFlag.Resizable : Int), 0x24, "window flags or together");

		check(Wgr.getPlatform().length > 0, "getPlatform is not empty");
		// the binding was generated from a particular wgrender; this is the one running
		eq(Version.runtime(), Version.BUILT, "the running library matches what we built against");
		check(Version.check(), "Version.check agrees");
		check(Version.runtimeLabelled().indexOf(Version.BUILT) == 0, "the labelled string starts with it");
		check(Assets.defaultBase().length > 0, "an asset base was resolved");
		check(Wgr.getTime() >= 0, "getTime is sane");
	}

	// --- struct reads: the field order a compile check cannot see -----------

	static function checkStructs():Void {
		final screen = Window.getScreenSize();
		near(screen.x, WIDTH, "screen width — vec2_t field order");
		near(screen.y, HEIGHT, "screen height");

		final mouse = Input.getMouseState();
		eq(mouse.buttons.length, 3, "mouse buttons array");
		check(mouse.x == 0 && mouse.y == 0, "no pointer in headless, so the mouse is at the origin");

		// nothing in the scene yet, so a pick must miss rather than report garbage
		final miss = scene.pick(WIDTH / 2, HEIGHT / 2);
		check(!miss.hit, "picking an empty scene misses");
		check(miss.handle.isNone, "a miss carries no handle");

		final wide = Text.measure("iiii", 16);
		final wider = Text.measure("WWWWWWWW", 16);
		check(wide > 0, "built-in text measures wider than nothing");
		check(wider > wide, "eight characters measure wider than four");
	}

	// --- handles, properties and the round-trips that have getters ----------

	static function checkHandles():Void {
		check(!scene.isNone, "scene created");
		check(!camera.isNone, "camera created");

		final light = new Light(Point);
		check(!light.isNone, "light created");
		check(light.enabled, "a light starts enabled");
		light.enabled = false;
		check(!light.enabled, "light.enabled round-trips");
		light.enabled = true;
		// Directional and spot lights cast; a point light is refused, because it would
		// need six maps (wgr_light.c: "point lights don't cast shadows yet").
		// NB wgr_light.h's comment still says spot is ignored too — it is out of date.
		check(!light.castsShadows, "a light starts not casting");
		light.castsShadows = true;
		check(!light.castsShadows, "a point light refuses to cast: it would need a cube map");

		final sun = new Light(Directional);
		sun.castsShadows = true;
		check(sun.castsShadows, "a directional light casts, and it round-trips");
		sun.destroy();

		final torch = new Light(Spot);
		torch.setSpotCone(0.3, 0.6);
		torch.castsShadows = true;
		check(torch.castsShadows, "a spot light casts too — wgri_shadow_fit_spot");
		torch.destroy();
		light.color = Color.GOLD;
		light.position = new Vec3(1, 2, 3);
		light.range = 10;
		light.setSpotCone(0.2, 0.4);
		light.setShadowBias(0.002, 2);
		light.shadowDistance = 50;
		light.shadowMapSize = 512;
		light.shadowStrength = 0.5;
		light.shadowColor = Color.BLACK;
		light.destroy();

		final material = new Material(Pbr);
		check(!material.isNone, "material created");
		eq((material.shading : Int), (MaterialShading.Pbr : Int), "a new material is Pbr");
		material.shading = Unlit;
		eq((material.shading : Int), (MaterialShading.Unlit : Int), "material.shading round-trips");
		check(!material.doubleSided, "a new material is single sided");
		material.doubleSided = true;
		check(material.doubleSided, "material.doubleSided round-trips");
		check(material.setFloat("roughness", 0.5), "a known parameter name is accepted");
		check(!material.setFloat("no_such_parameter", 1), "an unknown parameter name is refused");
		material.metallic = 0.5;
		material.normalScale = 1;
		material.occlusionStrength = 1;
		material.setBaseColor(1, 1, 1);
		material.setEmissive(0, 0, 0);
		material.setVec2("v", 1, 2);
		material.setInt("i", 1);
		material.setColor("c", Color.WHITE);
		material.setAlphaMode(Blend);
		check(material.getShader().isNone, "a built-in material has no custom shader");
		material.release();

		// a resource from a path that isn't there must come back as none, not garbage
		check(Texture.create("no/such/texture.png").isNone, "a missing texture is none");
		check(Mesh.create("no/such/mesh.glb").isNone, "a missing mesh is none");
		check(Audio.create("no/such/sound.mp3").isNone, "a missing sound is none");
	}

	static function checkText():Void {
		label = new Text2D(Handle.NONE); // no font yet: the default font
		check(!label.isNone, "text2d created without a font");
		label.text = "measure me";
		label.size = 20;
		label.position = new Vec2(10, 20);
		label.color = Color.BLACK;
		label.maxWidth = 0;
		check(label.visible, "text2d starts visible");
		label.visible = false;
		check(!label.visible, "text2d.visible round-trips");
		label.visible = true;
		check(label.pickable, "text2d starts pickable");
		label.pickable = false;
		check(!label.pickable, "text2d.pickable round-trips");
		label.pickable = true;
		check(label.enabled, "text2d starts enabled");
		label.enabled = false;
		check(!label.enabled, "text2d.enabled round-trips");
		label.enabled = true;
		label.setAlign(Center, Middle);

		final size = label.measure();
		check(size.x > 0 && size.y > 0, "a text2d with text measures larger than nothing");

		final sign = new Text3D(Handle.NONE);
		check(!sign.isNone, "text3d created");
		sign.text = "world";
		sign.size = 1.5;
		sign.color = Color.BLUE;
		sign.facing = CameraFixedY;
		sign.maxWidth = 4;
		sign.setAlign(Left, Bottom);
		sign.setTransform(new Vec3(0, 2, 0), new Vec3(0, Math.PI, 0));
		check(sign.visible && sign.pickable && sign.enabled, "text3d starts visible, pickable and enabled");
		sign.destroy();
	}

	static function checkEmitters():Void {
		final texture = Texture.create("no/such.png"); // none is fine: we assert on counts
		confetti = new Emitter2D(texture);
		check(!confetti.isNone, "emitter2d created");
		confetti.max = 64;
		confetti.setLife(5, 5);
		confetti.setVelocity(new Vec2(0, -10));
		confetti.setGravity(new Vec2(0, 10));
		confetti.setSize(4, 2, 0);
		confetti.setSpin(-1, 1);
		confetti.setColor(Color.WHITE, Color.BLACK);
		confetti.setSource(0, 0, 8, 8);
		confetti.setFrames(2, 2);
		confetti.setAlphaMode(Blend);
		confetti.setSpawnBox(1, 1);
		confetti.setSpawnCircle(1);
		confetti.drag = 0.5;
		confetti.inheritVelocity = 0.5;
		confetti.stretch = 0;
		confetti.seed = 7;
		confetti.addSizeKey(0, 1);
		confetti.clearSizeKeys();
		confetti.addColorKey(0, Color.WHITE);
		confetti.clearColorKeys();
		confetti.addPaletteColor(Color.RED);
		confetti.clearPalette();
		check(confetti.emitting, "an emitter starts emitting");
		eq(confetti.count, 0, "no particles before a frame");
		confetti.burst(10);
		eq(confetti.count, 10, "burst makes particles immediately");
		confetti.clear();
		eq(confetti.count, 0, "clear removes them");
		confetti.emitting = false;
		check(!confetti.emitting, "emitter.emitting round-trips");
		confetti.jump(new Vec2(1, 1));
		confetti.setPosition(new Vec2(2, 2));
		confetti.visible = true;

		final spray = new Emitter3D(texture);
		check(!spray.isNone, "emitter3d created");
		spray.max = 32;
		spray.setLife(5, 5);
		spray.setPosition(new Vec3(0, 0, 0));
		spray.setSpawnBox(new Vec3(1, 1, 1));
		spray.setSpawnSphere(1);
		spray.setVelocity(new Vec3(0, 1, 0), 0.1, 0.1);
		spray.setGravity(new Vec3(0, -9.8, 0));
		eq(spray.count, 0, "an emitter with the default rate of 0 makes nothing");
		spray.rate = 100;
		spray.prewarm(0.1);
		check(spray.count > 0, "prewarm with a rate runs the emitter forward");
		spray.destroy();
		confetti.destroy();
	}

	static function checkScene():Void {
		final mesh = Mesh.create("no/such.glb");
		model = new Model(mesh);
		final sprite = new Sprite3D(Texture.create("no/such.png"));
		final light = new Light(Directional);
		light.direction = new Vec3(0, -1, 0);
		light.intensity = 1;

		// SceneMember takes each kind; the compiler enforces which
		check(scene.add(model), "a model is a scene member");
		check(scene.add(sprite, 1), "a sprite3d is a scene member, on a layer");
		check(scene.add(light), "a light is a scene member");
		check(scene.add(label), "a text2d is a scene member");
		check(scene.setAmbient(Color.WHITE, 0.25), "ambient set");
		scene.activeCamera = camera;

		model.animation = 0;
		model.animationSpeed = 1;
		model.animationLoop = true;
		model.tint = Color.RAYWHITE;
		model.setTransform(new Vec3(0, 0, 0), new Vec3(0, 0, 0), new Vec3(1, 1, 1));
		sprite.facing = Free;
		sprite.tint = Color.WHITE;
		sprite.setTransform(new Vec3(0, 1, 0));

		camera.setView(new Vec3(0, 1, 5), new Vec3(0, 0, 0));
	}

	// --- lifecycle ----------------------------------------------------------

	static function onInit():Void {
		Log.setLevel(Fatal); // the missing-asset checks below log errors on purpose
		camera = new Camera3D(Perspective);
		scene = new Scene();
		scene.activeCamera = camera;

		checkValues();
		checkStructs();
		checkHandles();
		checkText();
		checkEmitters();
		checkScene();
	}

	static function onFrame(dt:Float, tickFraction:Float):Void {
		frames++;
		check(dt >= 0, "dt is not negative");
		if (frames == 1) {
			// these only mean anything once the loop is running
			check(Wgr.getTime() >= 0, "getTime inside a frame");
			eq(Input.getKey(Escape), ButtonState.Up, "no key is down in headless");
			check(!Input.isKeyPressed(Space), "no key was pressed");
		}
		Render.begin();
		Render.clearBackground(Color.RAYWHITE);
		Render.beginMode3D();
		Shape3D.drawGrid(4, 1, Color.DARKGRAY);
		Shape3D.drawCube(new Vec3(0, 0, 0), new Vec3(1, 1, 1), Color.SKYBLUE);
		Shape3D.drawCubeWires(new Vec3(0, 0, 0), new Vec3(1, 1, 1), Color.WHITE);
		Shape3D.drawSphere(new Vec3(0, 0, 0), 1, Color.GOLD);
		Shape3D.drawLine(new Vec3(0, 0, 0), new Vec3(1, 1, 1), Color.LIME);
		Shape3D.drawRectangle(new Vec3(0, 0, 0), 1, 1, Color.RED);
		Shape3D.drawCircle(new Vec3(0, 0, 0), 1, Color.VIOLET);
		Render.endMode3D();
		scene.draw();
		Shape2D.drawRectangle(0, 0, 10, 10, Color.SKYBLUE);
		Shape2D.drawRectangleLines(0, 0, 10, 10, Color.LIME);
		Shape2D.drawLine(new Vec2(0, 0), new Vec2(10, 10), Color.WHITE);
		Shape2D.drawCircle(new Vec2(5, 5), 4, Color.GOLD);
		Shape2D.drawCircleLines(new Vec2(5, 5), 4, Color.VIOLET);
		Shape2D.drawTriangle(new Vec2(0, 0), new Vec2(10, 0), new Vec2(5, 8), Color.RED);
		Shape2D.drawRoundedRectangle(0, 0, 20, 10, 3, Color.SKYBLUE);
		Shape2D.drawRoundedRectangleCorners(0, 0, 20, 10, 1, 2, 3, 4, Color.GOLD);
		Shape2D.drawBorder(0, 0, 20, 10, 1, 1, 1, 1, 2, 2, 2, 2, Color.LIGHTGRAY);
		Text.draw("built-in", 10, 10, 16, Color.BLACK);
		label.draw();
		Render.end();
	}

	public static function main():Void {
		final rc = Wgr.initValues(WIDTH, HEIGHT, "check", Msaa4x | Resizable);
		check(rc != Wgr.ERR_VERSION_MISMATCH, "initValues guards the version like the guest ABI does");
		check(rc == 0, "initValues succeeded");
		Wgr.setInit(onInit);
		Wgr.setFrame(onFrame);
		Wgr.run();

		check(frames > 0, "the loop ran at least one frame");
		Sys.println('${checks - failures}/$checks checks passed over $frames frames');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
