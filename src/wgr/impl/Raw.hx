package wgr.impl;

// Haxe picks Raw.js.hx or Raw.cpp.hx over this by target; this is what a third target
// would hit. Same pattern as librl's rl/impl/RLImpl.hx.
#error "wgr: no Raw implementation for this target. Add src/wgr/impl/Raw.<target>.hx."
