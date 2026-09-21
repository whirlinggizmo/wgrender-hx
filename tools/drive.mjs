// Load out/web in a headless browser, run for a while, print the console.
import { writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const W = process.env.LIBWGR_ROOT ?? join(homedir(), "projects/github/whirlinggizmo/wgrender-c");
const { findBrowser, freePort, launchBrowser, openSession, RunProcesses, sleep, waitFor } =
    await import(pathToFileURL(join(W, "tools/weblib.mjs")).href);
const site = resolve(join(HERE, "../out/web"));
const settle = Number(process.argv.find((a) => a.startsWith("--settle="))?.split("=")[1] ?? 6000);
const run = new RunProcesses("simple-js");
const errors = [], lines = [];
try {
    const port = await freePort();
    run.spawn("python3", [join(W, "tools/serve.py"), String(port), site]);
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
    // over the model: middle of the canvas, a little low — exercises wgr_scene_pick,
    // whose wgr_pick_result_t comes back through the out-pointer.
    const { result } = await page.send("Runtime.evaluate", {
        expression: "(() => { const r = document.getElementById('canvas').getBoundingClientRect();" +
                    " return [r.left + r.width / 2, r.top + r.height / 2 + 20]; })()",
        returnByValue: true });
    const [mx, my] = result.value;
    await page.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: mx, y: my });
    await sleep(1000);
    const shot = await page.send("Page.captureScreenshot", { format: "png" });
    writeFileSync(join(site, "../check.png"), Buffer.from(shot.data, "base64"));
    for (const l of lines) console.log("  " + l);
    console.log(`screenshot: ${resolve(join(site, "../check.png"))}`);
} finally { await run.stop(); }
if (errors.length) { console.error("FAILED:\n  " + errors.join("\n  ")); process.exit(1); }
console.log("ok");
