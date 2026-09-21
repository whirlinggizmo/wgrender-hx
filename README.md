# simple-js — wgrender as a host, the game as a guest

A second web port of wgrender's `simple`, next to [../simple](../simple) (Haxe →
hxcpp → wasm, all in one module). Here the split is the other way round:
**libwgrender is a wasm host and the game is a guest module in JS**, compiled from
Haxe.

The point is to find out what that costs and what it feels like, against the same
scene. `../simple` is the all-in-one comparison against the Nim and Beef ports; this
is the "ship it" variant.

## The shape

It follows [wg-vf](../../github/whirlinggizmo/wg-vf)'s host/guest split, applied to a
renderer rather than a simulation:

| The guest owns | The host owns |
|---|---|
| Game state and logic | When ops are called, and in what order |
| The handles it creates | The window, the loop, assets, input, the scene |

`host/wgr_guest.h` is the whole contract — four ops (`init`, `frame`, `asset`,
`shutdown`), registered once. wgrender was already most of the way to being a host:
it owns the loop through `sapp_run`, hands out handles rather than pointers, and
keeps a retained scene that draws in one call.

Guarantees the host makes, same as wg-vf's:

1. **Serial, non-reentrant, single-threaded.** Ops are never called concurrently or
   nested. The guest *may* call wgrender's API during an op — that is the point — but
   the host will not re-enter the guest while one is running.
2. **`init` first, `shutdown` last.**
3. **`asset` fires on the main thread during a later frame**, never inside another op.

Ops return 0 for ok, nonzero for a fault. A guest in a language with exceptions
catches at its own edge and converts a throw into a nonzero return — an exception that
escapes into the host's C frames takes the loop down (measured: on the web the page
freezes on an opaque `Uncaught [object WebAssembly.Exception]` with the message gone).
What the host does with a fault is `wgr_guest_set_fault_policy`: log and keep going,
or stop calling the guest and quit. **Still to decide** — wg-vf's rule for a
host-driven op is fatal, on the grounds that a faulted guest's state is untrustworthy.

## Status

Skeleton works end to end, with a hand-written JS guest (`web/guest.js`) standing in
for the Haxe one:

- the guest registers its four ops (`addFunction`) *before* `wgr_guest_start`, so
  `init` runs on the host's own schedule
- `init` sets the asset host and builds a scene, camera and light
- `wgr_guest_asset_load` → the `asset` op fires with the local path → `wgr_font_create`
- `frame` drives `render_begin` / `scene_draw` / `text_draw_ex` / `render_end` at
  60 fps, marshalling a fresh string every frame
- verified in a headless browser: 349 frames in 5.83 s, text rendering in the loaded
  TrueType font

### Size so far

| | bytes | gzipped |
|---|---:|---:|
| host wasm | 701,246 | 299,582 |
| host js (Emscripten glue) | 67,424 | 24,061 |
| guest js (placeholder) | 2,452 | 1,039 |
| **total** | **771,122** | |
| ../simple, wasm alone | 1,685,600 | 458,622 |

The host is ~11 KB of wasm over wgrender's own C `simple`, so the guest ABI is nearly
free. The whole download is less than half `../simple`'s wasm.

## Next

- `src/` — the Haxe guest: `Raw.js.hx` (externs + marshalling) under the existing
  `wgr.Wgr` layer from `../simple`, only 39 of whose 1,119 lines are C++-specific
- the four hazards as explicit tests, not incidental:
  **detached heap views** (`ALLOW_MEMORY_GROWTH` detaches a cached `HEAPF32` on any
  allocation — confirmed, and the struct-return reads are exactly where it would
  bite), **shadow-stack balance**, **async continuations** running outside the frame,
  and the **fault policy** above
- the rest of the scene (model, sprite, music, picking) to match `../simple`

## Build

```sh
./build.py host     # out/web/wgrender-host.js + .wasm
./build.py sizes
node tools/drive.mjs   # headless browser smoke test; writes out/check.png
```

The host exports the guest ABI plus the slice of wgrender's C API the guest calls —
read from `../simple/src/wgr/Raw.hx`, so the two ports cannot drift apart (104 calls
today).
