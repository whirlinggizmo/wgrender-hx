# wgr.flat — the flat API, on trial

Statics taking the handle first, the way librl's bindings are shaped:

```haxe
Material.setRoughness(m, 0.35);      // wgr.flat
m.roughness = 0.35;                  // wgr
```

This package exists to be compared against `wgr`, not yet to replace it. It covers
only what `examples/flat` calls — enough of Material, Model, Scene, Light, Shape3D,
Camera3D, Mesh and Texture to draw one real scene. `examples/flat` is deliberately
outside `examples/build.py`'s suite, so the trial cannot break the 32 examples that
work.

## The rules it is testing

1. **Statics, handle first.** `Subsystem.verb(handle, ...)`, named after the C call it
   makes. The point is that the mapping *is* the name: `Material.setRoughness` says
   `wgr_material_set_*` and nothing has to infer it from a property's body. That is
   what `tools/setters.py` spends 364 lines doing today.

2. **`set*` returns `Bool`, straight from C.** wgrender-c has no error type — 177
   setters return `bool`, 7 return `void`, and there is no `wgr_result_t`. An error
   code here would be invented rather than reported, so there isn't one. When a call
   fails the C logs why (`resolve()` warns "Invalid model handle" and returns false);
   the `Bool` says *that* it failed, the log says *why*.

   The 7 `void` setters stay `Void`. `Scene.setActiveCamera` is one of them, and this
   slice includes it on purpose so the exception is visible rather than theoretical.

3. **Everything stays `inline`.** librl's passthrough is not inline and costs three
   real calls per operation. wgrender-hx's frame cost sits at the noise floor because
   these compile away, and that is not being traded for shape.

4. **Typed handle abstracts stay.** librl passes one untyped `RLHandle`; the typed
   abstracts here are free type safety, and flattening does not need them gone.

5. **`Handle.isNone(h)` as a free static.** `h == 0` and `h == Handle.NONE` are both
   wrong on js for a field never assigned — `undefined == 0` is false — and the
   abstract does not prevent that, since the 0 promotes at the typed abstract and an
   operator overload on `Handle` never sees the comparison. Flattening costs
   discoverability here, not correctness, as long as the free form keeps the same
   `undefined` tolerance.

## What the trial measured, 2026-09-22

`examples/flat` draws exactly the scene `examples/materials` draws, so the two files
diff cleanly and the numbers compare like for like.

**Size** — gzipped guest js, headless web build:

| | raw | gzipped |
| --- | --- | --- |
| `materials`, the sharp API | 20,788 | 4,660 |
| `flat`, the same scene | **19,975** | **4,531** |
| `flat`, plus its 34 `ok()` wrappers | 26,785 | 5,053 |

The flat shape is *smaller* — 813 bytes raw, 129 gzipped — because a property accessor
on an abstract generates slightly more than a static does. The third row is the
example's own instrumentation (34 call sites, each with a distinct string literal),
not a cost of the shape; it is listed so the middle row is not mistaken for a trick.

**Frame cost** — `tools/bench.mjs`, three runs each, `scriptMs` per frame:

| | run 1 | run 2 | run 3 | mean |
| --- | --- | --- | --- | --- |
| `materials` | 0.327 | 0.361 | 0.357 | 0.348 |
| `flat` | 0.340 | 0.320 | 0.370 | 0.343 |

Indistinguishable: the 0.005 ms gap is smaller than either row's own spread, and the
`flat` figures are the *instrumented* build. `inline` holds, which was the condition
attached to flattening in the first place.

**The audit** — `tools/setters.py --check` is unchanged and still passes (99
properties, 80 methods), because it only scans the sharp API. That is the point: in an
all-flat world it has nothing left to infer and reduces to its doc-comment check.

**Library checks** — `test/check.py`, 317/317 over 5 frames, untouched. `wgr.flat` is
purely additive; no existing file changed.

## What is still unmeasured

- **Readability over 52 call sites.** `Material.setRoughness(m, 0.35)` against
  `m.roughness = 0.35` is a judgement, not a number, and the two files exist to be read
  side by side. The worst case in this example is a read-modify-write:
  `Light.setEnabled(sun, !Light.isEnabled(sun))` against `sun.enabled = !sun.enabled`.
- **Discoverability.** `m.` lists a material's parameters in autocomplete;
  `Material.` lists them too, but only once you know the subsystem's name. Nobody has
  used this for long enough to say whether that matters.
- **The other 460 members.** This slice is 9 files. The per-member cost looked flat to
  write, but a slice chosen to fit one example is not a sample.

## What it already changes

`wgr.Material`'s property setters discard the `Bool` that `wgr_material_set_float` and
`wgr_material_set_texture` return:

```haxe
inline function set_roughness(v:Float):Float {
    setFloat("roughness", v);   // returns Bool. Dropped.
    return v;
}
```

Four float properties and five texture properties do this, so a refused parameter — a
dead handle, a name a custom shader does not declare — is invisible at the call site.
A property cannot do otherwise: Haxe requires a setter to return the assigned type.
The flat form returns what C returned, which is the whole of point 2.
