#!/usr/bin/env node
// Startup timing for a wgrender web build, for sites wgrender's own tools/webstart.mjs
// can't point at (it resolves its site from examples/build/<backend> and needs an
// examples.json). Same idea, fewer options.
//
//   node tools/webstart.mjs --site=DIR [--site=DIR ...] [--net=local|4g|both] [--runs=N]
//
// Each site is opened in a fresh profile, served the way a host should
// (tools/serve.py --cache --gzip), and timed from navigation to libwgrender's own
// performance marks: wgr:init, wgr:subsystems, wgr:user-init, wgr:fs-ready,
// wgr:first-frame. Transferred bytes come from the resource timings.
//
// cold = fresh profile, nothing cached. warm = second visit in the same profile.
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const W = process.env.LIBWGR_ROOT ?? join(homedir(), "projects/github/whirlinggizmo/wgrender-c");
const { findBrowser, freePort, launchBrowser, openSession, RunProcesses, sleep, waitFor } =
    await import(pathToFileURL(join(W, "tools/weblib.mjs")).href);

const arg = (name, fallback) =>
    process.argv.find((a) => a.startsWith(`--${name}=`))?.split("=").slice(1).join("=") ?? fallback;
const sites = process.argv.filter((a) => a.startsWith("--site=")).map((a) => resolve(a.split("=")[1]));
const nets = { local: null, "4g": { offline: false, latency: 150, downloadThroughput: 9e6 / 8, uploadThroughput: 1.5e6 / 8 } };
const which = arg("net", "both") === "both" ? ["local", "4g"] : [arg("net", "both")];
const runs = Number(arg("runs", "3"));
const MARKS = ["wgr:init", "wgr:subsystems", "wgr:user-init", "wgr:fs-ready", "wgr:first-frame"];

if (!sites.length) { console.error("usage: webstart.mjs --site=DIR [--site=DIR]"); process.exit(2); }

async function visit(page, url, net) {
    await page.send("Network.enable");
    await page.send("Network.emulateNetworkConditions",
        net ? { offline: false, ...net } : { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
    await page.send("Page.navigate", { url });
    const deadline = Date.now() + 60000;
    for (;;) {
        const { result } = await page.send("Runtime.evaluate", {
            expression: `JSON.stringify({
                marks: performance.getEntriesByType("mark").map((m) => [m.name, m.startTime]),
                bytes: performance.getEntriesByType("resource")
                    .reduce((n, r) => n + (r.transferSize || 0), 0),
            })`, returnByValue: true, awaitPromise: false });
        const got = JSON.parse(result.value);
        if (got.marks.some(([n]) => n === "wgr:first-frame")) return got;
        if (Date.now() > deadline) return got;
        await sleep(100);
    }
}

const results = [];
for (const site of sites) {
    for (const netName of which) {
        const label = basename(dirname(dirname(site)));
        const run = new RunProcesses(`webstart-${label}`);
        try {
            const port = await freePort();
            run.spawn("python3", [join(W, "tools/serve.py"), String(port), site, "--cache", "--gzip"]);
            const entry = site.includes("simple-js") ? "wgrender-host.js" : "index.html";
            await waitFor(`http://127.0.0.1:${port}/${entry}`, "serve.py");
            const url = `http://127.0.0.1:${port}/`;
            for (let i = 0; i < runs; i++) {
                const { debugBase, browser } = await launchBrowser(run, findBrowser(process.env.WEBCHECK_BROWSER),
                    { display: "headless", backend: "webgl2", profile: `${run.profile}-${netName}-${i}` });
                const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
                const page = await openSession(`ws://${new URL(debugBase).host}/devtools/page/${targetId}`);
                await page.send("Runtime.enable");
                await page.send("Page.enable");
                const cold = await visit(page, url, nets[netName]);
                const warm = await visit(page, url, nets[netName]);
                results.push({ site: label, net: netName, run: i, cold, warm });
                await browser.send("Browser.close").catch(() => {});
                await sleep(300);
            }
        } finally { await run.stop(); }
    }
}

const at = (r, name) => (r.marks.find(([n]) => n === name) ?? [, null])[1];
const median = (xs) => { const s = xs.filter((x) => x != null).sort((a, b) => a - b); return s.length ? s[s.length >> 1] : null; };
const fmt = (v) => (v == null ? "    -" : `${v.toFixed(0).padStart(5)}`);

for (const visitKind of ["cold", "warm"]) {
    console.log(`\n=== ${visitKind} (ms to each mark, median of ${runs}) ===`);
    console.log(`${"site".padEnd(12)} ${"net".padEnd(6)} ${MARKS.map((m) => m.replace("wgr:", "").padStart(6)).join(" ")}   transferred`);
    for (const site of new Set(results.map((r) => r.site))) {
        for (const netName of which) {
            const rows = results.filter((r) => r.site === site && r.net === netName).map((r) => r[visitKind]);
            if (!rows.length) continue;
            const cells = MARKS.map((m) => fmt(median(rows.map((r) => at(r, m))))).join("  ");
            const bytes = median(rows.map((r) => r.bytes));
            console.log(`${site.padEnd(12)} ${netName.padEnd(6)} ${cells}   ${bytes ? bytes.toLocaleString() : "-"}`);
        }
    }
}
