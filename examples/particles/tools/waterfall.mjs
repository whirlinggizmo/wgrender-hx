#!/usr/bin/env node
// Per-resource timings for one cold visit on emulated 4G — which requests happen when,
// and what depends on what.
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
const W = process.env.LIBWGR_ROOT ?? join(homedir(), "projects/github/whirlinggizmo/wgrender-c");
const { findBrowser, freePort, launchBrowser, openSession, RunProcesses, sleep, waitFor } =
    await import(pathToFileURL(join(W, "tools/weblib.mjs")).href);
const site = resolve(process.argv[2]);
const label = basename(dirname(dirname(site)));
const run = new RunProcesses(`waterfall-${label}`);
try {
    const port = await freePort();
    run.spawn("python3", [join(W, "tools/serve.py"), String(port), site, "--cache", "--gzip"]);
    await waitFor(`http://127.0.0.1:${port}/index.html`, "serve.py");
    const { debugBase, browser } = await launchBrowser(run, findBrowser(process.env.WEBCHECK_BROWSER),
        { display: "headless", backend: "webgl2" });
    const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
    const page = await openSession(`ws://${new URL(debugBase).host}/devtools/page/${targetId}`);
    await page.send("Runtime.enable"); await page.send("Page.enable"); await page.send("Network.enable");
    await page.send("Network.emulateNetworkConditions",
        { offline: false, latency: 150, downloadThroughput: 9e6 / 8, uploadThroughput: 1.5e6 / 8 });
    await page.send("Page.navigate", { url: `http://127.0.0.1:${port}/` });
    await sleep(12000);
    const { result } = await page.send("Runtime.evaluate", { returnByValue: true, expression: `JSON.stringify(
        performance.getEntriesByType("resource")
          .filter(r => !/\\/wgr\\//.test(r.name))
          .map(r => [r.name.split("/").pop(), Math.round(r.startTime), Math.round(r.responseEnd), r.transferSize])
          .sort((a,b) => a[1]-b[1]))` });
    console.log(`=== ${label} — cold, 4G ===`);
    console.log("  resource                start     end   bytes");
    for (const [name, start, end, bytes] of JSON.parse(result.value))
        console.log(`  ${name.padEnd(22)} ${String(start).padStart(5)}   ${String(end).padStart(5)}   ${bytes.toLocaleString().padStart(8)}`);
    const { result: marks } = await page.send("Runtime.evaluate", { returnByValue: true,
        expression: `JSON.stringify(performance.getEntriesByType("mark").map(m => [m.name, Math.round(m.startTime)]))` });
    console.log("  marks:", JSON.parse(marks.value).map(([n, t]) => `${n.replace("wgr:", "")}=${t}`).join(" "));
} finally { await run.stop(); }
