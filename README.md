# wgrender-hx

Haxe bindings for [wgrender](https://github.com/whirlinggizmo/wgrender-c), over two
targets from one API:

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
test/                 the binding's own suite: 317 assertions against headless wgrender
examples/             hello3d, particles, simple (guest) and simple-hxcpp (all-in-one)
project/              how an installed copy links wgrender, and the submodule it uses
Run.hx                `haxelib run wgrender-hx setup`

tools/gen_raw.py      writes BOTH impl/Raw.*.hx whole, from wgrender's include/*.h
tools/gen_keys.py     regenerates wgr.Key from wgrender's wgr_keys.h
tools/coverage.py     what the binding reaches, and what wrapping next buys
tools/setters.py      whether a refusal wgrender documents is repeated in these docs
tools/guestbuild.py   the host/guest build, shared by every example
tools/compare.py      each example's size against wgrender's own C build of it
tools/bench.mjs       frame cost, in a headless browser
tools/drive.mjs       run a built example and fail on anything the console calls an error
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

A handful of the API modules carry a target guard; the rest compile for both
untouched.

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
haxelib git wgrender-hx https://github.com/whirlinggizmo/wgrender-hx
haxelib run wgrender-hx setup        # fetches wgrender and builds it
haxelib run wgrender-hx setup web    # and the Emscripten library, for wasm
```

then `-lib wgrender-hx`. wgrender rides along as a submodule under `project/lib` and
`project/Build.xml` tells hxcpp where its headers and library are, so there is nothing
to point at by hand. `setup` exists because wgrender is C: its own Makefile packs the
shaders and vendors sokol, and restating that here would be a second build to keep in
step with the first.

Working on the binding itself instead:

```sh
haxelib dev wgrender-hx /path/to/wgrender-hx
```

and pass `-D WGR_BUILD_XML=<file>`, an hxcpp build-tool XML naming whichever wgrender
you are working against. That define is also the switch: set, it wins; unset, the
vendored one is used. `tools/guestbuild.py` generates one, and every example goes
through it.

### The examples

```sh
examples/build.py all      build each one, web and native
examples/build.py drive    run each web build in a headless browser
examples/build.py site     collect them under one page
examples/build.py compare  sizes against wgrender's own C build of each
test/check.py              the binding's 317 assertions
```

[`hello3d`](examples/hello3d) is the smallest and loads nothing;
[`particles`](examples/particles) and [`simple`](examples/simple) are the fuller ones;
[`simple-hxcpp`](examples/simple-hxcpp) is the same scene built the other way, for the
size comparison against the C, Nim and Beef ports.

## Status

`wgr.impl.Raw` covers all 480 of wgrender's calls on hxcpp and 470 on js; the
hand-written API layer above it wraps 478. All 33 of wgrender's C examples could be
written against it without a gap.

The two it leaves alone are a decision, not a backlog: `wgr_text_draw_n` and
`wgr_text_measure_n` take a length in *bytes*, and a Haxe string measures in UTF-16
units, so the two disagree for anything non-ASCII — passing a substring to `draw()` is
correct and these would not be. `tools/coverage.py --check` fails if either is ever
wrapped after all, so a decision and a to-do stay distinguishable. It holds the js
omissions the same way: eleven calls that take a C function pointer or a `void *`,
which the guest ABI replaces there.

`tools/setters.py` guards the other direction. wgrender's headers name every value a
setter refuses, and this fails the build when one of those sentences is not repeated
in the binding's docs — the link that broke once already, when a header's "capped at
65536" was copied into a doc comment and the API shape followed the doc rather than
the code.

### Against the C

Same wgrender, same backend, same threading, so the only difference is the language:

| example | C | Haxe | vs C | gzipped | guest js |
|---|---|---|---|---|---|
| hello3d | 301,866 | 312,357 | 1.03x | **1.02x** | 8,954 |
| particles | 473,289 | 494,452 | 1.04x | **1.01x** | 21,996 |
| simple | 757,457 | 779,052 | 1.03x | **1.01x** | 21,686 |

The wasm is the same wgrender either way; the difference is the guest JS. Frame cost
differs by about 0.07 ms of script time on `simple`, against a 16.7 ms budget —
measured with `tools/bench.mjs`, which reads Chrome's CPU accounting because the frame
interval alone is capped at the display rate and reads 16.66 ms on both sides whatever
is happening inside it.

For contrast, the same scene compiled all-in-one through hxcpp is 1.69 MB of wasm,
2.3x the C. Keeping the Haxe runtime out of the binary is what the guest shape buys.

## Regenerating the C surface

`tools/gen_raw.py` reads wgrender's `include/*.h` and writes **both** `impl/Raw.cpp.hx`
and `impl/Raw.js.hx` whole — neither is ever patched, so the answer to an API change is
to run it and read what it says:

```
$ tools/gen_raw.py
wgrender-c: 480 functions, 18 enums, 12 structs
  Raw.cpp.hx  478 externs
  Raw.js.hx   467 wrappers
```

**hxcpp reaches every one of wgrender's public functions.** On js it reaches all but
ten, and those ten take a C function pointer or a `void *`, which the guest ABI
replaces there.

`wgr_input_get_keyboard_state` used to be an eleventh. Its struct is 2,324 bytes — 512
ints of key state plus the keys and characters a frame produced — and the generator's
only shape for a returned struct was to read every field and build the Haxe class,
which means marshalling 581 ints to answer one question about one key. So it learned a
second shape: a struct listed in `OPAQUE` comes back to js as a pointer into the wasm
heap, with the field offsets emitted beside it, and `keys[Escape]` is one `HEAP32`
index. On hxcpp it still wraps the struct, so the two targets differ by a line per
accessor and the public API is identical.

The tool derives the enum cast types, the struct externs and the struct-return heap
reads from the headers. It needs help for four things, declared in its `SPEC` rather
than edited into its output: which C callback typedefs map to which Haxe function
type, which returned structs map to which public value class (whose constructor must
take the C fields in order), which are too big to copy and come back as a heap
pointer, and which functions to skip. Anything it can't map is
left out and **listed**, so a gap is reported rather than silent. Today the only entry
is the two varargs loggers, which it re-adds at fixed arity from `MANUAL`.

Because the binding now declares wgrender's whole API, an app's build derives the
host's `EXPORTED_FUNCTIONS` from the calls its *compiled guest* makes rather than from
the binding — Emscripten cannot strip what is exported, and exporting everything cost
75 KB. The `hello3d` example exports 25 and its host wasm is 242 KB against `simple`'s
689 KB, because it links no model, glTF, audio or particle code at all. The guest fault policy
defaults to log-and-continue.
