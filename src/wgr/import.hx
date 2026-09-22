// Haxe applies this to every module in this directory, so the public modules reach the
// C surface (and its struct and enum types) without each one repeating the import.
import wgr.impl.Raw;
// and the callback plumbing, which Event and Asset reach for on both targets
import wgr.impl.Trampoline;
