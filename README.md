# wgrender-hx

Haxe bindings for [wgrender](../wgrender-c), over two targets from one API:

- **hxcpp** — native desktop, or compiled into the wasm alongside wgrender
- **js** — wgrender is a wasm *host* and your game is a guest module, so the Haxe
  runtime never enters the binary

```haxe
import wgr.*;

final mesh = Mesh.create(path);
model = new Model(mesh);      // wgrender's rule: object from resource, resource from path
mesh.release();               // the model holds its own reference
model.animationLoop = true;
model.tint = Color.RAYWHITE;
scene.add(model);             // takes a Model, Sprite3D, Text2D, Text3D or Light

if (pick.handle == model) ... // the untyped pick handle still compares to typed ones
```

## Layout

```
src/wgr/*.hx          the API — one module per wgrender public header
src/wgr/import.hx     gives those modules the C surface
src/wgr/impl/         the C surface and the guest ABI, chosen by target
  Raw.hx                #error for a target with no implementation
  Raw.cpp.hx            hxcpp externs against wgr.h
  Raw.js.hx             calls the host module's exports, and marshals
  GuestAbi.{cpp,js}.hx  installing the guest's ops, per target
host/wgr_guest.{c,h}  the guest ABI: wgrender as a host, four ops
tools/gen_raw.py      writes BOTH impl/Raw.*.hx whole, from wgrender's include/*.h
tools/gen_keys.py     regenerates wgr.Key from wgrender's wgr_keys.h
tools/coverage.py     what the binding reaches, and what wrapping next buys
```

Every handle kind is an `abstract` over `Int` and every method is `inline`, so the API
layer compiles away: a call costs what the C call costs. The only allocations are the
small value objects (`Vec2`, `Vec3`, `MouseState`, `PickResult`) the wrappers return.

### Why handles aren't `null`

A handle is 0 when it doesn't exist, and `isNone` reports that — rather than the
`model != null` a Haxe developer would reach for first. That is deliberate, and
measured:

- **`null` is not 0.** On hxcpp `Null<Int>(0) == null` is `false`, so the two would
  have to be mapped at every boundary, in both directions.
- **`Null<Model>` stops being an `Int`.** hxcpp renders it as `::Dynamic` — boxed, and
  no longer inlinable, which is the whole point of the layer.
- It would only be free on js, where `null` is native.

A field needs no initialiser either way: `isNone` treats js's `undefined` as none, so
`static var model:Model;` is correct on both targets. Without that it would be correct
on hxcpp (an uninitialised `Int` static is 0) and quietly wrong on js (`undefined == 0`
is `false`).

## The two shapes

An **all-in-one** app calls `Wgr.initValues` / `setInit` / `setFrame` / `run` and is
compiled into the binary (or the wasm) with wgrender. A **guest** app implements
`host/wgr_guest.h`'s four ops — `init`, `frame`, `asset`, `shutdown` — and the host
calls them; on js the host is a wasm module the page loads, on hxcpp it is linked in
and the Haxe program's `main` is the entry point.

The `@:buildXml` carrying the link configuration rides on `wgr.impl.Raw`, because
every program that touches wgrender at all reaches that class — anything in the API
layer can be stripped by `-dce full` out from under the build.

15 of the 42 API modules carry a target guard; the rest compile for both untouched.

## Logging

`Log.info(msg)` reaches wgrender's logger through `wgr_logger_message_source`, with
the file and line filled in by the compiler from `haxe.PosInfos` — so a line reads
`[INFO ] Guest.hx:91: ...`, naming the Haxe call site rather than generated C++.
`Log.plain(level, msg)` is the bare form.

The message is handed over as a `%s` argument, never as the format string itself, so
text can't be read as a format directive and nothing has to be escaped. On js, a log
before the host module is attached falls back to `console.log` rather than throwing —
startup going wrong is exactly when you want the log.

## Assets

`Assets.defaultBase()` resolves where assets load from at run time, rather than from a
compile-time define, so a built program is relocatable and a development build uses
the same lookup a shipped one does:

| | |
|---|---|
| web (js or hxcpp/Emscripten) | `/assets` — what `tools/serve.py` mounts, and what a host should serve |
| native | `$WGR_ASSET_BASE`, then an `assets` directory beside the executable, then `assets` relative to the working directory |

An app's build is expected to put `assets` next to the built executable — the examples
link it to wherever wgrender is checked out.

## Using it

```sh
haxelib dev wgrender-hx /path/to/wgrender-hx
```

then `-lib wgrender-hx`, plus `-D WGR_BUILD_XML=<file>` naming an hxcpp build-tool XML
that says where wgrender's headers and library are. See the examples for one that
generates it: [simple](../../../haxe/simple) (guest, web and native) and
[simple-hxcpp](../../../haxe/simple-hxcpp) (all-in-one, the size comparison against the
Nim and Beef ports).

## Status

A spike, not a release. `wgr.impl.Raw` covers all 466 of wgrender's calls on hxcpp,
and the hand-written API layer above it wraps 230. Measured against wgrender's 33 C
examples:

| | |
|---|---|
| need nothing more | `font`, `hello`, `model`, `particles`, `simple` |
| within five wrappers | `hello3d`, `quit`, `tick`, `audio`, `force_fetch`, `instancing`, `environment`, `gamepad`, `materials`, `render_target`, `scene3d`, `sprite3d`, `textures` |
| six to ten | `fetch`, `meshes`, `pick`, `lights`, `loading` |
| more | `shadows`, `sprite2d`, `2d`, `touch`, `clay`, `postprocess`, `text3d`, `window`, `ui`, `shaders` |

`tools/coverage.py` prints that, keeps it current, and ranks what to wrap next by how
many examples it unblocks — today `shape3d` (9), `sprite2d` (6), then `mesh`, `scene`,
`texture` and `sprite3d` (5 each).

It also holds the list of things deliberately *not* reached on js — twelve calls that
take a C function pointer or a `void *`, plus `wgr_input_get_keyboard_state`, whose
512 ints want a heap reader rather than a copy per frame. `--check` fails if one of
them turns up in `Raw.js.hx` after all, so a decision and a to-do stay distinguishable.
That idea is taken whole from librl's `tools/audit_binding_parity.py`.

## Regenerating the C surface

`tools/gen_raw.py` reads wgrender's `include/*.h` and writes **both** `impl/Raw.cpp.hx`
and `impl/Raw.js.hx` whole — neither is ever patched, so the answer to an API change is
to run it and read what it says:

```
$ tools/gen_raw.py
wgrender-c: 466 functions, 18 enums, 11 structs
  Raw.cpp.hx  456 externs
  Raw.js.hx   449 wrappers
```

**hxcpp reaches all 466 of wgrender's public functions.** On js it reaches 455; the
other 11 take a C function pointer or a `void *`, which the guest ABI replaces there,
and `wgr_input_get_keyboard_state` returns a 512-int struct that would be a poor thing
to copy per frame — it wants a reader that indexes the heap, not a value.

The tool derives the enum cast types, the struct externs and the struct-return heap
reads from the headers. It needs help for three things, declared in its `SPEC` rather
than edited into its output: which C callback typedefs map to which Haxe function
type, which returned structs map to which public value class (whose constructor must
take the C fields in order), and which functions to skip. Anything it can't map is
left out and **listed**, so a gap is reported rather than silent. Today the only entry
is the two varargs loggers, which it re-adds at fixed arity from `MANUAL`.

Because the binding now declares wgrender's whole API, an app's build derives the
host's `EXPORTED_FUNCTIONS` from the calls its *compiled guest* makes rather than from
the binding — Emscripten cannot strip what is exported, and exporting everything cost
75 KB. The particles example exports 66 and its host wasm is 402 KB against simple's
689 KB, because it links no model, glTF or audio code at all. The guest fault policy
defaults to log-and-continue.
