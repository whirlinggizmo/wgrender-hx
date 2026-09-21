package wgr;

// wgr_input.h

@:structInit
class MouseState {
	public final x:Int;
	public final y:Int;

	/** Scroll this frame: about one unit per wheel notch. **/
	public final wheel:Float;

	public final wheelX:Float;
	public final left:Int;
	public final right:Int;
	public final middle:Int;
	public final buttons:Array<Int>;
	public final dx:Int;
	public final dy:Int;

	public function new(x, y, wheel, wheelX, left, right, middle, buttons, dx, dy) {
		this.x = x;
		this.y = y;
		this.wheel = wheel;
		this.wheelX = wheelX;
		this.left = left;
		this.right = right;
		this.middle = middle;
		this.buttons = buttons;
		this.dx = dx;
		this.dy = dy;
	}
}
