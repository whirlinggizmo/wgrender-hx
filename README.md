# simple — wgrender in Haxe

A port of wgrender's `examples/simple.c` to Haxe, alongside the same example in
[Nim](../../nim/simple) and [Beef](../../beef/simple). Same scene in all four: an
animated model, a bobbing 3D sprite, looping music, two TTF fonts, a centred message
that reports what the mouse is over (scene picking), and a debug overlay with timers,
mouse state and the platform name.

It exists to answer two questions: what do idiomatic wgrender bindings look like in
Haxe, and what does Haxe cost in wasm.

## Build

```sh
./build.py desktop     # out/desktop/simple
./build.py web         # out/web/ (simple.js + simple.wasm + wgrender's page shell)
./build.py all
./build.py serve       # http://localhost:8000/
./build.py check       # compile the whole binding surface, not just what Simple.hx uses
./build.py compare     # this port's wasm next to the C, Nim and Beef ones
./build.py clean
node check_web.mjs     # headless-browser smoke test of out/web; writes build/web-check.png
```

`./build.py` builds wgrender first, then writes `build/<target>.hxml` and
`build/<target>.xml` — where wgrender is on this machine and how to compile and link
against it — and calls `haxe build.hxml` / `haxe web.hxml`. After that, running those
hxml files directly works too; they just won't rebuild wgrender.

Web options are wgrender's own make variables, read from the environment
(`BACKEND=webgl2|webgpu`, `WEB_DEBUG=0|1`). `WGRENDER_DIR` overrides where wgrender
is. Web builds are always `WEB_THREADS=0`: hxcpp's emscripten target is
single-threaded, so its objects carry no atomics and can't link into shared memory.

Needs Haxe 4.3, hxcpp, and Emscripten with `EMSDK` set.

## The route to wasm

Haxe has no wasm backend. The comparable path — and the one this uses — is the same
AOT route Nim and Beef take: **Haxe → hxcpp (C++) → Emscripten → wasm**, driven by
hxcpp's `emscripten` toolchain (`-D emscripten`). Haxe's other web target — plain JS
calling wgrender's Emscripten module through JS externs — is a different shape of
binding and is not what this measures, but it is the cheaper way to ship: see "The
other route" below.

## Size

`./build.py compare`, all linked against the same wgrender web library
(`BACKEND=webgl2 WEB_THREADS=0`, release):

| port                   |       wasm |   gzipped |  vs C |        js |  gzipped |
|------------------------|-----------:|----------:|------:|----------:|---------:|
| C (wgrender's example) |    690,116 |   292,002 | 1.00x |    64,910 |   23,186 |
| Nim                    |    713,584 |   301,782 | 1.03x |    65,138 |   23,280 |
| Beef                   |    846,131 |   368,843 | 1.23x |    66,674 |   23,985 |
| Haxe (this)            |  1,674,379 |   454,053 | 2.43x |    69,587 |   25,048 |

Roughly a megabyte of wasm over C, 162 KB of it after gzip. Almost all of it is the
hxcpp runtime rather than anything this example does: a Haxe hello-world through the
same toolchain is already 677 KB of wasm on its own — hxcpp ships a mark/sweep GC
(with binaryen's `--spill-pointers` so it can scan the wasm stack), reference-counted
UTF-16-aware strings, `Dynamic`, and class reflection tables, and `-dce full` only
removes what it can prove unreachable. Nim's ARC and Beef's arena/ownership model have
far less to carry into the binary.

The JS glue is the same size everywhere, because it's almost entirely Emscripten's.

Two caveats on the table. `./build.py compare` reads whatever each sibling project
last built, so the Nim row shows 726,858 / 307,166 unless it was built with
`WEB_THREADS=0` (its default is threads); the number above is the non-threaded build,
so it lines up with the rest. And the Haxe link needs one extra flag that the others
don't — see "Two things that needed working around" below.

## The other route: Haxe → JS

There is a second way to put Haxe on the web, and it avoids most of the cost above:
compile Haxe to **JS** and leave wgrender a separate Emscripten module that the JS
calls from the outside, rather than compiling Haxe *into* the wasm. The wasm then
contains only wgrender — the C row, ~690 KB — and the Haxe side is a JS file. It is
not what the table above measures, because it doesn't put Haxe in the wasm at all;
it's a different architecture, not a different flag.

The Haxe side costs almost nothing. The same small program (a `Map`, formatted
output, `Math.sin`) through each language's JS backend at release settings:

| backend                     |    bytes | gzipped |
|-----------------------------|---------:|--------:|
| Haxe → JS (`-dce full`)     |      951 |     480 |
| Nim → JS (`-d:release`)     |   49,312 |   9,100 |

Note the inversion: Haxe maps onto native JS types and carries essentially no runtime,
where Nim's JS backend brings a real one — the opposite of the wasm ranking, where Nim
is 1.03x C and Haxe is 2.43x. Both are noise against 690 KB of wasm, so it doesn't
change the outcome, but it's worth knowing which way round it goes.

### What the boundary actually costs

The obvious worry is JS↔wasm crossings. Measured (emcc 5.0.7 `-O3`, node 22, 5M
iterations warmed, on the shapes wgrender's API actually uses):

| crossing                                            | ns/call |
|-----------------------------------------------------|--------:|
| plain call, handle + 3 floats                        |     3.5 |
| plain call, handle + 9 floats (`set_transform`)      |     3.1 |
| `vec2_t` return via sret + heap read                 |     2.4 |
| `wgr_pick_result_t` return + 8-field heap read       |     4.6 |
| **JS string → UTF-8 on the wasm stack → call**       | **104.5** |

The crossing itself is ~3 ns and barely notices arity. Strings are 30x that, and are
the only shape that costs anything.

This example's frame path is 15 wasm calls — 6 plain, 3 returning structs, 6 carrying
text — so about **660 ns per frame, 0.004% of a 16.6 ms budget**. It would take
~47,000 plain calls per frame, or ~1,600 string calls, to lose 1% of frame time.

Two properties of wgrender make that hold, and both are deliberate (see its AGENTS.md).
The scene is retained-mode, so `wgr_scene_draw` is one call whether it draws 3 objects
or 30,000 — you pay per object you *mutate* each frame, not per object drawn; even
`spritebench`'s shape, 5,000 sprites each re-transformed every frame, is ~17 µs, about
0.1% of a frame. And the rule that every parameter is a handle, a scalar or a
`const char*` means there is nothing to marshal on the non-string calls, which is why
they are 3 ns.

So the realistic risk isn't geometry, it's **text** — a UI drawing a few hundred
dynamic strings a frame. That's cacheable: hold the encoded pointer while the string
is unchanged. (Only the JS→wasm direction was measured. The other way,
`addFunction` for the frame and asset callbacks, is once a frame plus a handful at
startup.)

### What it would cost to build

- wgrender has no `bindings/` directory and no `MODULARIZE` / `EXPORT_NAME` /
  `EXPORTED_FUNCTIONS` / `ALLOW_TABLE_GROWTH` in its build. That comes first; librl's
  equivalent is `bindings/js/dist/rl.js`, 2,277 lines.
- Five calls return structs by value (`wgr_scene_pick`, `wgr_input_get_mouse_state`,
  `wgr_input_get_keyboard_state`, `wgr_window_get_screen_size`, `wgr_text_measure_ex`).
  Under the wasm C ABI those come back through a hidden out-pointer, so JS allocates
  scratch and reads the fields out of the heap — what librl's binding calls its
  "scratch-backed helpers".
- It's a *second* web backend, not a route to native: hxcpp already gives this project
  a desktop build. The recurring cost is keeping two implementations in step, which is
  why librl's Haxe binding is a flat façade — a flat surface is much easier to write
  twice (`RLImpl.cpp.hx` 1,848 lines, `RLImpl.js.hx` 1,537).

The two-layer split here means it wouldn't be a second binding, though: only **38 of
the 807 hand-written lines** in `wgr/Wgr.hx` are C++-specific, clustered in `Native`
(10), `Asset`'s callback plumbing (5), `Wgr`'s trampolines (4), the five enum casts
(10) and the struct converters (4). The handle abstracts, properties, enums and flags
are all target-neutral. A JS port is a `Raw.js.hx` plus conditionals in those 38 lines.

## The bindings

`src/wgr/` is in two layers, the same split the Nim port uses:

- **`wgr/Raw.hx`** — the C API as is: C names, C types, declared with `@:include("wgr.h")`
  so the C++ compiler checks every prototype and struct layout. A wrong argument type
  or a stale struct field is a compile error, not a crash.
- **`wgr/Wgr.hx`** — the layer you actually write against.

The design goal was that the whole wrapper compile away. Every handle type is an
`abstract` over `Int`, every method is `inline`, so a call costs exactly what the C
call costs; the only allocations are the small value objects (`Vec2`, `Vec3`,
`MouseState`, `PickResult`) the wrappers hand back.

What that buys, compared with a flat C-shaped façade:

```haxe
// one abstract per handle kind, carrying that kind's methods — a Mesh where a
// Texture belongs is a compile error, and properties stand in for C's setters
final mesh = Mesh.create(path);
model = new Model(mesh);     // wgrender's rule: object from resource, resource from path
mesh.release();              // the model holds its own reference
model.animationLoop = true;
model.tint = Color.RAYWHITE;
model.setTransform(new Vec3(0, 0, 0));
scene.add(model);            // takes a Model, Sprite3D or Light, and nothing else

// closures, not function pointers plus a void*
Asset.ensureAsync(path).then(path -> { ... }, path -> Log.error('failed: $path'));

// the pick result's untyped handle still compares against typed ones
if (pick.handle == model) ...
```

Enums are `enum abstract`s over `Int`; window and asset flags are or-able
(`Msaa4x | Resizable`). The `Key` table is generated from wgrender's `wgr_keys.h` by
`tools/gen_keys.py`, and carries `static_assert`s that fail the C++ build if the
header's numbers ever move — the same guard the Nim port uses.

`test/CheckBindings.hx` (`./build.py check`) touches every wrapper, so the parts
`Simple.hx` doesn't use keep compiling against wgrender's headers.

It is the longest of the three bindings, at 807 hand-written lines against Nim's 342
and Beef's 187 (each excluding its generated key table). Beef is short because it
stops at the raw C surface; Nim and this one both wrap it, and Nim does the same job
in less than half the lines. Most of the gap is per-handle boilerplate: Nim gets a
typed handle from one `distinct Handle` line and shares `isNone` and `==` across all
of them with a typeclass, where each Haxe `abstract` has to restate `isNone`, its
conversion to the raw C type, and one named function per property setter.

### Compared with the older librl Haxe binding

`librl/bindings/haxe` is a flat façade — `Model.setTransform(handle, 9 floats)` with a
single untyped `RLHandle` for everything. This one follows the Nim binding instead: a
distinct type per handle kind, methods and properties on it, and vectors grouped into
values. Nothing here depends on that choice; it's the part worth comparing.

## Two things that needed working around

**C++ is stricter than C about enums.** wgrender's headers take real enum types
(`wgr_keycode_t`, `wgr_light_type_t`, ...), and C++ won't take an `int` there — which
C, and so the Nim port, will. Each Haxe enum carries a `@:to` that emits the cast, so
the call sites stay clean (`wgr.Wgr`, search for `toRaw`).

**The web link needs the wasm stack ops exported.** wgrender's `EM_JS` glue makes
Emscripten's JS `$stackSave`/`$stackRestore` live, but under hxcpp's
`-fwasm-exceptions` nothing native references the wasm stack operations, so emcc
leaves them out of the link and it fails on `emscripten_stack_get_current` /
`_emscripten_stack_restore`. `build.py` adds
`-sEXPORTED_FUNCTIONS=_main,_emscripten_stack_get_current,__emscripten_stack_restore`,
which pulls them back in. The C, Nim and Beef builds don't hit this: without wasm
exceptions the legacy exception glue references those symbols natively.

## Layout

```
build.hxml  web.hxml  check.hxml   haxe invocations (build.py writes build/*.hxml first)
build.py                           builds wgrender, then haxe; serve / compare / clean
check_web.mjs                      headless-browser smoke test of out/web
src/Simple.hx                      the example
src/Defines.hx                     reads a -D name=value define's value (needs a macro)
src/wgr/Wgr.hx                     the binding
src/wgr/Raw.hx                     the C API as is
test/CheckBindings.hx              compile-check of the whole binding surface
tools/gen_keys.py                  regenerates the Key table from wgrender's wgr_keys.h
```
