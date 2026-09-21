/* Host glue for the guest ABI — see wgr_guest.h.
 *
 * Analogous to wg-vf's native/wg_vf.c: the glue owns the exports the host calls and
 * the bookkeeping, so a guest only implements handlers. Here the "host" calling in is
 * JavaScript, and the ops it installs are JS functions made into C function pointers
 * with Emscripten's addFunction. */
#include <stdint.h>
#include <stddef.h>

#include "wgr.h"
#include "wgr_guest.h"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define GUEST_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define GUEST_EXPORT
#endif

static wgr_guest_init_fn guest_init;
static wgr_guest_frame_fn guest_frame;
static wgr_guest_asset_fn guest_asset;
static wgr_guest_shutdown_fn guest_shutdown;

static int fault_policy = WGR_GUEST_FAULT_CONTINUE;
static int faulted;
static uint32_t frame_id;

GUEST_EXPORT void wgr_guest_register(wgr_guest_init_fn init, wgr_guest_frame_fn frame,
                                     wgr_guest_asset_fn asset, wgr_guest_shutdown_fn shutdown)
{
    guest_init = init;
    guest_frame = frame;
    guest_asset = asset;
    guest_shutdown = shutdown;
}

GUEST_EXPORT void wgr_guest_set_fault_policy(int policy) { fault_policy = policy; }
GUEST_EXPORT uint32_t wgr_guest_frame_id(void) { return frame_id; }
GUEST_EXPORT int wgr_guest_faulted(void) { return faulted; }

static void fault(const char *op, int code)
{
    wgr_logger_message(WGR_LOGGER_LEVEL_ERROR, "wgr_guest: %s faulted (%d)", op, code);
    if (fault_policy == WGR_GUEST_FAULT_FATAL) {
        faulted = 1;
        wgr_request_quit();
    }
}

/* --- the ops, as wgrender's lifecycle callbacks --- */

static void host_init(void *user)
{
    (void)user;
    if (guest_init == NULL) {
        return;
    }
    int rc = guest_init();
    if (rc != 0) {
        fault("init", rc);
    }
}

static void host_frame(float dt, float tick_fraction, void *user)
{
    (void)tick_fraction;
    (void)user;
    frame_id++;
    if (faulted || guest_frame == NULL) {
        return;
    }
    int rc = guest_frame(dt, frame_id);
    if (rc != 0) {
        fault("frame", rc);
    }
}

/* --- assets: the glue holds the function pointers, the guest holds an id --- */

static void asset_done(const char *path, void *user, int ok)
{
    if (faulted || guest_asset == NULL) {
        return;
    }
    int rc = guest_asset((uint32_t)(uintptr_t)user, path, ok);
    if (rc != 0) {
        fault("asset", rc);
    }
}

static void asset_ok(const char *path, void *user) { asset_done(path, user, 1); }
static void asset_failed(const char *path, void *user) { asset_done(path, user, 0); }

GUEST_EXPORT int wgr_guest_asset_load(const char *path, uint32_t id)
{
    wgr_handle_t task = wgr_asset_ensure_async(path, NULL, WGR_ASSET_NONE);
    return wgr_asset_add_task(task, asset_ok, asset_failed, (void *)(uintptr_t)id)
           == WGR_ASSET_ADD_TASK_OK;
}

GUEST_EXPORT int wgr_guest_start(int width, int height, const char *title, uint32_t flags)
{
    /* Copied: a guest passing scratch memory shouldn't have to keep it alive. */
    static char kept_title[128];
    size_t i = 0;
    if (title != NULL) {
        for (; i + 1 < sizeof kept_title && title[i] != '\0'; i++) {
            kept_title[i] = title[i];
        }
    }
    kept_title[i] = '\0';

    wgr_init_values(width, height, kept_title, flags);
    wgr_set_init(host_init, NULL);
    wgr_set_frame(host_frame, NULL);
    return wgr_run();
}

/* Emscripten still wants an entry point; the guest starts the host, not main(). */
int main(void) { return 0; }
