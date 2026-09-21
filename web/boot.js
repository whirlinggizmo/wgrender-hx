// Load the host, install the guest's ops, then start it. Registering before
// wgr_guest_start is the point: the host calls init on the guest's first frame.
import createWgrHost from "./wgrender-host.js";
import { makeGuest } from "./guest.js";

const canvas = document.getElementById("canvas");
const host = await createWgrHost({ canvas, print: (t) => console.log(t), printErr: (t) => console.log(t) });
const guest = makeGuest(host);

// Ops are JS functions turned into C function pointers. Each catches at its own edge
// and returns nonzero, because a throw that escapes into the host's C frames freezes
// the page with an opaque WebAssembly.Exception.
const op = (fn, sig) => host.addFunction((...a) => {
    try { fn(...a); return 0; } catch (e) { console.error("guest fault:", e); return 1; }
}, sig);

host._wgr_guest_register(op(guest.init, "i"), op(guest.frame, "ifi"), op(guest.asset, "iiii"), 0);
host._wgr_guest_start(1024, 1280, guest.cstr("simple (wgrender host, JS guest)"), 0x20 | 0x04);
console.log("STARTED");
