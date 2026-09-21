// The shared driver, in the wgrender-hx haxelib; this names the example.
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const lib = process.env.WGRENDER_HX ?? join(homedir(), "projects/github/whirlinggizmo/wgrender-hx");
process.argv.push(`--site=${resolve(join(HERE, "../out/web"))}`, "--label=hello3d");
await import(pathToFileURL(join(lib, "tools/drive.mjs")).href);
