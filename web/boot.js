// Load the host, hand it to the Haxe guest, and let the guest start it. The guest
// registers its ops before wgr_guest_start, so the host calls init on its own
// schedule rather than whenever the page happened to finish loading.
import createWgrHost from "./wgrender-host.js";
import "./guest.js"; // Haxe output; @:expose puts WgrGuest on the global

const canvas = document.getElementById("canvas");
const host = await createWgrHost({ canvas, print: (t) => console.log(t), printErr: (t) => console.log(t) });
globalThis.WgrGuest.start(host);
console.log("STARTED");
