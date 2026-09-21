package wgr.impl;

/**
	Raw wgrender bindings for the hxcpp guest: the slice of the C API this example
	uses, as is (C names, C types), plus the guest ABI from `host/wgr_guest.h`.

	This is `../simple/src/wgr/Raw.hx` with the guest ABI added — the counterpart of
	`Raw.js.hx`, chosen by target. Most code wants the wrappers in `wgr.Wgr` instead (Haxe types, abstracts
	with methods, closures).

	Not bound: 2D sprites and shapes, particles, materials, custom shaders, the
	environment, events and gamepads. Adding one is a line here and a wrapper there.

	Declarations come straight from wgrender's public headers (`@:include("wgr.h")`),
	so the C++ compiler checks every prototype and struct layout for us — a wrong
	argument type or a stale struct field is a compile error, not a crash.
**/
import cpp.ConstCharStar;
import cpp.RawPointer;
import cpp.UInt32;

typedef WgrHandle = UInt32;
typedef WgrColor = UInt32;

/** C `void *`: the opaque user pointer every wgrender callback carries. **/
typedef VoidStar = RawPointer<cpp.Void>;

typedef AssetCallbackFn = cpp.Callable<(path:ConstCharStar, user:VoidStar) -> Void>;
typedef LifecycleFn = cpp.Callable<(user:VoidStar) -> Void>;
typedef FrameFn = cpp.Callable<(dt:Single, tickFraction:Single, user:VoidStar) -> Void>;

@:include("wgr.h") @:native("vec2_t") @:structAccess @:unreflective
extern class CVec2 {
	var x:Single;
	var y:Single;
}

@:include("wgr.h") @:native("vec3_t") @:structAccess @:unreflective
extern class CVec3 {
	var x:Single;
	var y:Single;
	var z:Single;
}

@:include("wgr.h") @:native("wgr_mouse_state_t") @:structAccess @:unreflective
extern class CMouseState {
	var x:Int;
	var y:Int;
	var wheel:Single;
	var wheel_x:Single;
	var left:Int;
	var right:Int;
	var middle:Int;
	/** C `int[3]`, so it reads as a pointer here; index it in place. **/
	var buttons:RawPointer<Int>;
	var dx:Int;
	var dy:Int;
}

@:include("wgr.h") @:native("wgr_keyboard_state_t") @:structAccess @:unreflective
extern class CKeyboardState {
	var max_num_keys:Int;
	/** C `int[512]`: a wgr_button_state_t per key, indexed by key code. **/
	var keys:RawPointer<Int>;
	var pressed_key:Int;
	var pressed_char:Int;
	var num_pressed_keys:Int;
	var pressed_keys:RawPointer<Int>;
	var num_pressed_chars:Int;
	var pressed_chars:RawPointer<Int>;
}

/**
	C enum parameter types. C++ will not take an `int` where the header says
	`wgr_keycode_t`, so the Haxe enums in `wgr.Wgr` cast to these — see their `toRaw`.
**/
@:include("wgr.h") @:native("wgr_log_level_t") @:structAccess @:unreflective
extern class CLogLevel {}

@:include("wgr.h") @:native("wgr_camera3d_projection_t") @:structAccess @:unreflective
extern class CProjection {}

@:include("wgr.h") @:native("wgr_light_type_t") @:structAccess @:unreflective
extern class CLightType {}

@:include("wgr.h") @:native("wgr_sprite3d_facing_t") @:structAccess @:unreflective
extern class CSpriteFacing {}

@:include("wgr.h") @:native("wgr_keycode_t") @:structAccess @:unreflective
extern class CKeycode {}

@:include("wgr.h") @:native("wgr_text_align_t") @:structAccess @:unreflective
extern class CTextAlign {}

@:include("wgr.h") @:native("wgr_pick_result_t") @:structAccess @:unreflective
extern class CPickResult {
	var hit:Bool;
	var handle:WgrHandle;
	var distance:Single;
	var point_local:CVec3;
	var point_world:CVec3;
	var normal_local:CVec3;
	var normal_world:CVec3;
}


/** The guest ABI (host/wgr_guest.h) as C function pointers. **/
typedef GuestInitFn = cpp.Callable<() -> Int>;
typedef GuestFrameFn = cpp.Callable<(dt:Single, frameId:UInt32) -> Int>;
typedef GuestAssetFn = cpp.Callable<(id:UInt32, path:ConstCharStar, ok:Int) -> Int>;
typedef GuestShutdownFn = cpp.Callable<() -> Int>;

@:keep @:unreflective @:include("wgr_guest.h")
extern class GuestRaw {
	@:native("wgr_guest_register")
	static function wgr_guest_register(init:GuestInitFn, frame:GuestFrameFn, asset:GuestAssetFn,
		shutdown:GuestShutdownFn):Void;
	@:native("wgr_guest_set_fault_policy")
	static function wgr_guest_set_fault_policy(policy:Int):Void;
	@:native("wgr_guest_start")
	static function wgr_guest_start(width:Int, height:Int, title:ConstCharStar, flags:UInt32):Int;
	@:native("wgr_guest_asset_load")
	static function wgr_guest_asset_load(path:ConstCharStar, id:UInt32):Int;
	@:native("wgr_guest_frame_id")
	static function wgr_guest_frame_id():UInt32;
	@:native("wgr_guest_faulted")
	static function wgr_guest_faulted():Int;
}

@:keep @:unreflective @:include("wgr.h")
extern class Raw {
	// --- lifecycle (wgr.h) ---
	@:native("wgr_init_values")
	static function wgr_init_values(width:Int, height:Int, title:ConstCharStar, flags:UInt32):Int;
	@:native("wgr_set_init")
	static function wgr_set_init(fn:LifecycleFn, user:VoidStar):Void;
	@:native("wgr_set_frame")
	static function wgr_set_frame(fn:FrameFn, user:VoidStar):Void;
	@:native("wgr_run")
	static function wgr_run():Int;
	@:native("wgr_get_platform")
	static function wgr_get_platform():ConstCharStar;
	@:native("wgr_set_target_fps")
	static function wgr_set_target_fps(fps:Int):Void;
	@:native("wgr_request_quit")
	static function wgr_request_quit():Void;

	// --- logging (wgr_logger.h) ---
	@:native("wgr_logger_set_level")
	static function wgr_logger_set_level(level:CLogLevel):Void;
	/** The varargs form, fixed at one `%s` — enough for a Haxe string. **/
	@:native("wgr_logger_message")
	static function wgr_logger_message(level:CLogLevel, format:ConstCharStar, text:ConstCharStar):Void;

	// --- assets (wgr_asset.h) ---
	@:native("wgr_asset_set_host")
	static function wgr_asset_set_host(host:ConstCharStar):Void;
	@:native("wgr_asset_ensure_async")
	static function wgr_asset_ensure_async(path:ConstCharStar, fetchUrl:ConstCharStar, flags:UInt32):WgrHandle;
	@:native("wgr_asset_add_task")
	static function wgr_asset_add_task(task:WgrHandle, onSuccess:AssetCallbackFn, onFailure:AssetCallbackFn,
		user:VoidStar):Int;

	// --- colors (wgr_color.h) ---
	@:native("wgr_color_rgba")
	static function wgr_color_rgba(r:Int, g:Int, b:Int, a:Int):WgrColor;

	// --- audio / sound (wgr_audio.h, wgr_sound.h) ---
	@:native("wgr_audio_create")
	static function wgr_audio_create(path:ConstCharStar):WgrHandle;
	@:native("wgr_audio_release")
	static function wgr_audio_release(audio:WgrHandle):Void;
	@:native("wgr_sound_create")
	static function wgr_sound_create(audio:WgrHandle):WgrHandle;
	@:native("wgr_sound_set_loop")
	static function wgr_sound_set_loop(sound:WgrHandle, loop:Bool):Bool;
	@:native("wgr_sound_play")
	static function wgr_sound_play(sound:WgrHandle):Bool;
	@:native("wgr_sound_destroy")
	static function wgr_sound_destroy(handle:WgrHandle):Void;

	// --- mesh / model (wgr_model.h) ---
	@:native("wgr_mesh_create")
	static function wgr_mesh_create(path:ConstCharStar):WgrHandle;
	@:native("wgr_mesh_release")
	static function wgr_mesh_release(mesh:WgrHandle):Void;
	@:native("wgr_model_create")
	static function wgr_model_create(mesh:WgrHandle):WgrHandle;
	@:native("wgr_model_set_animation")
	static function wgr_model_set_animation(model:WgrHandle, index:Int):Bool;
	@:native("wgr_model_set_animation_speed")
	static function wgr_model_set_animation_speed(model:WgrHandle, speed:Single):Bool;
	@:native("wgr_model_set_animation_loop")
	static function wgr_model_set_animation_loop(model:WgrHandle, loop:Bool):Bool;
	@:native("wgr_model_set_transform")
	static function wgr_model_set_transform(model:WgrHandle, px:Single, py:Single, pz:Single, rx:Single, ry:Single,
		rz:Single, sx:Single, sy:Single, sz:Single):Bool;
	@:native("wgr_model_set_tint")
	static function wgr_model_set_tint(model:WgrHandle, color:WgrColor):Bool;
	@:native("wgr_model_animate")
	static function wgr_model_animate(model:WgrHandle, dt:Single):Bool;
	@:native("wgr_model_destroy")
	static function wgr_model_destroy(handle:WgrHandle):Void;

	// --- texture / sprite3d (wgr_texture.h, wgr_sprite3d.h) ---
	@:native("wgr_texture_create")
	static function wgr_texture_create(path:ConstCharStar):WgrHandle;
	@:native("wgr_texture_release")
	static function wgr_texture_release(texture:WgrHandle):Void;
	@:native("wgr_sprite3d_create")
	static function wgr_sprite3d_create(texture:WgrHandle):WgrHandle;
	@:native("wgr_sprite3d_set_facing")
	static function wgr_sprite3d_set_facing(sprite:WgrHandle, facing:CSpriteFacing):Bool;
	@:native("wgr_sprite3d_set_transform")
	static function wgr_sprite3d_set_transform(sprite:WgrHandle, px:Single, py:Single, pz:Single, rx:Single, ry:Single,
		rz:Single, sx:Single, sy:Single, sz:Single):Bool;
	@:native("wgr_sprite3d_set_tint")
	static function wgr_sprite3d_set_tint(sprite:WgrHandle, color:WgrColor):Bool;
	@:native("wgr_sprite3d_destroy")
	static function wgr_sprite3d_destroy(handle:WgrHandle):Void;

	// --- fonts / text (wgr_font.h, wgr_text.h) ---
	@:native("wgr_font_create")
	static function wgr_font_create(path:ConstCharStar):WgrHandle;
	@:native("wgr_font_release")
	static function wgr_font_release(font:WgrHandle):Void;
	@:native("wgr_text_draw")
	static function wgr_text_draw(text:ConstCharStar, x:Int, y:Int, size:Int, color:WgrColor):Void;
	@:native("wgr_text_draw_ex")
	static function wgr_text_draw_ex(font:WgrHandle, text:ConstCharStar, x:Single, y:Single, size:Single,
		color:WgrColor):Void;
	@:native("wgr_text_measure")
	static function wgr_text_measure(text:ConstCharStar, size:Int):Int;
	@:native("wgr_text_measure_ex")
	static function wgr_text_measure_ex(font:WgrHandle, text:ConstCharStar, size:Single):CVec2;
	@:native("wgr_text_draw_fps_ex")
	static function wgr_text_draw_fps_ex(font:WgrHandle, x:Single, y:Single, size:Single, color:WgrColor):Void;

	// --- camera / light / scene (wgr_camera3d.h, wgr_light.h, wgr_scene.h) ---
	@:native("wgr_camera3d_create")
	static function wgr_camera3d_create(projection:CProjection):WgrHandle;
	@:native("wgr_camera3d_set_view")
	static function wgr_camera3d_set_view(camera:WgrHandle, px:Single, py:Single, pz:Single, tx:Single, ty:Single,
		tz:Single, ux:Single, uy:Single, uz:Single):Bool;
	@:native("wgr_light_create")
	static function wgr_light_create(kind:CLightType):WgrHandle;
	@:native("wgr_light_set_direction")
	static function wgr_light_set_direction(light:WgrHandle, x:Single, y:Single, z:Single):Bool;
	@:native("wgr_light_set_intensity")
	static function wgr_light_set_intensity(light:WgrHandle, intensity:Single):Bool;
	@:native("wgr_scene_create")
	static function wgr_scene_create():WgrHandle;
	@:native("wgr_scene_set_active_camera")
	static function wgr_scene_set_active_camera(scene:WgrHandle, camera:WgrHandle):Void;
	@:native("wgr_scene_add")
	static function wgr_scene_add(scene:WgrHandle, drawable:WgrHandle, layer:Int):Bool;
	@:native("wgr_scene_set_ambient")
	static function wgr_scene_set_ambient(scene:WgrHandle, color:WgrColor, intensity:Single):Bool;
	@:native("wgr_scene_draw")
	static function wgr_scene_draw(scene:WgrHandle):Void;
	@:native("wgr_scene_pick")
	static function wgr_scene_pick(scene:WgrHandle, camera:WgrHandle, mouseX:Single, mouseY:Single):CPickResult;
	@:native("wgr_camera3d_destroy")
	static function wgr_camera3d_destroy(camera:WgrHandle):Void;
	@:native("wgr_light_destroy")
	static function wgr_light_destroy(light:WgrHandle):Void;
	@:native("wgr_scene_destroy")
	static function wgr_scene_destroy(scene:WgrHandle):Void;

	// --- retained text objects (wgr_text.h, wgr_text2d.h, wgr_text3d.h) ---
	@:native("wgr_text_set_default_font")
	static function wgr_text_set_default_font(font:WgrHandle):Bool;
	@:native("wgr_text_get_default_font")
	static function wgr_text_get_default_font():WgrHandle;
	@:native("wgr_text_draw_fps")
	static function wgr_text_draw_fps(x:Int, y:Int):Void;
	@:native("wgr_text_draw_3d")
	static function wgr_text_draw_3d(font:WgrHandle, text:ConstCharStar, x:Single, y:Single, z:Single, size:Single,
		color:WgrColor):Void;

	@:native("wgr_text2d_create")
	static function wgr_text2d_create(font:WgrHandle):WgrHandle;
	@:native("wgr_text2d_destroy")
	static function wgr_text2d_destroy(text:WgrHandle):Void;
	@:native("wgr_text2d_set_font")
	static function wgr_text2d_set_font(text:WgrHandle, font:WgrHandle):Bool;
	@:native("wgr_text2d_set_text")
	static function wgr_text2d_set_text(text:WgrHandle, string:ConstCharStar):Bool;
	@:native("wgr_text2d_set_position")
	static function wgr_text2d_set_position(text:WgrHandle, x:Single, y:Single):Bool;
	@:native("wgr_text2d_set_size")
	static function wgr_text2d_set_size(text:WgrHandle, size:Single):Bool;
	@:native("wgr_text2d_set_color")
	static function wgr_text2d_set_color(text:WgrHandle, color:WgrColor):Bool;
	@:native("wgr_text2d_set_visible")
	static function wgr_text2d_set_visible(text:WgrHandle, visible:Bool):Bool;
	@:native("wgr_text2d_is_visible")
	static function wgr_text2d_is_visible(text:WgrHandle):Bool;
	@:native("wgr_text2d_set_pickable")
	static function wgr_text2d_set_pickable(text:WgrHandle, pickable:Bool):Bool;
	@:native("wgr_text2d_is_pickable")
	static function wgr_text2d_is_pickable(text:WgrHandle):Bool;
	@:native("wgr_text2d_set_enabled")
	static function wgr_text2d_set_enabled(text:WgrHandle, enabled:Bool):Bool;
	@:native("wgr_text2d_is_enabled")
	static function wgr_text2d_is_enabled(text:WgrHandle):Bool;
	@:native("wgr_text2d_set_align")
	static function wgr_text2d_set_align(text:WgrHandle, horizontal:CTextAlign, vertical:CTextAlign):Bool;
	@:native("wgr_text2d_set_max_width")
	static function wgr_text2d_set_max_width(text:WgrHandle, width:Single):Bool;
	@:native("wgr_text2d_measure_width")
	static function wgr_text2d_measure_width(text:WgrHandle):Single;
	@:native("wgr_text2d_measure_height")
	static function wgr_text2d_measure_height(text:WgrHandle):Single;
	@:native("wgr_text2d_draw")
	static function wgr_text2d_draw(text:WgrHandle):Void;

	@:native("wgr_text3d_create")
	static function wgr_text3d_create(font:WgrHandle):WgrHandle;
	@:native("wgr_text3d_destroy")
	static function wgr_text3d_destroy(text:WgrHandle):Void;
	@:native("wgr_text3d_set_font")
	static function wgr_text3d_set_font(text:WgrHandle, font:WgrHandle):Bool;
	@:native("wgr_text3d_set_text")
	static function wgr_text3d_set_text(text:WgrHandle, string:ConstCharStar):Bool;
	@:native("wgr_text3d_set_size")
	static function wgr_text3d_set_size(text:WgrHandle, size:Single):Bool;
	@:native("wgr_text3d_set_align")
	static function wgr_text3d_set_align(text:WgrHandle, horizontal:CTextAlign, vertical:CTextAlign):Bool;
	@:native("wgr_text3d_set_max_width")
	static function wgr_text3d_set_max_width(text:WgrHandle, width:Single):Bool;
	@:native("wgr_text3d_set_transform")
	static function wgr_text3d_set_transform(text:WgrHandle, x:Single, y:Single, z:Single, rx:Single, ry:Single,
		rz:Single):Bool;
	@:native("wgr_text3d_set_facing")
	static function wgr_text3d_set_facing(text:WgrHandle, facing:CSpriteFacing):Bool;
	@:native("wgr_text3d_set_color")
	static function wgr_text3d_set_color(text:WgrHandle, color:WgrColor):Bool;
	@:native("wgr_text3d_set_visible")
	static function wgr_text3d_set_visible(text:WgrHandle, visible:Bool):Bool;
	@:native("wgr_text3d_is_visible")
	static function wgr_text3d_is_visible(text:WgrHandle):Bool;
	@:native("wgr_text3d_set_pickable")
	static function wgr_text3d_set_pickable(text:WgrHandle, pickable:Bool):Bool;
	@:native("wgr_text3d_is_pickable")
	static function wgr_text3d_is_pickable(text:WgrHandle):Bool;
	@:native("wgr_text3d_set_enabled")
	static function wgr_text3d_set_enabled(text:WgrHandle, enabled:Bool):Bool;
	@:native("wgr_text3d_is_enabled")
	static function wgr_text3d_is_enabled(text:WgrHandle):Bool;
	@:native("wgr_text3d_get_size")
	static function wgr_text3d_get_size(text:WgrHandle):CVec2;
	@:native("wgr_text3d_draw")
	static function wgr_text3d_draw(text:WgrHandle):Void;

	// --- frame (wgr_render.h, wgr_window.h, wgr_input.h) ---
	@:native("wgr_render_begin")
	static function wgr_render_begin():Void;
	@:native("wgr_render_end")
	static function wgr_render_end():Void;
	@:native("wgr_render_clear_background")
	static function wgr_render_clear_background(color:WgrColor):Void;
	@:native("wgr_window_get_screen_size")
	static function wgr_window_get_screen_size():CVec2;
	@:native("wgr_input_get_mouse_state")
	static function wgr_input_get_mouse_state():CMouseState;
	/** WGR_BUTTON_*; WGR_BUTTON_UP for an unknown key. **/
	@:native("wgr_input_get_key")
	static function wgr_input_get_key(key:CKeycode):Int;
	@:native("wgr_input_get_keyboard_state")
	static function wgr_input_get_keyboard_state():CKeyboardState;
}
