// The shared driver, in the wgrender-hx haxelib; this names the example.
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const lib = join(HERE, "../../.."); // examples/<name>/tools -> the library
process.argv.push(`--site=${resolve(join(HERE, "../out/web"))}`, "--label=textures");
await import(pathToFileURL(join(lib, "tools/drive.mjs")).href);
