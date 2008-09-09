/**
 * Store important info about a path we found! :)
 */
class PathInfo
{
	roadList = null;		// List of all road tiles the road needs to follow.
	roadCost = null;		// The cost to create this road.
	depot = null;			// The location of the depot.
	build = null;			// Is this path build?

	constructor(roadList, roadCost) {
		this.roadList = roadList;
		this.roadCost = roadCost;
		this.build = false;
	}
}

