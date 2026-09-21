/** Reading a `-D name=value` define's *value* needs a macro in Haxe. **/
class Defines {
	public static macro function value(name:String, fallback:String):haxe.macro.Expr {
		final defined = haxe.macro.Context.definedValue(name);
		return macro $v{defined != null ? defined : fallback};
	}
}
