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

Working, at parity with `../simple`: the same scene, the same picking, in a headless
browser — model animating, sprite bobbing, both TTF fonts, music, 60 fps, and the pick
message reading `MODEL PICK: ... pick result y: 0.581142`.

The guest is Haxe compiled to JS (`src/Guest.hx`). It registers its four ops before
`wgr_guest_start` and then drives wgrender's API from inside them.

### Size

Everything a visitor downloads, against the other ports of the same scene (all linked
against the same wgrender web library — `BACKEND=webgl2 WEB_THREADS=0`, release):

| port | wasm | js | total | gzipped | vs C |
|---|---:|---:|---:|---:|---:|
| C (wgrender's example) |   690,116 | 64,910 |   755,026 | 315,188 | 1.00x |
| Nim |   713,584 | 65,138 |   778,722 | 325,062 | 1.03x |
| Beef |   846,131 | 66,674 |   912,805 | 392,828 | 1.21x |
| Haxe, in the wasm (../simple) | 1,685,600 | 69,587 | 1,755,187 | 483,670 | 2.32x |
| Haxe, as a guest (this) |   701,424 | 86,179 |   787,603 | 328,744 | **1.04x** |

The honest headline is **1.04x the C download**, not "less than half of ../simple" —
the interesting number is how close this gets to C, not how far it is from the
all-in-one build. This port's JS breaks down as:

| | bytes | gzipped | |
|---|---:|---:|---|
| `wgrender-host.js` | 67,424 | 24,061 | Emscripten glue |
| `guest.js` | 18,184 | 4,684 | **the whole game, from Haxe** |
| `boot.js` | 571 | 349 | the ESM shim that loads one and starts the other |

So Haxe costs about 4% over writing this in C: 11,308 bytes of wasm for the guest ABI
plus 18 KB of JS for the game, instead of a megabyte of runtime compiled in.

No `index.html` in any row — wgrender's page shell is ~8.6 KB and common to the other
ports, while this one's page is a 600-byte hand-rolled file, so counting HTML would
flatter this port for the wrong reason. The Nim row is its `WEB_THREADS=0` build; its
checked-out `out/web` is the threaded default (726,858 wasm) and doesn't compare.

### How much of the binding was reusable

The whole point of the two-layer split. `src/wgr/Wgr.hx` is `../simple`'s file with
target guards: **37 guard lines and 27 real edits, 3.9% of 1,373 lines**. Everything
structural — the handle abstracts, properties, enums, flags, `Vec2`/`Vec3`,
`PickResult` — carried over untouched.

What needed guarding was exactly what the host/guest model replaces or what hxcpp
needs specifically:

- the app lifecycle (`initValues`/`setInit`/`setFrame`/`run` and their trampolines) —
  the guest ABI enters the loop instead
- `Asset.ensureAsync`/`AssetTask` — the guest gets an id back, not a closure
  (`Asset.setHost` is shared)
- `Native`, the hxcpp pointer and callback plumbing
- the seven `@:to toRaw()` enum casts, which exist only to satisfy C++'s enum
  parameters
- four struct converters: hxcpp unpacks a C struct, the JS layer already returns the
  Haxe value
- `KeyboardState`, whose 512-int struct the JS layer does not marshal yet

`src/wgr/Raw.js.hx` is the other half — 51 calls hand-written for the ones that need
care, 46 generated by `tools/gen_raw_js.py` from `../simple/src/wgr/Raw.hx` so the two
ports cannot drift.

### What the marshalling layer has to get right

Three measured hazards, all handled in one place:

- **Never hold a heap view.** `ALLOW_MEMORY_GROWTH` detaches every `HEAPF32`/`HEAP32`
  that JS holds on any allocation — measured, a 192 MB `malloc` mid-frame took a
  cached view's `byteLength` to 0 while a fresh read was fine. Every read goes through
  `host.HEAPF32` at the point of use. Pointers survive growth; views don't.
- **Scratch is an arena per op.** Strings and struct-return slots come from
  `stackAlloc`, and `Guest.op` restores the stack pointer once when the op ends, fault
  or not. Haxe has no `finally`, so per-call restore would need a try/rethrow at every
  call site.
- **Structs return through a hidden out-pointer.** Confirmed against the wasm C ABI
  with a standalone test before trusting it: `vec2_t` and a 36-byte struct both came
  back through a first-argument pointer.

### Known gaps

- `KeyboardState` isn't marshalled (the other input paths are)
- the guest's ops are wrapped through `Reflect.makeVarArgs`, which is tidy but not the
  cheapest possible edge
- fault policy is still the default (log and continue); see above

## Build## Build

```sh
./build.py host     # out/web/wgrender-host.js + .wasm
./build.py sizes
node tools/drive.mjs   # headless browser smoke test; writes out/check.png
```

The host exports the guest ABI plus the slice of wgrender's C API the guest calls —
read from `../simple/src/wgr/Raw.hx`, so the two ports cannot drift apart (104 calls
today).
