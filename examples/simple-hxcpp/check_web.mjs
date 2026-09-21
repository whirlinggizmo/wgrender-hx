#!/usr/bin/env node
// Web smoke check for a web build (out/web, or --site=DIR): serves it with wgrender's
// tools/serve.py, loads it in a headless Chromium-based browser through wgrender's
// tools/weblib.mjs, moves the mouse over the model, and fails on a console error,
// an uncaught exception or a wgrender [ERROR]/[FATAL] line. Saves build/web-check.png.
//
//   node check_web.mjs [--site=DIR] [--settle=MS]    (settle default 8000; LIBWGR_ROOT
//                                                     overrides wgrender)
import { writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const WGRENDER = process.env.LIBWGR_ROOT ?? join(homedir(), "projects/github/whirlinggizmo/wgrender-c");
const { findBrowser, freePort, launchBrowser, openSession, RunProcesses, sleep, waitFor } =
    await import(pathToFileURL(join(WGRENDER, "tools/weblib.mjs")).href);
const site = resolve(process.argv.find((a) => a.startsWith("--site="))?.split("=")[1] ?? join(HERE, "out/web"));
const settle = Number(process.argv.find((a) => a.startsWith("--settle="))?.split("=")[1] ?? 8000);

const run = new RunProcesses("haxe-simple");
const errors = [];
const lines = [];
try {
    const port = await freePort();
    run.spawn("python3", [join(WGRENDER, "tools/serve.py"), String(port), site]);
    const url = `http://127.0.0.1:${port}/`;
    await waitFor(`${url}examples.json`, "tools/serve.py");
    const { debugBase, browser } = await launchBrowser(run, findBrowser(process.env.WEBCHECK_BROWSER),
                                                       { display: "headless", backend: "webgl2" });
    const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
    const page = await openSession(`ws://${new URL(debugBase).host}/devtools/page/${targetId}`);
    page.onEvent((msg) => {
        if (msg.method === "Runtime.consoleAPICalled") {
            const text = msg.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
            lines.push(text);
            if (msg.params.type === "error" || /\[(ERROR|FATAL)/.test(text)) errors.push(text);
        } else if (msg.method === "Runtime.exceptionThrown") {
            const d = msg.params.exceptionDetails;
            errors.push(d.exception?.description ?? d.text);
        }
    });
    await page.send("Runtime.enable");
    await page.send("Page.enable");
    await page.send("Page.navigate", { url });
    await sleep(settle);
    // over the model: the middle of the canvas (below the page's 38px bar), a little low
    const { result } = await page.send("Runtime.evaluate", {
        expression: "(() => { const r = document.getElementById('canvas').getBoundingClientRect();" +
                    " return [r.left + r.width / 2, r.top + r.height / 2 + 20]; })()",
        returnByValue: true });
    const [x, y] = result.value;
    await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
    await sleep(1000);
    const shot = await page.send("Page.captureScreenshot", { format: "png" });
    const out = join(HERE, "build/web-check.png");
    writeFileSync(out, Buffer.from(shot.data, "base64"));
    for (const l of lines) console.log("  console:", l);
    console.log(`screenshot: ${out}`);
} finally {
    await run.stop();
}
if (errors.length) {
    console.error("FAILED:\n  " + errors.join("\n  "));
    process.exit(1);
}
console.log("ok");
process.exit(0);
