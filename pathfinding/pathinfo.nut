/**
 * Store important info about a path we found! :)
 */
class PathInfo {

	roadList = null;                 // List of all road tiles the road needs to follow.
	roadListReturn = null;           // Like roadList but for the return journey (only for trains).
	extraRoadBits = null;            // Any extra road bits this connection requires. These are mainly the tracks
	                                 // needed by trains to link to the other platforms at stations or to connect
	                                 // the roadList and roadListReturn.
	/// @todo roadCost doesn't seem to be used anywhere. Remove?
	roadCost = null;                 // The cost to create this road.
	depot = null;                    // The location of the depot.
	depotOtherEnd = null;            // The location of the depot at the other end (if any).
	build = null;                    // Is this path built?
	vehicleType = null;              // The vehicle type this path info is for. Note: Can be set to AIVehicle.VT_INVALID in ConnectionsAdvisor.nut!
	travelFromNodeStationID = null;  // The station ID of the producing side.
	travelToNodeStationID = null;    // The station ID of the accepting side.
							
	travelTimesCache = null;         // An array containing the travel times in days for vehicles with a certain speed.

	buildDate = null;                // The date this connection is build.
	nrRoadStations = null;           // The number of road stations.
	
	refittedForArticulatedVehicles = null; // Has this path been refitted to allow articulated vehicles?

	constructor(_roadList, _roadListReturn, _roadCost, _vehicleType) {
		roadList = _roadList;
		roadListReturn = _roadListReturn;
		extraRoadBits = [];
		roadCost = _roadCost;
		vehicleType = _vehicleType;
		build = false;
		travelTimesCache = {};
		nrRoadStations = 0;
		depot = null;
		depotOtherEnd = null;
		refittedForArticulatedVehicles = false;
		travelFromNodeStationID = null;
		travelToNodeStationID = null;
	}
	
	// Since the vehicleType in pathInfo can be AIVehicle.VT_INVALID we can't use it to determine if
	// we need to call FixRoadList. Thus we add a parameter here.
	function LoadData(data, actual_vehicleType) {
		roadList = [];
		foreach (tile in data["roadList"]) {
			local at = AnnotatedTile();
			at.tile = tile;
			roadList.push(at);
		}
		
		roadListReturn = [];
		foreach (tile in data["roadListReturn"]) {
			local at = AnnotatedTile();
			at.tile = tile;
			roadListReturn.push(at);
		}
		
		extraRoadBits = [];
		foreach (roadBitList in data["extraRoadBits"]) {
			local array = [];
			foreach (tile in roadBitList) {
				local at = AnnotatedTile();
				at.tile = tile;
				array.push(at);
			}
			extraRoadBits.push(array);
		}
		
		roadCost = data["roadCost"];
		vehicleType = data["vehicleType"];
		depot = data["depot"];
		depotOtherEnd = data["depotOtherEnd"];
		build = data["build"];
		buildDate = data["buildDate"];
		nrRoadStations = data["nrRoadStations"];
		refittedForArticulatedVehicles = data["refittedForArticulatedVehicles"];
		// We need to fix up roadlists because roadList.type and direction are used
		// in GetTravelTime which otherwise would return 0 causing problems.
		if ((actual_vehicleType == AIVehicle.VT_ROAD) || (actual_vehicleType == AIVehicle.VT_RAIL)) {
			// Also for rail for now!
			RoadPathFinderHelper.FixRoadlist(roadList);
			if (actual_vehicleType == AIVehicle.VT_RAIL)
				// Trains are the only vehicle type that uses roadListReturn
				RoadPathFinderHelper.FixRoadlist(roadListReturn);
		}
		// else it looks like we don't need to do fixups for water and air since they don't use
		// roadList.type and roadList.direction
	}
	
	function SaveData() {
		local saveData = {};
		saveData["roadList"] <- [];
		if (roadList) {
			foreach (at in roadList) {
				saveData["roadList"].push(at.tile);
			}
		}
		
		saveData["roadListReturn"] <- [];
		if (roadListReturn) {
			foreach (at in roadListReturn) {
				saveData["roadListReturn"].push(at.tile);
			}
		}
		
		saveData["extraRoadBits"] <- [];
		if (extraRoadBits) {
			foreach (roadBitList in extraRoadBits) {
				local array = [];
				foreach (at in roadBitList) {
					array.push(at.tile);
				}
				saveData["extraRoadBits"].push(array);
			}
		}
		
		saveData["roadCost"] <- roadCost;
		saveData["vehicleType"] <- vehicleType;
		saveData["depot"] <- depot;
		saveData["depotOtherEnd"] <- depotOtherEnd;
		saveData["build"] <- build;
		saveData["buildDate"] <- buildDate;
		saveData["nrRoadStations"] <- nrRoadStations;
		saveData["refittedForArticulatedVehicles"] <- refittedForArticulatedVehicles;
		return saveData;
	}
	
	/**
	 * Get the traveltime for a vehicle with a certain maxSpeed for this road.
	 * @engineID The engine in question.
	 * @forward If true, we calculate the time from the start point to the end point
	 * (as calculated by the pathfinder).
	 * return The number of days it takes to traverse a certain road.
	 */
	function GetTravelTime(engineID, forward);
	
	/**
	 * Called after this path has been established. Used to update the internal parameters to 
	 * reflect the new state.
	 */
	function UpdateAfterBuild(vehicleType, fromTile, toTile, stationCoverageRadius);
}

function PathInfo::UpdateAfterBuild(vehicleType, fromTile, toTile, stationCoverageRadius) {
	// Wormnest: I think vehicleType should be set here too. Or is there a reason that's not done here?
	this.vehicleType = vehicleType;
	
	build = true;
	nrRoadStations = 1;
	buildDate = AIDate.GetCurrentDate();
	travelFromNodeStationID = AIStation.GetStationID(fromTile);
	travelToNodeStationID = AIStation.GetStationID(toTile);
}

function PathInfo::GetTravelTime(engineID, forward) {
	
	if (roadList == null)
		return -1;
		
	// Check if we don't have this in our cache.
	local maxSpeed = AIEngine.GetMaxSpeed(engineID);
	local vehicleType = AIEngine.GetVehicleType(engineID);
	local cacheID = "" + forward + "_" + vehicleType + "_" + maxSpeed;

	local time;

	//Log.logDebug("Get travel time for engine " + AIEngine.GetName(engineID) + (forward ? " going to destination." : " going back to source."));
	if (travelTimesCache.rawin(cacheID)) {
		time = travelTimesCache.rawget(cacheID);
		if (time > 0)
			return time;
		else
			// Should not happen! Maybe caused by loading a savegame?
			Log.logError("TravelTime in cache == 0! Updating cache.");
	}

	if (vehicleType == AIVehicle.VT_ROAD)
		time = RoadPathFinderHelper.GetTime(roadList, engineID, forward);
	else if (vehicleType == AIVehicle.VT_WATER)
		time = WaterPathFinderHelper.GetTime(roadList, engineID, forward);
	else if (vehicleType == AIVehicle.VT_RAIL)
		time = RailPathFinderHelper.GetTime(roadList, engineID, forward);
	else if (vehicleType == AIVehicle.VT_AIR) {
		
		// For air connections the distance travelled is different (shorter in general)
		// than road vehicles. A part of the tiles are traversed diagonal, we want to
		// capture this so we can make more precise predictions on the income per vehicle.
		local fromLoc = roadList[roadList.len() -1].tile;
		local toLoc = roadList[0].tile;
		local distanceX = AIMap.GetTileX(fromLoc) - AIMap.GetTileX(toLoc);
		local distanceY = AIMap.GetTileY(fromLoc) - AIMap.GetTileY(toLoc);

		if (distanceX < 0) distanceX = -distanceX;
		if (distanceY < 0) distanceY = -distanceY;

		local diagonalTiles;
		local straightTiles;

		if (distanceX < distanceY) {
			diagonalTiles = distanceX;
			straightTiles = distanceY - diagonalTiles;
		} else {
			diagonalTiles = distanceY;
			straightTiles = distanceX - diagonalTiles;
		}

		// Take the landing sequence in consideration.
		local realDistance = diagonalTiles * Tile.diagonalRoadLength + (straightTiles + 40) * Tile.straightRoadLength;
		time = realDistance / AIEngine.GetMaxSpeed(engineID);
		
		
		//local manhattanDistance = AIMap.DistanceManhattan(roadList[0].tile, roadList[roadList.len() - 1].tile);
		//time = manhattanDistance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(engineID);
	} else {
		Log.logWarning("Unknown vehicle type: " + vehicleType);
		quit();
		return 2147483647;
	}

	if (time > 0)
		travelTimesCache[cacheID] <- time;
	else
		Log.logError("Computed TravelTime == 0! Something is wrong!");
	return time;
}
