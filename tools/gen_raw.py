#!/usr/bin/env python3
"""Generate the whole C surface — src/wgr/impl/Raw.cpp.hx and Raw.js.hx — from
wgrender's public headers.

    tools/gen_raw.py [WGRENDER_DIR]        (default: ../wgrender-c, or $WGRENDER_DIR)

Both files are written whole; neither is ever patched. Run it when wgrender's API
moves, read what it reports, and rebuild.

It reads `include/*.h` for functions, enums and structs, and needs help for exactly
three things, all declared in SPEC below rather than edited into the output:

  callbacks   a C function-pointer parameter has no shape the parser can infer
  values      a struct returned by value maps to a Haxe class in the public layer,
              whose constructor is expected to take the C fields in order
  skips       varargs, and anything else with no sane rendering

Everything else is mechanical. Functions whose types it cannot map are left out and
listed at the end, so the gap is reported rather than silent.
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WGRENDER = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                        else os.environ.get('WGRENDER_DIR', ROOT / '../wgrender-c')).resolve()
OUT = ROOT / 'src/wgr/impl'

# ---------------------------------------------------------------- the spec ---

# C callback typedefs: the Haxe function type, and whether the JS layer can offer it.
# The guest ABI (host/wgr_guest.h) replaces every one of these on js, so none can.
CALLBACKS = {
    'wgr_lifecycle_fn': '(user:VoidStar) -> Void',
    'wgr_frame_fn': '(dt:Single, tickFraction:Single, user:VoidStar) -> Void',
    'wgr_tick_fn': '(dt:Single, user:VoidStar) -> Void',
    'wgr_asset_callback_fn': '(path:ConstCharStar, user:VoidStar) -> Void',
    'wgr_event_callback_fn': '(event:VoidStar, user:VoidStar) -> Void',
    'wgr_event_listener_fn': '(payload:VoidStar, user:VoidStar) -> Void',
    'wgr_asset_fetch_fn': '(request:WgrHandle, url:ConstCharStar, destPath:ConstCharStar, user:VoidStar) -> Void',
    'wgr_asset_ping_fn': '(host:ConstCharStar, milliseconds:Single, user:VoidStar) -> Void',
}

# Structs returned by value, and the public-layer class the JS side builds from them.
# The constructor must take the C fields in order — that is what makes the read
# generatable rather than hand-written.
OPAQUE = {'wgr_keyboard_state_t'}

VALUES = {
    'vec2_t': 'Vec2',
    'vec3_t': 'Vec3',
    'wgr_mouse_state_t': 'MouseState',
    'wgr_pick_result_t': 'PickResult',
    'wgr_touch_t': 'Touch',
    'wgr_touch_gesture_t': 'TouchGesture',
    'wgr_pick_stats_t': 'PickStats',
}

# No sane rendering: varargs, or a pointer the public API rule says should not exist.
SKIP = {
    'wgr_logger_message', 'wgr_logger_message_source',  # varargs — re-added in MANUAL
}

# Declarations the parser can't produce, rendered verbatim. Keep this short: anything
# here is a thing the generator does not know, and every entry is a thing to re-check
# when wgrender's API moves.
MANUAL_CPP = '''
	/** The varargs logger, fixed at one `%s` — enough for a Haxe string. **/
	@:native("wgr_logger_message")
	static function wgr_logger_message(level:CLogLevel, format:ConstCharStar, text:ConstCharStar):Void;

	/** The same, with the call site the WGR_LOG_* macros would have filled in. **/
	@:native("wgr_logger_message_source")
	static function wgr_logger_message_source(level:CLogLevel, sourceFile:ConstCharStar, sourceLine:Int,
		format:ConstCharStar, text:ConstCharStar):Void;'''

MANUAL_JS = '''
	/** The varargs logger, fixed at one `%s` — enough for a Haxe string. **/
	public static inline function wgr_logger_message(level:Int, format:String, text:String):Void
		Raw.host._wgr_logger_message(level, cstr(format), cstr(text));

	/** The same, with the call site the WGR_LOG_* macros would have filled in. **/
	public static inline function wgr_logger_message_source(level:Int, sourceFile:String, sourceLine:Int,
			format:String, text:String):Void
		Raw.host._wgr_logger_message_source(level, cstr(sourceFile), sourceLine, cstr(format), cstr(text));'''

SCALARS = {  # C type -> (hxcpp, js), size, how JS reads it out of the heap
    'void': ('Void', 'Void', 0, None),
    'bool': ('Bool', 'Bool', 4, 'HEAPU8:1'),
    'int': ('Int', 'Int', 4, 'HEAP32:4'),
    'unsigned int': ('UInt32', 'Int', 4, 'HEAPU32:4'),
    'unsigned': ('UInt32', 'Int', 4, 'HEAPU32:4'),
    'float': ('Single', 'Float', 4, 'HEAPF32:4'),
    'double': ('Float', 'Float', 8, None),
    'wgr_handle_t': ('WgrHandle', 'Int', 4, 'HEAPU32:4'),
    'wgr_color_t': ('WgrColor', 'Int', 4, 'HEAPU32:4'),
    'const char *': ('ConstCharStar', 'String', 4, None),
    'char *': ('ConstCharStar', 'String', 4, None),
    # the opaque user pointer: hxcpp passes it, js never needs to (the guest ABI
    # carries an id instead), so it has no JS mapping and those calls drop out there.
    'void *': ('VoidStar', None, 4, None),
}

# ------------------------------------------------------------- the headers ---


def read_headers():
    text = {h.name: h.read_text() for h in sorted((WGRENDER / 'include').glob('*.h'))}
    if not text:
        sys.exit(f'no headers under {WGRENDER}/include')
    everything = '\n'.join(text.values())
    enums = set(re.findall(r'\}\s*(wgr_\w+_t)\s*;', everything)) - set(re.findall(r'typedef struct[^{]*\{[^}]*\}\s*(\w+)\s*;', everything, re.S))
    structs = {}
    for m in re.finditer(r'typedef struct[^{]*\{(.*?)\}\s*(\w+)\s*;', everything, re.S):
        body, name = m.group(1), m.group(2)
        # Strip comments across the whole body: a trailing /* ... */ can run onto the
        # next line, and stripping line by line then swallows the field it follows.
        body = re.sub(r'/\*.*?\*/', ' ', body, flags=re.S)
        body = re.sub(r'//[^\n]*', ' ', body)
        fields = []
        for line in body.split('\n'):
            line = line.strip()
            fm = re.match(r'^((?:unsigned |const )?[\w]+(?:\s*\*)?)\s+(.+);$', line)
            if not fm:
                continue
            ctype = fm.group(1).strip()
            # one line can declare several: `float x, y;`
            for declarator in fm.group(2).split(','):
                dm = re.match(r'^\s*(\w+)\s*(?:\[\s*(\w+)\s*\])?\s*$', declarator)
                if not dm:
                    continue
                bound = dm.group(2)
                # `int keys[WGR_MAX_KEYS]` — a macro bound is still an array, just one
                # whose size we can't compute, which is fine for a struct we only pass.
                count = int(bound) if bound and bound.isdigit() else (-1 if bound else 0)
                fields.append((ctype, dm.group(1), count))
        if fields:
            structs[name] = fields
    functions = []
    for header, body in text.items():
        for m in re.finditer(r'^((?:const\s+)?(?:unsigned\s+)?[\w]+)\s*(\*?)\s*(wgr_\w+)\s*\(([^;]*?)\)\s*;',
                             body, re.M):
            ret = ' '.join(m.group(1).split()) + (' *' if m.group(2) else '')
            name, params = m.group(3), ' '.join(m.group(4).split())
            functions.append((header, ret, name, params))
    return enums, structs, functions


def parse_params(params):
    params = re.sub(r'/\*.*?\*/', ' ', params).strip()  # `float rz, /* radians */ float sx`
    params = ' '.join(params.split())
    if params in ('void', ''):
        return []
    out = []
    for part in re.split(r',(?![^()]*\))', params):
        part = part.strip()
        # `const char *path` binds the star to the name, so take it either way
        pm = re.match(r'^((?:const\s+)?(?:unsigned\s+|signed\s+)?[\w]+)\s*(\*?)\s*(\w+)$', part)
        if not pm:
            return None  # a function pointer, an array, something unparsed
        ctype = ' '.join(pm.group(1).split()) + (' *' if pm.group(2) else '')
        out.append((ctype, pm.group(3)))
    return out


def layout(structs, name):
    """Field offsets in bytes, C rules — every member here is 4-aligned or a nest."""
    offsets, at = [], 0
    for ctype, field, count in structs[name]:
        if ctype in structs:
            size = layout(structs, ctype)[1] * max(count, 1)
            offsets.append((field, ctype, at, count))
        else:
            unit = SCALARS.get(ctype, (None, None, 4, None))[2]
            size = unit * max(count, 1)
            offsets.append((field, ctype, at, count))
        at += size
    return offsets, at


# ------------------------------------------------------------- the output ---

HEADER = """package wgr.impl;

// GENERATED by tools/gen_raw.py from wgrender's include/*.h — do not edit.
// Re-run the tool when wgrender's API moves; it writes this file whole.
"""


def hx(ctype, enums, side):
    """The Haxe type for a C type, or None if there isn't one."""
    if ctype in SCALARS:
        return SCALARS[ctype][0 if side == 'cpp' else 1]
    if ctype in enums:
        return ('C' + ''.join(p.title() for p in ctype[4:-2].split('_'))) if side == 'cpp' else 'Int'
    if ctype in CALLBACKS:
        return ''.join(p.title() for p in ctype[4:-3].split('_')) + 'Fn' if side == 'cpp' else None
    if ctype in VALUES or ctype in OPAQUE:
        name = 'C' + ''.join(p.title() for p in ctype.replace('wgr_', '').removesuffix('_t').split('_'))
        return name if side == 'cpp' else VALUES.get(ctype)
    return None


def emit_cpp(enums, structs, functions):
    used_enums, used_values, used_callbacks, body, skipped = set(), set(), set(), [], []
    for header, ret, name, params in functions:
        if name in SKIP:
            skipped.append((name, 'spec: skipped')); continue
        args = parse_params(params)
        if args is None:
            skipped.append((name, 'unparsed parameter list')); continue
        types = [ret] + [t for t, _ in args]
        bad = [t for t in types if hx(t, enums, 'cpp') is None]
        if bad:
            skipped.append((name, f'no mapping for {bad[0]}')); continue
        for t in types:
            (used_enums if t in enums else used_values if t in VALUES or t in OPAQUE
             else used_callbacks if t in CALLBACKS else set()).add(t)
        sig = ', '.join(f'{n}:{hx(t, enums, "cpp")}' for t, n in args)
        # C++ needs the enum type on the way in; on the way out it is a number, and an
        # opaque extern would be useless to the caller.
        hret = 'Int' if ret in enums else hx(ret, enums, 'cpp')
        body.append(f'\t@:native("{name}")\n\tstatic function {name}({sig}):{hret};')

    lines = [HEADER, 'import cpp.ConstCharStar;', 'import cpp.RawPointer;', 'import cpp.UInt32;', '',
             'typedef WgrHandle = UInt32;', 'typedef WgrColor = UInt32;', '',
             '/** C `void *`: the opaque user pointer every wgrender callback carries. **/',
             'typedef VoidStar = RawPointer<cpp.Void>;', '']
    for c in sorted(used_callbacks):
        lines.append(f'typedef {hx(c, enums, "cpp")} = cpp.Callable<{CALLBACKS[c]}>;')
    lines.append('')
    lines.append('// Structs the API returns by value. C++ takes them as values; the JS side reads')
    lines.append('// them out of the heap (see Raw.js.hx).')
    for s in sorted(used_values):
        fields = '\n'.join(
            f'\t/** C `{t}[{c if c > 0 else "N"}]`, so it reads as a pointer here; index it in place. **/\n'
            f'\tvar {f}:cpp.RawPointer<{hx(t, enums, "cpp")}>;' if c else
            f'\tvar {f}:{hx(t, enums, "cpp") or ("C" + t)};'
            for f, t, c in ((f, t, c) for f, t, _, c in layout(structs, s)[0]))
        lines.append(f'@:include("wgr.h") @:native("{s}") @:structAccess @:unreflective\n'
                     f'extern class {hx(s, enums, "cpp")} {{\n{fields}\n}}\n')
    lines.append('// C enum parameter types: C++ will not take an `int` where the header names an')
    lines.append('// enum, so wgr\'s enum abstracts cast to these (see their `toRaw`).')
    for e in sorted(used_enums):
        lines.append(f'@:include("wgr.h") @:native("{e}") @:structAccess @:unreflective\n'
                     f'extern class {hx(e, enums, "cpp")} {{}}\n')
    lines.append(
        "// Where wgrender is on this machine and how to link it: the app's build writes\n"
        "// that file and passes -D WGR_BUILD_XML. It rides here because every program\n"
        "// that touches wgrender at all reaches this class, so -dce full cannot strip it\n"
        "// out from under the build the way it can any class in the API layer.\n"
        '@:buildXml(\'<include name="${WGR_BUILD_XML}" />\')\n'
        '@:keep @:unreflective @:include("wgr.h")\nextern class Raw {')
    lines.append('\n'.join(body))
    lines.append(MANUAL_CPP)
    lines.append('}')
    (OUT / 'Raw.cpp.hx').write_text('\n'.join(lines) + '\n')
    return len(body), skipped


def emit_js(enums, structs, functions):
    body, skipped, values_used = [], [], set()
    for header, ret, name, params in functions:
        if name in SKIP:
            continue
        args = parse_params(params)
        if args is None:
            continue
        types = [ret] + [t for t, _ in args]
        if any(t in CALLBACKS for t in types):
            skipped.append((name, 'takes a C callback — the guest ABI replaces it on js'))
            continue
        if any(hx(t, enums, 'js') is None for t in types):
            continue
        sig = ', '.join(f'{n}:{hx(t, enums, "js")}' for t, n in args)
        call_args = ', '.join(f'cstr({n})' if t in ('const char *', 'char *') else n for t, n in args)
        if ret in VALUES:
            values_used.add(ret)
            fields, size = layout(structs, ret)
            reads, heaps = [], set()
            for field, ctype, at, count in fields:
                if ctype in structs and ctype not in SCALARS:
                    sub, _ = layout(structs, ctype)
                    heaps.add('HEAPF32')
                    reads.append(f'new {VALUES.get(ctype, "Vec3")}('
                                 + ', '.join(f'f32[base + {(at + o) // 4}]' for _, _, o, _ in sub) + ')')
                elif count:
                    heaps.add('HEAP32')
                    reads.append('[' + ', '.join(f'i32[base + {(at + i * 4) // 4}]' for i in range(count)) + ']')
                else:
                    heap, width = SCALARS[ctype][3].split(':')
                    heaps.add(heap)
                    if width == '1':
                        reads.append(f'u8[out + {at}] != 0')
                    else:
                        reads.append(f'{ {"HEAP32": "i32", "HEAPU32": "u32", "HEAPF32": "f32"}[heap] }[base + {at // 4}]')
            locals_ = '\n\t\t'.join(
                f'final {v} = Raw.host.{k};' for k, v in
                [('HEAP32', 'i32'), ('HEAPU32', 'u32'), ('HEAPF32', 'f32'), ('HEAPU8', 'u8')] if k in heaps)
            body.append(
                f'\tpublic static function {name}({sig}):{VALUES[ret]} {{\n'
                f'\t\tfinal out = scratch({size});\n'
                f'\t\tRaw.host._{name}(out{", " if call_args else ""}{call_args});\n'
                f'\t\t{locals_}\n\t\tfinal base = out >> 2;\n'
                f'\t\treturn new {VALUES[ret]}({", ".join(reads)});\n\t}}')
        else:
            call = f'Raw.host._{name}({call_args})'
            hret = hx(ret, enums, 'js')
            line = (f'\t\t{call};' if hret == 'Void'
                    else f'\t\treturn {call} != 0;' if hret == 'Bool'
                    else f'\t\treturn str({call});' if ret in ('const char *', 'char *')
                    else f'\t\treturn {call};')
            body.append(f'\tpublic static inline function {name}({sig}):'
                        f'{"String" if ret in ("const char *", "char *") else hret}\n{line}')
    return body, skipped, values_used


JS_PREAMBLE = '''
import wgr.Handle;
import wgr.MouseState;
import wgr.PickResult;
import wgr.Vec2;
import wgr.Vec3;

typedef WgrHandle = Int;
typedef WgrColor = Int;

/**
	The same C surface Raw.cpp.hx declares, reached through the host module's exports.

	Three rules this layer keeps, all of them measured hazards:

	- **Never hold a heap view.** The host links with `ALLOW_MEMORY_GROWTH`, so any
	  allocation detaches every `HEAPF32`/`HEAP32` JS holds. Every read goes through
	  `host.HEAPF32` at the point of use. Pointers survive growth; views do not.
	- **Scratch is an arena per op.** Strings and struct-return slots come from
	  `stackAlloc`, and the guest's op edge restores the stack pointer once when the op
	  ends, fault or not (`wgr.impl.GuestAbi`).
	- **Structs come back through a pointer.** The wasm C ABI returns anything larger
	  than a scalar through a hidden first argument, so these read the fields out of
	  the heap rather than getting a value.
**/
class Raw {
	/** The Emscripten module, handed over at boot. **/
	public static var host(default, null):Dynamic;

	public static function attach(module:Dynamic):Void {
		host = module;
	}

	/** Where the op arena started; `GuestAbi` restores to here when an op ends. **/
	public static inline function stackMark():Int
		return host.stackSave();

	public static inline function stackRelease(mark:Int):Void
		host.stackRestore(mark);

	/** A NUL-terminated copy of `s` in the op's arena. **/
	public static inline function cstr(s:String):Int {
		final length = host.lengthBytesUTF8(s) + 1;
		final pointer = host.stackAlloc(length);
		host.stringToUTF8(s, pointer, length);
		return pointer;
	}

	static inline function scratch(bytes:Int):Int
		return host.stackAlloc(bytes);

	public static inline function str(pointer:Int):String
		return host.UTF8ToString(pointer);

	/** The guest ABI's asset op, keyed by `id` — the guest never sees a callback. **/
	public static inline function wgr_guest_asset_load(path:String, id:Int):Bool
		return host._wgr_guest_asset_load(cstr(path), id) != 0;
'''


def main():
    enums, structs, functions = read_headers()
    print(f'{WGRENDER.name}: {len(functions)} functions, {len(enums)} enums, {len(structs)} structs')

    n_cpp, cpp_skipped = emit_cpp(enums, structs, functions)
    js_body, js_skipped, _ = emit_js(enums, structs, functions)
    (OUT / 'Raw.js.hx').write_text(HEADER + JS_PREAMBLE + '\n' + '\n\n'.join(js_body)
                                   + '\n' + MANUAL_JS + '\n}\n')

    print(f'  Raw.cpp.hx  {n_cpp} externs')
    print(f'  Raw.js.hx   {len(js_body)} wrappers')
    by_reason = {}
    for name, why in cpp_skipped:
        by_reason.setdefault(why, []).append(name)
    if by_reason:
        print('\nnot bound (hxcpp):')
        for why, names in sorted(by_reason.items(), key=lambda kv: -len(kv[1])):
            print(f'  {len(names):>3}  {why}')
            print(f'       {", ".join(sorted(names)[:4])}{" …" if len(names) > 4 else ""}')
    if js_skipped:
        print(f'\nhxcpp only ({len(js_skipped)}): the guest ABI replaces these on js')
        print(f'  {", ".join(sorted(n for n, _ in js_skipped))}')


if __name__ == '__main__':
    main()
