// wgrender's shadows example, as a Haxe guest: a casting light and what it does.
//
// A port of examples/shadows.c. The sun casts, so once a frame everything that casts
// is drawn into a depth map and the lit shading darkens what is behind something. The
// scene is a floor, a wall, some generated shapes and an animated character, so the
// shadows fall across each other and across themselves.
//
//   1        the sun's casting on and off -- the difference the whole feature makes
//   2        the same for a spot circling overhead, casting through its own cone:
//            two casters at once, a layer of the shadow map each
//   UP/DOWN  shadow distance. Less distance covers less of the scene with the same
//            map, so the shadows sharpen
//   [ ]      depth bias. Too little stripes the lit surfaces ("acne"), too much lifts
//            a shadow away from what casts it
//   M        map size: 512, 1024, 2048, 4096
//   S        how much light a shadow blocks
//   T        what it leaves behind: none, cool, warm
//   O        stop the camera
//   ESC      quit
//
// The ball on the left casts nothing, so it floats the way everything did before
// shadows; the one on the right receives nothing, so the wall's shadow passes over it.
import wgr.*;

@:expose("WgrGuest")
class Shadows {
	static inline final SCREEN_WIDTH = 1000;
	static inline final SCREEN_HEIGHT = 600;
	static inline final CHARACTER_PATH = "models/woman_casual/woman_casual.glb";
	static inline final ASSET_CHARACTER = 1;

	static final MAP_SIZES = [512, 1024, 2048, 4096];
	/**
		What a shadow keeps of the light: nothing (physical), then two stylised tints.

		Filled in `onInit`, not here. A static initialiser runs when the module loads,
		which on js is before the host module exists — `Color.rgba` would be called
		through `Raw` with nothing attached, and the binding says so rather than
		crashing obscurely.
	**/
	static var TINTS:Array<Color>;
	static final TINT_NAMES = ["none", "cool", "warm"];

	static var scene:Scene;
	static var camera:Camera3D;
	static var target:Vec3;
	static var sun:Light;
	static var spot:Light;
	static var spotMarker:Shape3D;
	static var character:Model;

	static var shadows = true;
	static var spotShadows = true;
	static var orbit = true;
	static var distance = 30.0;
	static var bias = 1.0;
	static var strength = 1.0;
	static var sizeIndex = 1;
	static var tintIndex = 0;
	static var angle = 0.0;
	static var elapsed = 0.0;

	static function main():Void {
		GuestAbi.autostart(start);
	}

	public static function start(host:Dynamic):Bool {
		GuestAbi.attach(host);
		GuestAbi.register(onInit, (dt, _) -> onFrame(dt), onAsset);
		return GuestAbi.start(SCREEN_WIDTH, SCREEN_HEIGHT, "shadows (wgrender host, Haxe guest)",
			Msaa4x | Resizable);
	}

	static function onInit():Void {
		Asset.setHost(Assets.defaultBase());
		TINTS = [Color.rgba(0, 0, 0, 255), Color.rgba(30, 60, 100, 255), Color.rgba(100, 50, 30, 255)];
		target = new Vec3(0, 1.2, 0);
		camera = Camera3D.create(Perspective);
		scene = Scene.create();
		Scene.setActiveCamera(scene, camera);
		Scene.setAmbient(scene, Color.rgba(140, 170, 225, 255), 0.25);

		addLights();
		addScenery();

		character = Model.create(Handle.NONE);
		Model.setPosition(character, new Vec3(0, 0, 0));
		Scene.add(scene, character);
		if (!GuestAbi.loadAsset(CHARACTER_PATH, ASSET_CHARACTER))
			Log.error('failed to queue asset: $CHARACTER_PATH');
		Debug.enableFps(12, 10, 16);
	}

	static function addLights():Void {
		sun = Light.create(Directional);
		Light.setDirection(sun, new Vec3(-0.75, -0.85, -0.35));
		Light.setColor(sun, Color.rgba(255, 244, 224, 255));
		Light.setIntensity(sun, 3.2);
		Light.setCastsShadows(sun, true);
		Light.setShadowDistance(sun, distance);
		Light.setShadowMapSize(sun, MAP_SIZES[sizeIndex]);
		Light.setShadowStrength(sun, strength);
		Light.setShadowColor(sun, TINTS[tintIndex]);
		Scene.add(scene, sun);

		// A second caster, circling the scene and shadowing through its own cone.
		// Both share the map, so both use the same size.
		spot = Light.create(Spot);
		Light.setColor(spot, Color.rgba(150, 210, 255, 255));
		Light.setIntensity(spot, 260.0);
		Light.setRange(spot, 24.0);
		Light.setSpotCone(spot, 0.30, 0.44);
		Light.setCastsShadows(spot, true);
		Light.setShadowMapSize(spot, MAP_SIZES[sizeIndex]);
		Light.setShadowDistance(spot, 24.0);
		Scene.add(scene, spot);

		spotMarker = Shape3D.create();
		Shape3D.setSphere(spotMarker, 0.16);
		Shape3D.setColor(spotMarker, Color.rgba(150, 210, 255, 255));
		Scene.add(scene, spotMarker);
	}

	/** A model of `mesh` at `position` in one colour, added to the scene. **/
	static function place(mesh:Mesh, position:Vec3, r:Float, g:Float, b:Float, roughness:Float):Model {
		final model = Model.create(mesh);
		Mesh.release(mesh); // the model holds it
		Model.setPosition(model, position);
		final material = Material.create(Pbr);
		Material.setBaseColor(material, r, g, b, 1.0);
		Material.setMetallic(material, 0.0);
		Material.setRoughness(material, roughness);
		Model.setMaterial(model, -1, material);
		Material.release(material);
		Scene.add(scene, model);
		return model;
	}

	static function addScenery():Void {
		place(Mesh.plane(40.0, 40.0, 0), new Vec3(0, 0, 0), 0.42, 0.44, 0.46, 0.9);
		// a wall, to throw a long shadow across the floor
		place(Mesh.cube(0.5, 3.0, 7.0), new Vec3(-4.5, 1.5, 0), 0.55, 0.5, 0.45, 0.85);
		place(Mesh.torus(0.7, 0.22, 48, 24), new Vec3(2.6, 1.1, -1.6), 0.9, 0.55, 0.2, 0.4);
		place(Mesh.capsule(0.4, 1.6, 16, 32), new Vec3(1.2, 0.8, 1.8), 0.35, 0.75, 0.45, 0.5);
		place(Mesh.cube(1.0, 1.0, 1.0), new Vec3(3.8, 0.5, 1.4), 0.3, 0.5, 0.85, 0.6);

		// one that casts nothing, and one that nothing shadows
		Model.setCastsShadow(place(Mesh.sphere(0.6, 24, 48), new Vec3(-2.0, 0.6, 2.4), 0.95, 0.85, 0.3, 0.35), false);
		Model.setReceivesShadow(place(Mesh.sphere(0.6, 24, 48), new Vec3(-2.6, 0.6, -1.2), 0.9, 0.3, 0.5, 0.35), false);
	}

	static function onAsset(id:Int, path:String, ok:Bool):Void {
		if (!ok) {
			Log.error('load failed: $path');
			return;
		}
		if (id != ASSET_CHARACTER)
			return;
		final mesh = Mesh.create(path);
		Model.setMesh(character, mesh);
		Mesh.release(mesh);
		Model.setAnimation(character, 3);
		Model.setAnimationLoop(character, true);
	}

	static function handleKeys(dt:Float):Void {
		if (Input.isKeyPressed(Escape))
			Wgr.requestQuit();
		if (Input.isKeyPressed(Digit1)) {
			shadows = !shadows;
			Light.setCastsShadows(sun, shadows);
		}
		if (Input.isKeyPressed(Digit2)) {
			spotShadows = !spotShadows;
			Light.setCastsShadows(spot, spotShadows);
		}
		if (Input.isKeyPressed(O))
			orbit = !orbit;
		if (Input.isKeyPressed(S)) {
			strength = strength > 0.9 ? 0.65 : (strength > 0.5 ? 0.35 : 1.0);
			Light.setShadowStrength(sun, strength);
		}
		if (Input.isKeyPressed(T)) {
			tintIndex = (tintIndex + 1) % TINTS.length;
			Light.setShadowColor(sun, TINTS[tintIndex]);
		}
		if (Input.isKeyPressed(M)) {
			sizeIndex = (sizeIndex + 1) % MAP_SIZES.length;
			Light.setShadowMapSize(sun, MAP_SIZES[sizeIndex]);
			Light.setShadowMapSize(spot, MAP_SIZES[sizeIndex]);
		}
		if (Input.isKeyDown(Up) || Input.isKeyDown(Down)) {
			final step = Input.isKeyDown(Up) ? dt * 20.0 : -dt * 20.0;
			distance = Math.max(2.0, Math.min(distance + step, 200.0));
			Light.setShadowDistance(sun, distance);
		}
		if (Input.isKeyDown(LeftBracket) || Input.isKeyDown(RightBracket)) {
			final step = Input.isKeyDown(RightBracket) ? dt * 4.0 : -dt * 4.0;
			bias = Math.max(0.0, Math.min(bias + step, 16.0));
			Light.setShadowBias(sun, bias, bias * 4.0);
		}
	}

	static function onFrame(dt:Float):Void {
		handleKeys(dt);

		elapsed += dt;
		Model.animate(character, dt);
		// the spot circles overhead, always aimed at the middle of the scene
		final sx = 7.0 * Math.sin(elapsed * 0.35);
		final sz = 7.0 * Math.cos(elapsed * 0.35);
		Light.setPosition(spot, new Vec3(sx, 6.5, sz));
		Light.setDirection(spot, new Vec3(-sx, -6.5, -sz));
		Shape3D.setPosition(spotMarker, new Vec3(sx, 6.5, sz));
		if (orbit)
			angle += dt * 0.18;
		Camera3D.setView(camera, new Vec3(11.0 * Math.sin(angle), 5.0, 11.0 * Math.cos(angle)), target);

		Render.beginFrame();
		Render.clearBackground(Color.rgba(120, 150, 200, 255));
		Scene.draw(scene);
		Text.draw("wgrender shadows: a directional light casting into a depth map", 12, 36, 20, Color.RAYWHITE);
		Text.draw('[1] sun ${shadows ? "on" : "off"}   [2] spot ${spotShadows ? "on" : "off"}   '
			+ 'map ${MAP_SIZES[sizeIndex]}   distance ${Math.round(distance)}   '
			+ 'bias ${fixed(bias, 1)} texels', 12, 64, 16, Color.LIGHTGRAY);
		Text.draw('[S] strength ${fixed(strength, 2)}   [T] tint ${TINT_NAMES[tintIndex]}', 12, 86, 16,
			Color.LIGHTGRAY);
		Text.draw("UP/DOWN distance   [ ] bias   M map size   O camera   ESC quit", 12, 108, 16, Color.GRAY);
		Text.draw("left ball casts nothing; right ball receives nothing", 12, 130, 16, Color.GRAY);
		Render.endFrame();
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
