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
tools/gen_keys.py     regenerates wgr.Key from wgrender's wgr_keys.h
tools/gen_raw_js.py   regenerates the mechanical half of Raw.js.hx from Raw.cpp.hx
```

Every handle kind is an `abstract` over `Int` and every method is `inline`, so the API
layer compiles away: a call costs what the C call costs. The only allocations are the
small value objects (`Vec2`, `Vec3`, `MouseState`, `PickResult`) the wrappers return.

## The two shapes

An **all-in-one** app calls `Wgr.initValues` / `setInit` / `setFrame` / `run` and is
compiled into the binary (or the wasm) with wgrender. A **guest** app implements
`host/wgr_guest.h`'s four ops — `init`, `frame`, `asset`, `shutdown` — and the host
calls them; on js the host is a wasm module the page loads, on hxcpp it is linked in
and the Haxe program's `main` is the entry point.

Which one an app is decides which class survives DCE, which is why the `@:buildXml`
carrying the link configuration rides on both `wgr.Wgr` and `wgr.impl.GuestAbi`.

15 of the 42 API modules carry a target guard; the rest compile for both untouched.

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

A spike, not a release. It covers the slice of wgrender the `simple` example uses —
not 2D sprites and shapes, particles, materials, custom shaders, the environment,
events or gamepads. `KeyboardState` is unmarshalled on js. The guest fault policy
defaults to log-and-continue.
