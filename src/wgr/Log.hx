package wgr;

// wgr_logger.h

class Log {
	public static inline function setLevel(level:LogLevel):Void
		Raw.wgr_logger_set_level(level);

	public static inline function message(level:LogLevel, msg:String):Void
		Raw.wgr_logger_message(level, "%s", msg);

	public static inline function trace(msg:String):Void
		message(Trace, msg);

	public static inline function debug(msg:String):Void
		message(Debug, msg);

	public static inline function info(msg:String):Void
		message(Info, msg);

	public static inline function warn(msg:String):Void
		message(Warn, msg);

	public static inline function error(msg:String):Void
		message(Error, msg);

	public static inline function fatal(msg:String):Void
		message(Fatal, msg);
}
