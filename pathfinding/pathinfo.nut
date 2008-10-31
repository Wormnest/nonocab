/**
 * Store important info about a path we found! :)
 */
class PathInfo
{
	roadList = null;		// List of all road tiles the road needs to follow.
	roadCost = null;		// The cost to create this road.
	depot = null;			// The location of the depot.
	build = null;			// Is this path build?
	forceReplan = null;		// Must this path be replanned?
							
	travelTimesForward = null;	// An array containing the travel times in days for vehicles with a certain speed.
	travelTimesBackward = null;	// An array containing the travel times in days for vehicles with a certain speed.

	buildDate = null;		// The date this connection is build.
	nrRoadStations = null;          // The number of road stations.

	constructor(_roadList, _roadCost) {
		roadList = _roadList;
		roadCost = _roadCost;
		build = false;
		travelTimesForward = [];
		travelTimesBackward = [];
		nrRoadStations = 0;
	}
	
	/**
	 * Get the traveltime for a vehicle with a certain maxSpeed for this road.
	 * @maxSpeed The maximum speed of the engine in question.
	 * @forward If true, we calculate the time from the start point to the end point
	 * (as calculated by the pathfinder).
	 * return The number of days it takes to traverse a certain road.
	 */
	function GetTravelTime(maxSpeed, forward);
}

function PathInfo::GetTravelTime(maxSpeed, forward) {
	
	if (roadList == null)
		return -1;
		
	// Check if we don't have this in our cache.
	local cache = (forward ? travelTimesForward : travelTimesBackward);
	foreach (time in cache) {
		if (time[0] == maxSpeed) 
			return time[1];
	}
	
	local pathfinder = RoadPathFinding(PathFinderHelper());
	local time = pathfinder.GetTime(roadList, maxSpeed, forward);
	cache.push([maxSpeed, time]);
	return time;
}
