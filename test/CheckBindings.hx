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

	/** The assertions are target-neutral so js can type-check them; only `main` isn't. **/
	static function say(line:String):Void {
		#if sys
		Sys.println(line);
		#else
		js.Browser.console.log(line);
		#end
	}

	static function check(ok:Bool, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (!ok) {
			failures++;
			say('FAIL ${pos.fileName}:${pos.lineNumber}  $what');
		}
	}

	static function eq(actual:Dynamic, expected:Dynamic, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (actual != expected) {
			failures++;
			say('FAIL ${pos.fileName}:${pos.lineNumber}  $what: got $actual, expected $expected');
		}
	}

	static function near(actual:Float, expected:Float, what:String, ?pos:haxe.PosInfos):Void {
		checks++;
		if (Math.abs(actual - expected) > 0.001) {
			failures++;
			say('FAIL ${pos.fileName}:${pos.lineNumber}  $what: got $actual, expected ~$expected');
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

	static function checkShapes():Void {
		final box = new Shape3D();
		check(!box.isNone, "shape3d created");
		check(box.setCube(new Vec3(1, 2, 3)), "a shape3d takes a cube");
		check(box.setSphere(1), "and a sphere — the last form set wins");
		check(box.setRectangle(2, 1), "and a filled rectangle");
		check(box.setCircle(1), "and a circle outline");
		check(box.setLine(new Vec3(0, 0, 0), new Vec3(1, 1, 1)), "and a line");
		box.color = Color.SKYBLUE;
		box.setTransform(new Vec3(1, 2, 3), new Vec3(0, Math.PI, 0), new Vec3(2, 2, 2));
		check(box.visible, "a shape3d starts visible");
		box.visible = false;
		check(!box.visible, "shape3d.visible round-trips");
		box.visible = true;
		check(box.pickable, "a shape3d starts pickable");
		box.pickable = false;
		check(!box.pickable, "shape3d.pickable round-trips");
		box.pickable = true;
		check(box.enabled, "a shape3d starts enabled");
		box.enabled = false;
		check(!box.enabled, "shape3d.enabled round-trips");
		box.enabled = true;

		// a strip is built point by point, and reset by starting a new one
		check(box.setLineStrip(), "a strip can be started");
		eq(box.pointCount, 0, "a new strip is empty");
		box.addPoint(new Vec3(0, 0, 0));
		box.addPoint(new Vec3(1, 0, 0));
		box.addPoint(new Vec3(1, 1, 0));
		eq(box.pointCount, 3, "addPoint appends");
		box.setLineStrip();
		eq(box.pointCount, 0, "starting again empties it");

		final badge = new Shape2D();
		check(!badge.isNone, "shape2d created");
		check(badge.setRectangle(20, 10, 3), "a shape2d takes a rounded rectangle");
		check(badge.setCircle(5), "and a circle");
		check(badge.setLine(new Vec2(0, 0), new Vec2(10, 0), 2), "and a line with a thickness");
		badge.color = Color.GOLD;
		badge.outline = 2;
		check(badge.setPivot(new Vec2(0.5, 0.5)), "pivot is a fraction of the size, not pixels");
		badge.setTransform(new Vec2(10, 20), Math.PI / 4, new Vec2(2, 2));
		check(badge.visible && badge.pickable && badge.enabled, "a shape2d starts visible, pickable and enabled");
		badge.visible = false;
		check(!badge.visible, "shape2d.visible round-trips");
		badge.visible = true;

		check(scene.add(box), "a shape3d is a scene member");
		check(scene.add(badge, 1), "a shape2d is a scene member, on a layer");
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

	// --- camera, meshes, and the properties with real getters ---------------

	static function checkCamera():Void {
		final c = new Camera3D(Perspective);
		eq(c.projection, Projection.Perspective, "projection reads back as the enum, not an int");
		c.projection = Orthographic;
		eq(c.projection, Projection.Orthographic, "projection round-trips");

		c.fov = 1.0;
		near(c.fov, 1.0, "fov round-trips");
		c.orthoHeight = 4;
		near(c.orthoHeight, 4, "orthoHeight round-trips");

		check(c.setActive(), "setActive succeeded");
		eq((Camera3D.active : Int), (c : Int), "the active camera is the one just set");
		check(!Camera3D.defaultCamera.isNone, "there is a default camera");

		// put the scene's camera back: later checks draw through it
		check(camera.setActive(), "the check camera is active again");
		c.destroy();
	}

	static function checkMeshes():Void {
		// generated geometry: no file, so these work in headless
		final cube = Mesh.cube(1, 1, 1);
		check(!cube.isNone, "a generated cube mesh exists");
		eq(cube.materialCount, 1, "a generated mesh has one material slot");
		check(!cube.getMaterial(0).isNone, "that slot has a material");

		// deduplicated: the same parameters give the same resource
		final again = Mesh.cube(1, 1, 1);
		eq((again : Int), (cube : Int), "the same parameters return the same mesh");
		again.release();

		check(!Mesh.plane(2, 2, 4).isNone, "a generated plane exists");
		check(!Mesh.sphere(1, 8, 16).isNone, "a generated sphere exists");
		check(!Mesh.cylinder(1, 2, 12).isNone, "a generated cylinder exists");
		check(!Mesh.cone(1, 2, 12).isNone, "a generated cone exists");
		check(!Mesh.capsule(0.5, 2, 4, 12).isNone, "a generated capsule exists");
		check(!Mesh.torus(1, 0.25, 8, 16).isNone, "a generated torus exists");
		check(Mesh.cube(0, 1, 1).isNone, "a size of 0 is refused, not silently accepted");

		final m = new Model(cube);
		check(m.isReady, "a model on a generated mesh is ready at once");
		eq(m.animationCount, 0, "a generated mesh brings no animations");
		near(m.getAnimationDuration(0), 0, "no animation has no duration");

		// the boolean properties all default on, and all round-trip
		check(m.visible && m.pickable && m.enabled && m.castsShadow && m.receivesShadow,
			"a new model is visible, pickable, enabled and shadowed both ways");
		m.visible = false;
		m.pickable = false;
		m.enabled = false;
		m.castsShadow = false;
		m.receivesShadow = false;
		check(!m.visible && !m.pickable && !m.enabled && !m.castsShadow && !m.receivesShadow,
			"every model flag round-trips false");
		m.visible = true;

		// the header's promise: a time set before the mesh arrives applies once it does,
		// so it is remembered rather than dropped when there is nothing to pose yet
		m.animationTime = 0.5;
		near(m.animationTime, 0.5, "animationTime is kept with no animation to pose yet");

		// an override changes what this model draws, not what the mesh holds
		final mesh0 = cube.getMaterial(0);
		final custom = new Material(Unlit);
		check(m.setMaterial(0, custom), "a material override is set");
		eq((m.getMaterial(0) : Int), (custom : Int), "the model draws the override");
		eq((cube.getMaterial(0) : Int), (mesh0 : Int), "the mesh's own slot is untouched");
		custom.release();
		m.destroy();
		cube.release();
	}

	static function checkSprite3D():Void {
		final texture = Texture.create("no/such.png");
		final s = new Sprite3D(texture);

		s.setTransform(new Vec3(1, 2, 3), new Vec3(0, 0.5, 0), new Vec3(2, 2, 2));
		final p = s.position;
		near(p.x, 1, "sprite3d position x reads back");
		near(p.y, 2, "sprite3d position y reads back");
		near(p.z, 3, "sprite3d position z reads back — the vec3 is not transposed");
		near(s.rotation.y, 0.5, "sprite3d rotation reads back in radians");
		near(s.scale.x, 2, "sprite3d scale reads back");

		check(s.visible && s.pickable && s.enabled, "a new sprite3d is visible, pickable, enabled");
		s.visible = false;
		s.pickable = false;
		s.enabled = false;
		check(!s.visible && !s.pickable && !s.enabled, "every sprite3d flag round-trips false");
		s.visible = true;

		eq(s.alphaMode, AlphaMode.Blend, "a sprite3d blends by default");
		check(s.setAlphaMode(Mask, 0.5), "alpha mode set to masked");
		eq(s.alphaMode, AlphaMode.Mask, "alpha mode reads back as the enum");

		s.size = 2;
		check(s.setExtent(3, 1), "a rectangular extent is accepted");
		check(!s.setExtent(0, 1), "a zero extent is refused");
		check(s.setSource(0, 0, 16, 16), "a source region is accepted");
		// a fraction of the quad, not pixels: (0.5, 1) is the bottom edge
		check(s.setPivot(0.5, 1), "a pivot is a fraction of the quad");
		check(s.setPickAlphaTest(true, 0.5), "pick alpha test enabled");

		check(s.getMaterial().isNone, "a new sprite3d is on the built-in shader");
		final custom = new Material(Unlit);
		check(s.setMaterial(custom), "a sprite3d takes a material");
		eq((s.getMaterial() : Int), (custom : Int), "and reads it back");
		custom.release();

		check(s.setTexture(Texture.defaultTexture), "a sprite3d's texture can be swapped");
		s.destroy();
		texture.release();
	}

	static function checkSceneState():Void {
		final s = new Scene();
		final m = new Model(Mesh.cube(1, 1, 1));

		check(s.culling, "a new scene culls");
		s.culling = false;
		check(!s.culling, "culling round-trips");
		s.culling = true;

		check(!s.interactive, "a new scene is not interactive");
		s.interactive = true;
		check(s.interactive, "interactive round-trips");

		check(s.add(m, 2), "a member goes onto a layer");
		check(s.setLayer(m, 3), "and moves to another");
		check(s.setClip(3, 0, 0, 100, 100), "a layer clips to a rectangle");
		check(s.setClip(3, 0, 0, 0, 0), "a zero rectangle removes the clip");

		// nothing is under a pointer that never moved
		check(s.hovered.isNone, "nothing is hovered in headless");
		eq(s.getHover(m), ButtonState.Up, "hover is up");
		eq(s.getPress(m), ButtonState.Up, "press is up");
		check(!s.isClicked(m), "nothing is clicked");

		check(s.setTonemap(Aces, 1), "a tonemap and exposure are set");
		final missing = Environment.create("no/such.hdr");
		check(missing.isNone, "a missing environment does not load");
		check(s.setEnvironment(Handle.NONE), "a none environment removes it");
		check(s.setBackground(Handle.NONE), "a none background removes it");

		check(s.remove(m), "a member comes out");
		check(!s.remove(m), "and cannot come out twice");
		s.clear();
		m.destroy();
		s.destroy();
	}

	static function checkTexture():Void {
		check(!Texture.defaultTexture.isNone, "there is a default texture");
		check(!Texture.placeholder.isNone, "there is a placeholder texture");

		final target = Texture.createTarget(64, 32);
		check(!target.isNone, "a render target is created");
		final size = target.size;
		near(size.x, 64, "the target's width reads back");
		near(size.y, 32, "the target's height reads back — the vec2 is not transposed");
		target.release();
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
		checkShapes();
		checkCamera();
		checkTexture();
		checkMeshes();
		checkSprite3D();
		checkSceneState();
	}

	static function onFrame(dt:Float, tickFraction:Float):Void {
		frames++;
		check(dt >= 0, "dt is not negative");
		if (frames == 1) {
			// these only mean anything once the loop is running
			check(Wgr.getTime() >= 0, "getTime inside a frame");
			eq(Input.getKey(Escape), ButtonState.Up, "no key is down in headless");
			check(!Input.isKeyPressed(Space), "no key was pressed");

			// the keyboard as a whole. On js this is a heap view, which is why it is
			// read inside a frame and not held: the op edge resets the stack it sits on.
			final keyboard = Input.getKeyboardState();
			eq(keyboard[Key.Escape], ButtonState.Up, "the whole keyboard agrees: escape is up");
			eq(keyboard[Key.Space], ButtonState.Up, "and space is up");
			check(!keyboard.isDown(Key.A) && !keyboard.isPressed(Key.A) && !keyboard.isReleased(Key.A),
				"a key nothing touched is in no state at all");
			eq(keyboard.numPressedKeys, 0, "no key arrived this frame");
			eq(keyboard.numPressedChars, 0, "no character arrived this frame");
			eq(keyboard.pressedChar, 0, "so there is no last character");
			eq(keyboard.typedText(), "", "and no text to append");
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

	#if !sys
	/**
		js has no host loop to drive — the guest ABI replaces it — so this entry exists
		only so `./build.py check` can type-check every assertion above against the js
		binding. A wrapper that compiles on hxcpp but not js fails here, not in an example.
	**/
	public static function main():Void {}
	#else
	public static function main():Void {
		final rc = Wgr.initValues(WIDTH, HEIGHT, "check", Msaa4x | Resizable);
		check(rc != Wgr.ERR_VERSION_MISMATCH, "initValues guards the version like the guest ABI does");
		check(rc == 0, "initValues succeeded");
		Wgr.setInit(onInit);
		Wgr.setFrame(onFrame);
		Wgr.run();

		check(frames > 0, "the loop ran at least one frame");
		say('${checks - failures}/$checks checks passed over $frames frames');
		Sys.exit(failures == 0 ? 0 : 1);
	}
	#end
}
