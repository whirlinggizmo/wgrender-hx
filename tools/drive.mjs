// Load an example's out/web in a headless browser, run it, and fail on anything the
// console calls an error. Shared by every host/guest example:
//
//   node <lib>/tools/drive.mjs --site=out/web [--label=NAME] [--settle=MS] [--click]
//
// Saves a screenshot beside the site directory, because three bugs in this port were
// visible there and invisible to every assertion: a canvas with no CSS size, a model
// drawn off screen, and a pivot taken as pixels instead of a fraction.
//
// And it now *reads* that screenshot, because "no console error" passed a build that
// rendered nothing at all: a lifecycle bug wiped the frame callback and this said ok
// over a black canvas. A screen of one colour is a failure whatever the console says.
// --min-colours=1 turns it off for an example that really is one flat colour.
import { existsSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const { decodePng, distinctColours } =
    await import(pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), "png.mjs")).href);

const arg = (name, fallback) =>
    process.argv.find((a) => a.startsWith(`--${name}=`))?.split("=").slice(1).join("=") ?? fallback;
const ROOT_HX = resolve(dirname(fileURLToPath(import.meta.url)), "..");
/* wgrender: LIBWGR_ROOT (examples/build.py passes the one tools/wgrpath.py finds), else
 * a wgrender-c checkout beside this repository, else the pinned submodule. */
const W = process.env.LIBWGR_ROOT ??
    [join(ROOT_HX, "../wgrender-c"), join(ROOT_HX, "project/lib/wgrender-c")].find((d) => existsSync(join(d, "include/wgr.h")));
if (!W) throw new Error("no wgrender: set LIBWGR_ROOT, or git submodule update --init");
const { findBrowser, freePort, launchBrowser, openSession, PYTHON, RunProcesses, sleep, waitFor } =
    await import(pathToFileURL(join(W, "tools/weblib.mjs")).href);

const site = resolve(arg("site", "out/web"));
const label = arg("label", "guest");
const settle = Number(arg("settle", 6000));
const click = process.argv.includes("--click");
const minColours = Number(arg("min-colours", 2));

const run = new RunProcesses(label);
const errors = [], lines = [];
try {
    const port = await freePort();
    run.spawn(PYTHON, [join(W, "tools/serve.py"), String(port), site]);
    await waitFor(`http://127.0.0.1:${port}/wgrender-host.js`, "serve.py");
    const { debugBase, browser } = await launchBrowser(run, findBrowser(process.env.WEBCHECK_BROWSER),
                                                       { display: "headless", backend: "webgl2" });
    const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
    const page = await openSession(`ws://${new URL(debugBase).host}/devtools/page/${targetId}`);
    page.onEvent((m) => {
        if (m.method === "Runtime.consoleAPICalled") {
            const t = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
            lines.push(t);
            if (m.params.type === "error" || /\[(ERROR|FATAL)/.test(t)) errors.push(t);
        } else if (m.method === "Runtime.exceptionThrown") {
            const d = m.params.exceptionDetails;
            errors.push("UNCAUGHT " + (d.exception?.description ?? d.text).split("\n")[0]);
        }
    });
    await page.send("Runtime.enable");
    await page.send("Page.enable");
    await page.send("Page.navigate", { url: `http://127.0.0.1:${port}/` });
    await sleep(settle);
    // the middle of the canvas, a little low: over whatever the example puts there,
    // which exercises picking and the hover state a scene keeps
    const { result } = await page.send("Runtime.evaluate", {
        expression: "(() => { const r = document.getElementById('canvas').getBoundingClientRect();" +
                    " return [r.left + r.width / 2, r.top + r.height / 2 + 20]; })()",
        returnByValue: true });
    const [mx, my] = result.value;
    await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: mx, y: my });
    if (click)
        for (const type of ["mousePressed", "mouseReleased"])
            await page.send("Input.dispatchMouseEvent",
                            { type, x: mx, y: my, button: "left", clickCount: 1 });
    await sleep(1000);
    const shot = await page.send("Page.captureScreenshot", { format: "png" });
    const out = resolve(join(site, "../check.png"));
    const pixels = Buffer.from(shot.data, "base64");
    writeFileSync(out, pixels);
    const colours = distinctColours(decodePng(pixels));
    if (colours < minColours)
        errors.push(`the screen is ${colours === 1 ? "one flat colour" : `only ${colours} colours`}`
                    + ` — nothing was drawn (${out})`);
    for (const l of lines) console.log("  " + l);
    console.log(`screenshot: ${out}`);
} finally { await run.stop(); }
if (errors.length) { console.error("FAILED:\n  " + errors.join("\n  ")); process.exit(1); }
console.log("ok");
