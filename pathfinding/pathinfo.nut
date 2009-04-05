/**
 * Store important info about a path we found! :)
 */
class PathInfo {

	roadList = null;		// List of all road tiles the road needs to follow.
	roadCost = null;		// The cost to create this road.
	depot = null;			// The location of the depot.
	depotOtherEnd = null;		// The location of the depot at the other end (if it any).
	build = null;			// Is this path build?
							
	travelTimesCache = null;	// An array containing the travel times in days for vehicles with a certain speed.

	buildDate = null;		// The date this connection is build.
	nrRoadStations = null;          // The number of road stations.

	constructor(_roadList, _roadCost) {
		roadList = _roadList;
		roadCost = _roadCost;
		build = false;
		travelTimesCache = {};
		nrRoadStations = 0;
	}
	
	function LoadData(data) {
		roadList = [];
		foreach (tile in data["roadList"]) {
			local at = AnnotatedTile();
			at.tile = tile;
			roadList.push(at);
		}
		roadCost = data["roadCost"];
		depot = data["depot"];
		depotOtherEnd = data["depotOtherEnd"];
		build = data["build"];
		travelTimesCache = data["travelTimesCache"];
		buildDate = data["buildDate"];
		nrRoadStations = data["nrRoadStations"];
	}
	
	function SaveData() {
		local saveData = {};
		saveData["roadList"] <- [];
		foreach (at in roadList) {
			saveData["roadList"].push(at.tile);
		}
		saveData["roadCost"] <- roadCost;
		saveData["depot"] <- depot;
		saveData["depotOtherEnd"] <- depotOtherEnd;
		saveData["build"] <- build;
		saveData["travelTimesCache"] <- travelTimesCache;
		saveData["buildDate"] <- buildDate;
		saveData["nrRoadStations"] <- nrRoadStations;
		return saveData;
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

function PathInfo::GetTravelTime(engineID, forward) {
	
	if (roadList == null)
		return -1;
		
	// Check if we don't have this in our cache.
	local maxSpeed = AIEngine.GetMaxSpeed(engineID);
	local vehicleType = AIEngine.GetVehicleType(engineID);
	local cacheID = "" + forward + "_" + vehicleType + "_" + maxSpeed;

	if (travelTimesCache.rawin(cacheID))
		return travelTimesCache.rawget(cacheID);
		
	local time;

	if (vehicleType == AIVehicle.VT_ROAD)
		time = RoadPathFinderHelper.GetTime(roadList, maxSpeed, forward);
	else if (vehicleType == AIVehicle.VT_WATER)
		time = WaterPathFinderHelper.GetTime(roadList, maxSpeed, forward);
	else
		Log.logWarning("Unknown vehicle type: " + vehicleType);
	
	travelTimesCache[cacheID] <- time;
	return time;
}
