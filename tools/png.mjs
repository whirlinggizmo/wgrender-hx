// Just enough PNG to ask whether a screenshot has anything on it.
//
// A driver that only fails on console errors passes a build that renders nothing:
// a blank canvas is not an error. That happened -- a lifecycle bug wiped the frame
// callback and the run came back "ok" over a black screen. So the check is now "is
// there more than one colour", and answering it needs the pixels.
//
// Node ships zlib, which is the hard part; the rest is the IHDR, the concatenated
// IDAT and undoing the five per-scanline filters. No dependency, ~60 lines.
import { inflateSync } from "node:zlib";

const PAETH = (a, b, c) => {
    const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
};

/** { width, height, channels, data } with `data` the unfiltered rows, 8-bit. */
export function decodePng(buffer) {
    if (buffer.readUInt32BE(0) !== 0x89504e47) throw new Error("not a PNG");
    let at = 8, width = 0, height = 0, channels = 0, bitDepth = 0;
    const idat = [];
    while (at < buffer.length) {
        const length = buffer.readUInt32BE(at);
        const type = buffer.toString("ascii", at + 4, at + 8);
        const body = buffer.subarray(at + 8, at + 8 + length);
        if (type === "IHDR") {
            width = body.readUInt32BE(0);
            height = body.readUInt32BE(4);
            bitDepth = body[8];
            const colour = body[9];
            channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colour];
            if (bitDepth !== 8 || channels === undefined || colour === 3)
                throw new Error(`unsupported PNG: depth ${bitDepth}, colour type ${colour}`);
            if (body[12] !== 0) throw new Error("interlaced PNG");
        } else if (type === "IDAT") idat.push(body);
        else if (type === "IEND") break;
        at += 12 + length;
    }
    const raw = inflateSync(Buffer.concat(idat));
    const stride = width * channels;
    const out = Buffer.alloc(stride * height);
    for (let y = 0; y < height; y++) {
        const filter = raw[y * (stride + 1)];
        const src = y * (stride + 1) + 1;
        const dst = y * stride;
        const up = dst - stride;
        for (let x = 0; x < stride; x++) {
            const a = x >= channels ? out[dst + x - channels] : 0;
            const b = y > 0 ? out[up + x] : 0;
            const c = x >= channels && y > 0 ? out[up + x - channels] : 0;
            const v = raw[src + x];
            out[dst + x] = (filter === 0 ? v : filter === 1 ? v + a : filter === 2 ? v + b
                : filter === 3 ? v + ((a + b) >> 1) : v + PAETH(a, b, c)) & 0xff;
        }
    }
    return { width, height, channels, data: out };
}

/** How many distinct colours, stopping once `cap` is reached. Cheap "is it blank?". */
export function distinctColours(png, cap = 64) {
    const seen = new Set();
    const { data, channels, width, height } = png;
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const i = (y * width + x) * channels;
            seen.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
            if (seen.size >= cap) return seen.size;
        }
    }
    return seen.size;
}
