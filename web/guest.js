// A hand-written JS guest, to prove the ABI before the Haxe one replaces it.
export function makeGuest(host) {
    const ASSET_BASE = "/assets", DEBUG_FONT = "fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
    const FONT_ID = 1;
    let scene = 0, camera = 0, font = 0, elapsed = 0;

    // NOTE: never hoist a HEAP view — ALLOW_MEMORY_GROWTH detaches it on any alloc.
    const cstr = (s) => { // caller-scoped: valid until the enclosing stackRestore
        const len = host.lengthBytesUTF8(s) + 1, p = host.stackAlloc(len);
        host.stringToUTF8(s, p, len);
        return p;
    };
    const withStack = (fn) => { const sp = host.stackSave(); try { return fn(); } finally { host.stackRestore(sp); } };

    return {
        cstr: (s) => cstr(s), // for boot.js's title, before any frame
        init() {
            withStack(() => host._wgr_asset_set_host(cstr(ASSET_BASE)));
            host._wgr_logger_set_level(3); // warn
            host._wgr_set_target_fps(60);
            camera = host._wgr_camera3d_create(0);
            host._wgr_camera3d_set_view(camera, 12, 12, 12, 0, 1, 0, 0, 1, 0);
            scene = host._wgr_scene_create();
            host._wgr_scene_set_active_camera(scene, camera);
            const sun = host._wgr_light_create(0);
            host._wgr_light_set_direction(sun, -0.6, -1.0, -0.5);
            host._wgr_light_set_intensity(sun, 3.0);
            host._wgr_scene_add(scene, sun, 0);
            host._wgr_scene_set_ambient(scene, 0xFFFFFFFF, 0.25);
            withStack(() => host._wgr_guest_asset_load(cstr(DEBUG_FONT), FONT_ID));
            console.log("GUEST_INIT ok");
        },
        frame(dt, frameId) {
            elapsed += dt;
            host._wgr_render_begin();
            host._wgr_render_clear_background(0xF5F5F5FF);
            host._wgr_scene_draw(scene);
            withStack(() => {
                const s = `frame ${frameId}  elapsed ${elapsed.toFixed(2)}  font ${font ? "loaded" : "pending"}`;
                host._wgr_text_draw_ex(font, cstr(s), 10, 10, 18, 0x000000FF);
            });
            host._wgr_render_end();
            if (frameId % 60 === 0) console.log(`FRAME ${frameId} font=${font}`);
        },
        asset(id, pathPtr, ok) {
            const path = host.UTF8ToString(pathPtr);
            console.log(`GUEST_ASSET id=${id} ok=${ok} ${path}`);
            if (id === FONT_ID && ok) font = host._wgr_font_create(pathPtr);
        },
    };
}
