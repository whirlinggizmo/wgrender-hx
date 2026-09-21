package wgr;

// wgr_pick.h — what the last pick cost

/** Fields in the C struct's order; see `Touch`. **/
@:structInit
class PickStats {
	public final broadphaseTests:Int;
	public final broadphaseRejects:Int;
	public final narrowphaseTests:Int;
	public final narrowphaseHits:Int;

	public function new(broadphaseTests, broadphaseRejects, narrowphaseTests, narrowphaseHits) {
		this.broadphaseTests = broadphaseTests;
		this.broadphaseRejects = broadphaseRejects;
		this.narrowphaseTests = narrowphaseTests;
		this.narrowphaseHits = narrowphaseHits;
	}
}
