package wgr.impl;


/**
	Raw wgrender bindings for the JS guest: the same C API `../simple/src/wgr/Raw.hx`
	declares through hxcpp externs, reached instead through the host module's exports.

	Haxe picks this file over a plain `Raw.hx` on the js target (`Module.<target>.hx`),
	which is how one `wgr.Wgr` layer can sit on top of either.

	Three rules this layer exists to keep, all of them measured hazards:

	- **Never hold a heap view.** The host links with `ALLOW_MEMORY_GROWTH`, so any
	  allocation detaches every `HEAPF32`/`HEAP32` JS holds. Measured: one 192 MB
	  `malloc` mid-frame took a cached view's `byteLength` to 0 while a freshly read
	  one was fine. So every read goes through `host.HEAPF32` at the point of use.
	  Pointers stay valid across growth; only the views die.
	- **Scratch is an arena per op.** Strings and struct-return slots come from
	  `stackAlloc`, and the guest's op edge restores the stack pointer once when the op
	  ends, fault or not (Haxe has no `finally`, and per-call restore would need a
	  try/rethrow at every call site). `Guest.run` owns that.
	- **Structs come back through a pointer.** The wasm C ABI returns anything bigger
	  than a scalar through a hidden first argument, so these read the fields out of
	  the heap rather than getting a value.
**/
typedef WgrHandle = Int;
typedef WgrColor = Int;

class Raw {
	/** The Emscripten module, handed over at boot. **/
	public static var host(default, null):Dynamic;

	public static function attach(module:Dynamic):Void {
		host = module;
	}

	// --- scratch -------------------------------------------------------------

	/** Where the op arena started; `Guest` restores to here when an op ends. **/
	public static inline function stackMark():Int
		return host.stackSave();

	public static inline function stackRelease(mark:Int):Void
		host.stackRestore(mark);

	/** A NUL-terminated copy of `s` in the op's arena. **/
	public static inline function cstr(s:String):Int {
		final length = host.lengthBytesUTF8(s) + 1;
		final pointer = host.stackAlloc(length);
		host.stringToUTF8(s, pointer, length);
		return pointer;
	}

	static inline function scratch(bytes:Int):Int
		return host.stackAlloc(bytes);

	public static inline function str(pointer:Int):String
		return host.UTF8ToString(pointer);

	// --- lifecycle -----------------------------------------------------------

	public static inline function wgr_get_platform():String
		return str(host._wgr_get_platform());

	public static inline function wgr_set_target_fps(fps:Int):Void
		host._wgr_set_target_fps(fps);

	public static inline function wgr_request_quit():Void
		host._wgr_request_quit();

	// --- logging -------------------------------------------------------------

	public static inline function wgr_logger_set_level(level:Int):Void
		host._wgr_logger_set_level(level);

	public static inline function wgr_logger_message(level:Int, format:String, text:String):Void
		host._wgr_logger_message(level, cstr(format), cstr(text));

	// --- assets --------------------------------------------------------------

	public static inline function wgr_asset_set_host(base:String):Void
		host._wgr_asset_set_host(cstr(base));

	/** The guest ABI's asset op, keyed by `id` — the guest never sees a callback. **/
	public static inline function wgr_guest_asset_load(path:String, id:Int):Bool
		return host._wgr_guest_asset_load(cstr(path), id) != 0;

	// --- colors --------------------------------------------------------------

	public static inline function wgr_color_rgba(r:Int, g:Int, b:Int, a:Int):Int
		return host._wgr_color_rgba(r, g, b, a);

	// --- audio / sound -------------------------------------------------------

	public static inline function wgr_audio_create(path:String):Int
		return host._wgr_audio_create(cstr(path));

	public static inline function wgr_audio_release(audio:Int):Void
		host._wgr_audio_release(audio);

	public static inline function wgr_sound_create(audio:Int):Int
		return host._wgr_sound_create(audio);

	public static inline function wgr_sound_set_loop(sound:Int, loop:Bool):Bool
		return host._wgr_sound_set_loop(sound, loop) != 0;

	public static inline function wgr_sound_play(sound:Int):Bool
		return host._wgr_sound_play(sound) != 0;

	// --- mesh / model --------------------------------------------------------

	public static inline function wgr_mesh_create(path:String):Int
		return host._wgr_mesh_create(cstr(path));

	public static inline function wgr_mesh_release(mesh:Int):Void
		host._wgr_mesh_release(mesh);

	public static inline function wgr_model_create(mesh:Int):Int
		return host._wgr_model_create(mesh);

	public static inline function wgr_model_set_animation(model:Int, index:Int):Bool
		return host._wgr_model_set_animation(model, index) != 0;

	public static inline function wgr_model_set_animation_speed(model:Int, speed:Float):Bool
		return host._wgr_model_set_animation_speed(model, speed) != 0;

	public static inline function wgr_model_set_animation_loop(model:Int, loop:Bool):Bool
		return host._wgr_model_set_animation_loop(model, loop) != 0;

	public static inline function wgr_model_set_transform(model:Int, px:Float, py:Float, pz:Float, rx:Float, ry:Float,
			rz:Float, sx:Float, sy:Float, sz:Float):Bool
		return host._wgr_model_set_transform(model, px, py, pz, rx, ry, rz, sx, sy, sz) != 0;

	public static inline function wgr_model_set_tint(model:Int, color:Int):Bool
		return host._wgr_model_set_tint(model, color) != 0;

	public static inline function wgr_model_animate(model:Int, dt:Float):Bool
		return host._wgr_model_animate(model, dt) != 0;

	// --- texture / sprite3d --------------------------------------------------

	public static inline function wgr_texture_create(path:String):Int
		return host._wgr_texture_create(cstr(path));

	public static inline function wgr_texture_release(texture:Int):Void
		host._wgr_texture_release(texture);

	public static inline function wgr_sprite3d_create(texture:Int):Int
		return host._wgr_sprite3d_create(texture);

	public static inline function wgr_sprite3d_set_facing(sprite:Int, facing:Int):Bool
		return host._wgr_sprite3d_set_facing(sprite, facing) != 0;

	public static inline function wgr_sprite3d_set_transform(sprite:Int, px:Float, py:Float, pz:Float, rx:Float,
			ry:Float, rz:Float, sx:Float, sy:Float, sz:Float):Bool
		return host._wgr_sprite3d_set_transform(sprite, px, py, pz, rx, ry, rz, sx, sy, sz) != 0;

	public static inline function wgr_sprite3d_set_tint(sprite:Int, color:Int):Bool
		return host._wgr_sprite3d_set_tint(sprite, color) != 0;

	// --- fonts / text --------------------------------------------------------

	public static inline function wgr_font_create(path:String):Int
		return host._wgr_font_create(cstr(path));

	public static inline function wgr_text_draw(text:String, x:Int, y:Int, size:Int, color:Int):Void
		host._wgr_text_draw(cstr(text), x, y, size, color);

	public static inline function wgr_text_draw_ex(font:Int, text:String, x:Float, y:Float, size:Float,
			color:Int):Void
		host._wgr_text_draw_ex(font, cstr(text), x, y, size, color);

	public static inline function wgr_text_measure(text:String, size:Int):Int
		return host._wgr_text_measure(cstr(text), size);

	public static inline function wgr_text_draw_fps_ex(font:Int, x:Float, y:Float, size:Float, color:Int):Void
		host._wgr_text_draw_fps_ex(font, x, y, size, color);

	/** vec2_t comes back through a hidden out-pointer; read it, don't hold the view. **/
	public static function wgr_text_measure_ex(font:Int, text:String, size:Float):Vec2 {
		final out = scratch(8);
		host._wgr_text_measure_ex(out, font, cstr(text), size);
		final heap = host.HEAPF32;
		return new Vec2(heap[out >> 2], heap[(out >> 2) + 1]);
	}

	// --- camera / light / scene ----------------------------------------------

	public static inline function wgr_camera3d_create(projection:Int):Int
		return host._wgr_camera3d_create(projection);

	public static inline function wgr_camera3d_set_view(camera:Int, px:Float, py:Float, pz:Float, tx:Float, ty:Float,
			tz:Float, ux:Float, uy:Float, uz:Float):Bool
		return host._wgr_camera3d_set_view(camera, px, py, pz, tx, ty, tz, ux, uy, uz) != 0;

	public static inline function wgr_light_create(kind:Int):Int
		return host._wgr_light_create(kind);

	public static inline function wgr_light_set_direction(light:Int, x:Float, y:Float, z:Float):Bool
		return host._wgr_light_set_direction(light, x, y, z) != 0;

	public static inline function wgr_light_set_intensity(light:Int, intensity:Float):Bool
		return host._wgr_light_set_intensity(light, intensity) != 0;

	public static inline function wgr_scene_create():Int
		return host._wgr_scene_create();

	public static inline function wgr_scene_set_active_camera(scene:Int, camera:Int):Void
		host._wgr_scene_set_active_camera(scene, camera);

	public static inline function wgr_scene_add(scene:Int, drawable:Int, layer:Int):Bool
		return host._wgr_scene_add(scene, drawable, layer) != 0;

	public static inline function wgr_scene_set_ambient(scene:Int, color:Int, intensity:Float):Bool
		return host._wgr_scene_set_ambient(scene, color, intensity) != 0;

	public static inline function wgr_scene_draw(scene:Int):Void
		host._wgr_scene_draw(scene);

	/** wgr_pick_result_t, read field by field out of the heap. **/
	public static function wgr_scene_pick(scene:Int, camera:Int, x:Float, y:Float):PickResult {
		final out = scratch(64);
		host._wgr_scene_pick(out, scene, camera, x, y);
		final i32 = host.HEAP32, f32 = host.HEAPF32, u8 = host.HEAPU8; // fetched fresh, never held
		final base = out >> 2;
		return new PickResult(u8[out] != 0, i32[base + 1], f32[base + 2], vec3(f32, base + 3), vec3(f32, base + 6),
			vec3(f32, base + 9), vec3(f32, base + 12));
	}

	static inline function vec3(f32:Dynamic, base:Int):Vec3
		return new Vec3(f32[base], f32[base + 1], f32[base + 2]);

	// --- frame ---------------------------------------------------------------

	public static inline function wgr_render_begin():Void
		host._wgr_render_begin();

	public static inline function wgr_render_end():Void
		host._wgr_render_end();

	public static inline function wgr_render_clear_background(color:Int):Void
		host._wgr_render_clear_background(color);

	public static function wgr_window_get_screen_size():Vec2 {
		final out = scratch(8);
		host._wgr_window_get_screen_size(out);
		final heap = host.HEAPF32;
		return new Vec2(heap[out >> 2], heap[(out >> 2) + 1]);
	}

	public static function wgr_input_get_mouse_state():MouseState {
		final out = scratch(64);
		host._wgr_input_get_mouse_state(out);
		final i32 = host.HEAP32, f32 = host.HEAPF32;
		final base = out >> 2;
		return new MouseState(i32[base], i32[base + 1], f32[base + 2], f32[base + 3], i32[base + 4], i32[base + 5],
			i32[base + 6], [i32[base + 7], i32[base + 8], i32[base + 9]], i32[base + 10], i32[base + 11]);
	}

	public static inline function wgr_input_get_key(key:Int):Int
		return host._wgr_input_get_key(key);

	// --- BEGIN generated by tools/gen_raw_js.py from Raw.cpp.hx ---------------

	public static inline function wgr_sound_destroy(handle:Int):Void
		host._wgr_sound_destroy(handle);

	public static inline function wgr_model_destroy(handle:Int):Void
		host._wgr_model_destroy(handle);

	public static inline function wgr_sprite3d_destroy(handle:Int):Void
		host._wgr_sprite3d_destroy(handle);

	public static inline function wgr_font_release(font:Int):Void
		host._wgr_font_release(font);

	public static inline function wgr_camera3d_destroy(camera:Int):Void
		host._wgr_camera3d_destroy(camera);

	public static inline function wgr_light_destroy(light:Int):Void
		host._wgr_light_destroy(light);

	public static inline function wgr_scene_destroy(scene:Int):Void
		host._wgr_scene_destroy(scene);

	public static inline function wgr_text_set_default_font(font:Int):Bool
		return host._wgr_text_set_default_font(font) != 0;

	public static inline function wgr_text_get_default_font():Int
		return host._wgr_text_get_default_font();

	public static inline function wgr_text_draw_fps(x:Int, y:Int):Void
		host._wgr_text_draw_fps(x, y);

	public static inline function wgr_text_draw_3d(font:Int, text:String, x:Float, y:Float, z:Float, size:Float, color:Int):Void
		host._wgr_text_draw_3d(font, cstr(text), x, y, z, size, color);

	public static inline function wgr_text2d_create(font:Int):Int
		return host._wgr_text2d_create(font);

	public static inline function wgr_text2d_destroy(text:Int):Void
		host._wgr_text2d_destroy(text);

	public static inline function wgr_text2d_set_font(text:Int, font:Int):Bool
		return host._wgr_text2d_set_font(text, font) != 0;

	public static inline function wgr_text2d_set_text(text:Int, string:String):Bool
		return host._wgr_text2d_set_text(text, cstr(string)) != 0;

	public static inline function wgr_text2d_set_position(text:Int, x:Float, y:Float):Bool
		return host._wgr_text2d_set_position(text, x, y) != 0;

	public static inline function wgr_text2d_set_size(text:Int, size:Float):Bool
		return host._wgr_text2d_set_size(text, size) != 0;

	public static inline function wgr_text2d_set_color(text:Int, color:Int):Bool
		return host._wgr_text2d_set_color(text, color) != 0;

	public static inline function wgr_text2d_set_visible(text:Int, visible:Bool):Bool
		return host._wgr_text2d_set_visible(text, visible) != 0;

	public static inline function wgr_text2d_is_visible(text:Int):Bool
		return host._wgr_text2d_is_visible(text) != 0;

	public static inline function wgr_text2d_set_pickable(text:Int, pickable:Bool):Bool
		return host._wgr_text2d_set_pickable(text, pickable) != 0;

	public static inline function wgr_text2d_is_pickable(text:Int):Bool
		return host._wgr_text2d_is_pickable(text) != 0;

	public static inline function wgr_text2d_set_enabled(text:Int, enabled:Bool):Bool
		return host._wgr_text2d_set_enabled(text, enabled) != 0;

	public static inline function wgr_text2d_is_enabled(text:Int):Bool
		return host._wgr_text2d_is_enabled(text) != 0;

	public static inline function wgr_text2d_set_align(text:Int, horizontal:Int, vertical:Int):Bool
		return host._wgr_text2d_set_align(text, horizontal, vertical) != 0;

	public static inline function wgr_text2d_set_max_width(text:Int, width:Float):Bool
		return host._wgr_text2d_set_max_width(text, width) != 0;

	public static inline function wgr_text2d_measure_width(text:Int):Float
		return host._wgr_text2d_measure_width(text);

	public static inline function wgr_text2d_measure_height(text:Int):Float
		return host._wgr_text2d_measure_height(text);

	public static inline function wgr_text2d_draw(text:Int):Void
		host._wgr_text2d_draw(text);

	public static inline function wgr_text3d_create(font:Int):Int
		return host._wgr_text3d_create(font);

	public static inline function wgr_text3d_destroy(text:Int):Void
		host._wgr_text3d_destroy(text);

	public static inline function wgr_text3d_set_font(text:Int, font:Int):Bool
		return host._wgr_text3d_set_font(text, font) != 0;

	public static inline function wgr_text3d_set_text(text:Int, string:String):Bool
		return host._wgr_text3d_set_text(text, cstr(string)) != 0;

	public static inline function wgr_text3d_set_size(text:Int, size:Float):Bool
		return host._wgr_text3d_set_size(text, size) != 0;

	public static inline function wgr_text3d_set_align(text:Int, horizontal:Int, vertical:Int):Bool
		return host._wgr_text3d_set_align(text, horizontal, vertical) != 0;

	public static inline function wgr_text3d_set_max_width(text:Int, width:Float):Bool
		return host._wgr_text3d_set_max_width(text, width) != 0;

	public static inline function wgr_text3d_set_transform(text:Int, x:Float, y:Float, z:Float, rx:Float, ry:Float, rz:Float):Bool
		return host._wgr_text3d_set_transform(text, x, y, z, rx, ry, rz) != 0;

	public static inline function wgr_text3d_set_facing(text:Int, facing:Int):Bool
		return host._wgr_text3d_set_facing(text, facing) != 0;

	public static inline function wgr_text3d_set_color(text:Int, color:Int):Bool
		return host._wgr_text3d_set_color(text, color) != 0;

	public static inline function wgr_text3d_set_visible(text:Int, visible:Bool):Bool
		return host._wgr_text3d_set_visible(text, visible) != 0;

	public static inline function wgr_text3d_is_visible(text:Int):Bool
		return host._wgr_text3d_is_visible(text) != 0;

	public static inline function wgr_text3d_set_pickable(text:Int, pickable:Bool):Bool
		return host._wgr_text3d_set_pickable(text, pickable) != 0;

	public static inline function wgr_text3d_is_pickable(text:Int):Bool
		return host._wgr_text3d_is_pickable(text) != 0;

	public static inline function wgr_text3d_set_enabled(text:Int, enabled:Bool):Bool
		return host._wgr_text3d_set_enabled(text, enabled) != 0;

	public static inline function wgr_text3d_is_enabled(text:Int):Bool
		return host._wgr_text3d_is_enabled(text) != 0;

	public static inline function wgr_text3d_draw(text:Int):Void
		host._wgr_text3d_draw(text);

	public static inline function wgr_emitter3d_create(texture:Int):Int
		return host._wgr_emitter3d_create(texture);

	public static inline function wgr_emitter3d_destroy(emitter:Int):Void
		host._wgr_emitter3d_destroy(emitter);

	public static inline function wgr_emitter3d_set_source(emitter:Int, x:Float, y:Float, width:Float, height:Float):Bool
		return host._wgr_emitter3d_set_source(emitter, x, y, width, height) != 0;

	public static inline function wgr_emitter3d_set_frames(emitter:Int, columns:Int, rows:Int, count:Int, per_second:Float):Bool
		return host._wgr_emitter3d_set_frames(emitter, columns, rows, count, per_second) != 0;

	public static inline function wgr_emitter3d_set_position(emitter:Int, x:Float, y:Float, z:Float):Bool
		return host._wgr_emitter3d_set_position(emitter, x, y, z) != 0;

	public static inline function wgr_emitter3d_jump(emitter:Int, x:Float, y:Float, z:Float):Bool
		return host._wgr_emitter3d_jump(emitter, x, y, z) != 0;

	public static inline function wgr_emitter3d_set_rate(emitter:Int, per_second:Float):Bool
		return host._wgr_emitter3d_set_rate(emitter, per_second) != 0;

	public static inline function wgr_emitter3d_burst(emitter:Int, count:Int):Bool
		return host._wgr_emitter3d_burst(emitter, count) != 0;

	public static inline function wgr_emitter3d_set_emitting(emitter:Int, emitting:Bool):Bool
		return host._wgr_emitter3d_set_emitting(emitter, emitting) != 0;

	public static inline function wgr_emitter3d_is_emitting(emitter:Int):Bool
		return host._wgr_emitter3d_is_emitting(emitter) != 0;

	public static inline function wgr_emitter3d_set_max(emitter:Int, count:Int):Bool
		return host._wgr_emitter3d_set_max(emitter, count) != 0;

	public static inline function wgr_emitter3d_set_life(emitter:Int, min_seconds:Float, max_seconds:Float):Bool
		return host._wgr_emitter3d_set_life(emitter, min_seconds, max_seconds) != 0;

	public static inline function wgr_emitter3d_prewarm(emitter:Int, seconds:Float):Bool
		return host._wgr_emitter3d_prewarm(emitter, seconds) != 0;

	public static inline function wgr_emitter3d_set_spawn_box(emitter:Int, half_x:Float, half_y:Float, half_z:Float):Bool
		return host._wgr_emitter3d_set_spawn_box(emitter, half_x, half_y, half_z) != 0;

	public static inline function wgr_emitter3d_set_spawn_sphere(emitter:Int, radius:Float):Bool
		return host._wgr_emitter3d_set_spawn_sphere(emitter, radius) != 0;

	public static inline function wgr_emitter3d_set_velocity(emitter:Int, x:Float, y:Float, z:Float, spread:Float, speed_variance:Float):Bool
		return host._wgr_emitter3d_set_velocity(emitter, x, y, z, spread, speed_variance) != 0;

	public static inline function wgr_emitter3d_set_gravity(emitter:Int, x:Float, y:Float, z:Float):Bool
		return host._wgr_emitter3d_set_gravity(emitter, x, y, z) != 0;

	public static inline function wgr_emitter3d_set_drag(emitter:Int, per_second:Float):Bool
		return host._wgr_emitter3d_set_drag(emitter, per_second) != 0;

	public static inline function wgr_emitter3d_set_inherit_velocity(emitter:Int, fraction:Float):Bool
		return host._wgr_emitter3d_set_inherit_velocity(emitter, fraction) != 0;

	public static inline function wgr_emitter3d_set_size(emitter:Int, start:Float, end:Float, variance:Float):Bool
		return host._wgr_emitter3d_set_size(emitter, start, end, variance) != 0;

	public static inline function wgr_emitter3d_set_color(emitter:Int, start:Int, end:Int):Bool
		return host._wgr_emitter3d_set_color(emitter, start, end) != 0;

	public static inline function wgr_emitter3d_add_size_key(emitter:Int, t:Float, size:Float):Bool
		return host._wgr_emitter3d_add_size_key(emitter, t, size) != 0;

	public static inline function wgr_emitter3d_clear_size_keys(emitter:Int):Bool
		return host._wgr_emitter3d_clear_size_keys(emitter) != 0;

	public static inline function wgr_emitter3d_add_color_key(emitter:Int, t:Float, color:Int):Bool
		return host._wgr_emitter3d_add_color_key(emitter, t, color) != 0;

	public static inline function wgr_emitter3d_clear_color_keys(emitter:Int):Bool
		return host._wgr_emitter3d_clear_color_keys(emitter) != 0;

	public static inline function wgr_emitter3d_add_palette_color(emitter:Int, color:Int):Bool
		return host._wgr_emitter3d_add_palette_color(emitter, color) != 0;

	public static inline function wgr_emitter3d_clear_palette(emitter:Int):Bool
		return host._wgr_emitter3d_clear_palette(emitter) != 0;

	public static inline function wgr_emitter3d_set_spin(emitter:Int, min:Float, max:Float):Bool
		return host._wgr_emitter3d_set_spin(emitter, min, max) != 0;

	public static inline function wgr_emitter3d_set_stretch(emitter:Int, seconds:Float):Bool
		return host._wgr_emitter3d_set_stretch(emitter, seconds) != 0;

	public static inline function wgr_emitter3d_set_alpha_mode(emitter:Int, mode:Int, cutoff:Float):Bool
		return host._wgr_emitter3d_set_alpha_mode(emitter, mode, cutoff) != 0;

	public static inline function wgr_emitter3d_set_seed(emitter:Int, seed:Int):Bool
		return host._wgr_emitter3d_set_seed(emitter, seed) != 0;

	public static inline function wgr_emitter3d_get_count(emitter:Int):Int
		return host._wgr_emitter3d_get_count(emitter);

	public static inline function wgr_emitter3d_clear(emitter:Int):Void
		host._wgr_emitter3d_clear(emitter);

	public static inline function wgr_emitter3d_set_visible(emitter:Int, visible:Bool):Bool
		return host._wgr_emitter3d_set_visible(emitter, visible) != 0;

	public static inline function wgr_emitter3d_draw(emitter:Int):Void
		host._wgr_emitter3d_draw(emitter);

	public static inline function wgr_emitter2d_create(texture:Int):Int
		return host._wgr_emitter2d_create(texture);

	public static inline function wgr_emitter2d_destroy(emitter:Int):Void
		host._wgr_emitter2d_destroy(emitter);

	public static inline function wgr_emitter2d_set_source(emitter:Int, x:Float, y:Float, width:Float, height:Float):Bool
		return host._wgr_emitter2d_set_source(emitter, x, y, width, height) != 0;

	public static inline function wgr_emitter2d_set_frames(emitter:Int, columns:Int, rows:Int, count:Int, per_second:Float):Bool
		return host._wgr_emitter2d_set_frames(emitter, columns, rows, count, per_second) != 0;

	public static inline function wgr_emitter2d_set_position(emitter:Int, x:Float, y:Float):Bool
		return host._wgr_emitter2d_set_position(emitter, x, y) != 0;

	public static inline function wgr_emitter2d_jump(emitter:Int, x:Float, y:Float):Bool
		return host._wgr_emitter2d_jump(emitter, x, y) != 0;

	public static inline function wgr_emitter2d_set_rate(emitter:Int, per_second:Float):Bool
		return host._wgr_emitter2d_set_rate(emitter, per_second) != 0;

	public static inline function wgr_emitter2d_burst(emitter:Int, count:Int):Bool
		return host._wgr_emitter2d_burst(emitter, count) != 0;

	public static inline function wgr_emitter2d_set_emitting(emitter:Int, emitting:Bool):Bool
		return host._wgr_emitter2d_set_emitting(emitter, emitting) != 0;

	public static inline function wgr_emitter2d_is_emitting(emitter:Int):Bool
		return host._wgr_emitter2d_is_emitting(emitter) != 0;

	public static inline function wgr_emitter2d_set_max(emitter:Int, count:Int):Bool
		return host._wgr_emitter2d_set_max(emitter, count) != 0;

	public static inline function wgr_emitter2d_set_life(emitter:Int, min_seconds:Float, max_seconds:Float):Bool
		return host._wgr_emitter2d_set_life(emitter, min_seconds, max_seconds) != 0;

	public static inline function wgr_emitter2d_prewarm(emitter:Int, seconds:Float):Bool
		return host._wgr_emitter2d_prewarm(emitter, seconds) != 0;

	public static inline function wgr_emitter2d_set_spawn_box(emitter:Int, half_width:Float, half_height:Float):Bool
		return host._wgr_emitter2d_set_spawn_box(emitter, half_width, half_height) != 0;

	public static inline function wgr_emitter2d_set_spawn_circle(emitter:Int, radius:Float):Bool
		return host._wgr_emitter2d_set_spawn_circle(emitter, radius) != 0;

	public static inline function wgr_emitter2d_set_velocity(emitter:Int, x:Float, y:Float, spread:Float, speed_variance:Float):Bool
		return host._wgr_emitter2d_set_velocity(emitter, x, y, spread, speed_variance) != 0;

	public static inline function wgr_emitter2d_set_gravity(emitter:Int, x:Float, y:Float):Bool
		return host._wgr_emitter2d_set_gravity(emitter, x, y) != 0;

	public static inline function wgr_emitter2d_set_drag(emitter:Int, per_second:Float):Bool
		return host._wgr_emitter2d_set_drag(emitter, per_second) != 0;

	public static inline function wgr_emitter2d_set_inherit_velocity(emitter:Int, fraction:Float):Bool
		return host._wgr_emitter2d_set_inherit_velocity(emitter, fraction) != 0;

	public static inline function wgr_emitter2d_set_size(emitter:Int, start:Float, end:Float, variance:Float):Bool
		return host._wgr_emitter2d_set_size(emitter, start, end, variance) != 0;

	public static inline function wgr_emitter2d_set_color(emitter:Int, start:Int, end:Int):Bool
		return host._wgr_emitter2d_set_color(emitter, start, end) != 0;

	public static inline function wgr_emitter2d_add_size_key(emitter:Int, t:Float, size:Float):Bool
		return host._wgr_emitter2d_add_size_key(emitter, t, size) != 0;

	public static inline function wgr_emitter2d_clear_size_keys(emitter:Int):Bool
		return host._wgr_emitter2d_clear_size_keys(emitter) != 0;

	public static inline function wgr_emitter2d_add_color_key(emitter:Int, t:Float, color:Int):Bool
		return host._wgr_emitter2d_add_color_key(emitter, t, color) != 0;

	public static inline function wgr_emitter2d_clear_color_keys(emitter:Int):Bool
		return host._wgr_emitter2d_clear_color_keys(emitter) != 0;

	public static inline function wgr_emitter2d_add_palette_color(emitter:Int, color:Int):Bool
		return host._wgr_emitter2d_add_palette_color(emitter, color) != 0;

	public static inline function wgr_emitter2d_clear_palette(emitter:Int):Bool
		return host._wgr_emitter2d_clear_palette(emitter) != 0;

	public static inline function wgr_emitter2d_set_spin(emitter:Int, min:Float, max:Float):Bool
		return host._wgr_emitter2d_set_spin(emitter, min, max) != 0;

	public static inline function wgr_emitter2d_set_stretch(emitter:Int, seconds:Float):Bool
		return host._wgr_emitter2d_set_stretch(emitter, seconds) != 0;

	public static inline function wgr_emitter2d_set_alpha_mode(emitter:Int, mode:Int, cutoff:Float):Bool
		return host._wgr_emitter2d_set_alpha_mode(emitter, mode, cutoff) != 0;

	public static inline function wgr_emitter2d_set_seed(emitter:Int, seed:Int):Bool
		return host._wgr_emitter2d_set_seed(emitter, seed) != 0;

	public static inline function wgr_emitter2d_get_count(emitter:Int):Int
		return host._wgr_emitter2d_get_count(emitter);

	public static inline function wgr_emitter2d_clear(emitter:Int):Void
		host._wgr_emitter2d_clear(emitter);

	public static inline function wgr_emitter2d_set_visible(emitter:Int, visible:Bool):Bool
		return host._wgr_emitter2d_set_visible(emitter, visible) != 0;

	public static inline function wgr_emitter2d_draw(emitter:Int):Void
		host._wgr_emitter2d_draw(emitter);

	public static inline function wgr_shape3d_draw_grid(slices:Int, spacing:Float, color:Int):Void
		host._wgr_shape3d_draw_grid(slices, spacing, color);

	public static inline function wgr_debug_enable_fps(x:Int, y:Int, font_size:Int):Void
		host._wgr_debug_enable_fps(x, y, font_size);

	public static inline function wgr_render_begin_mode_3d():Void
		host._wgr_render_begin_mode_3d();

	public static inline function wgr_render_end_mode_3d():Void
		host._wgr_render_end_mode_3d();
	// --- END generated ---------------------------------------------------------

	/** vec2_t through the out-pointer, like the other struct returns. **/
	public static function wgr_text3d_get_size(text:Int):Vec2 {
		final out = scratch(8);
		host._wgr_text3d_get_size(out, text);
		final heap = host.HEAPF32;
		return new Vec2(heap[out >> 2], heap[(out >> 2) + 1]);
	}
}
