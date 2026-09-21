// The shared driver, in the wgrender-hx haxelib; this names the example. --click
// makes the 2D confetti emitter burst where the pointer is.
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const lib = process.env.WGRENDER_HX ??
    join(homedir(), "projects/github/whirlinggizmo/wgrender-hx");
process.argv.push(`--site=${resolve(join(HERE, "../out/web"))}`, "--label=particles", "--click");
await import(pathToFileURL(join(lib, "tools/drive.mjs")).href);
