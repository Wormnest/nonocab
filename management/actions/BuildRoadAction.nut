/**
 * Action class for the creation of roads.
 */
class BuildRoadAction extends Action
{
	connection = null;			// Connection object of the road to build.
	buildDepot = false;			// Should we create a depot?
	buildRoadStations = false;	// Should we build road stations?
	directions = null;			// A list with all directions.
	pathfinder = null;			// The pathfinder to use.
	world = null;				// The world.
	
	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, buildDepot, buildRoadStations, world)
	{
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.connection = connection;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
		this.pathfinder = RoadPathFinding();
		this.world = world;
		Action.constructor();
	}
}


function BuildRoadAction::Execute()
{
	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	
	// Check if this path isn't already build.
	if (!connection.pathInfo.build) {
	
		local pathBuilder = PathBuilder(connection, world.cargoTransportEngineIds[connection.cargoID]);
	
		local roadCost = PathBuilder.GetCostForRoad(connection.pathInfo.roadList);
		local money = AICompany.GetBankBalance(AICompany.MY_COMPANY);
		if (roadCost > money) {
			Log.logWarning("Not enough money(" + money + ") to build the road (cost = " + roadCost +").");
			return false;
		}
		
		if (!pathBuilder.RealiseConnection(buildRoadStations)) {
			connection.pathInfo.forceReplan = true;
			Log.logError("BuildRoadAction: Failed to build a road");
			return false;
		}
	}
		
	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();

	if (buildRoadStations) {
	
		// This breaks?!
		//local abc = AIExecMode();
		local isTruck = !AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS);
		if (!AIRoad.IsRoadStationTile(roadList[0].tile) && !AIRoad.BuildRoadStation(roadList[0].tile, roadList[1].tile, isTruck, false, true)) {
			
			if (!BuildRoadStation(connection, false, isTruck)) {
				Log.logError("BuildRoadAction: Road station couldn't be build! Not handled yet!");
				connection.pathInfo.forceReplan = true;
				return false;
			}
		} 
		
		if (!AIRoad.IsRoadStationTile(roadList[len - 1].tile) && !AIRoad.BuildRoadStation(roadList[len - 1].tile, roadList[len - 2].tile, isTruck, false, true)) {
			
			if (!BuildRoadStation(connection, true, isTruck)) {
				Log.logError("BuildRoadAction: Road station couldn't be build! Not handled yet!");
				connection.pathInfo.forceReplan = true;
				return false;
			}
		}
	}

	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		local depotLocation = null;
		local depotFront = null;
		
		// Look for a suitable spot and test if we can build there.
		for (local i = 2; i < len - 1; i++) {
			
			foreach (direction in directions) {
				if (direction == roadList[i].direction || direction == -roadList[i].direction)
					continue;
				if (Tile.IsBuildable(roadList[i].tile + direction) && AIRoad.CanBuildConnectedRoadPartsHere(roadList[i].tile, roadList[i].tile + direction, roadList[i + 1].tile)) {
					
					// Switch to test mode so we don't build the depot, but just test its location.
					{
						local test = AITestMode();
						if (AIRoad.BuildRoadDepot(roadList[i].tile + direction, roadList[i].tile)) {
							
							// We can't build the depot instantly, because OpenTTD crashes if we
							// switch to exec mode at this point (stupid bug...).
							depotLocation = roadList[i].tile + direction;
							depotFront = roadList[i].tile;
							connection.pathInfo.depot = depotLocation;
						}
					}
					
					if (depotLocation) {
						local abc = AIExecMode();
						// If we found the correct location switch to exec mode and build it.
						// Note that we need to build the road first, else we are unable to do
						// so again in the future.
						if (!AIRoad.BuildRoad(depotLocation, depotFront) ||	!AIRoad.BuildRoadDepot(depotLocation, depotFront)) {
							depotLocation = null;
							depotFront = null;
						} else {
							break;
						}
					}
				}
			}
			
			if (depotLocation != null)
				break;
		}
		
		// Check if we could actualy build a depot:
		if (depotLocation == null)
			return false;
	}
	
	// We only specify a connection as build if both the depots and the roads are build.
	connection.pathInfo.build = true;
	
	
	CallActionHandlers();
	return true;
}


function BuildRoadAction::BuildRoadStation(connection, isProducingSide, isTruck) {
	Log.logError(AIError.GetLastErrorString());
	

	local originalRoadList = connection.pathInfo.roadList;
	local originalRoadListLen = originalRoadList.len();
	
	// Find a new way to connect the industry:
	local start_list;
	if (isProducingSide) {
		// The road is calculated from the producition side to the accepting side.
		// However, the road is stored from the accepting side to the production
		// side!
		start_list = connection.travelFromNode.GetProducingTiles(connection.cargoID);
		start_list.RemoveTile(originalRoadList[originalRoadListLen - 1].tile);
		AISign.BuildSign(originalRoadList[originalRoadListLen - 1].tile, "!");
	} else {
		start_list = connection.travelToNode.GetAcceptingTiles(connection.cargoID);
		start_list.RemoveTile(originalRoadList[0].tile);
		AISign.BuildSign(originalRoadList[0].tile, "!");		
	}
	
	/**
	 * The end list consists of the first 10 nodes of the path before
	 * the actual road station. The original location of the road list
	 * is however excluded from the list (since we couldn't build there
	 * in the first place!
	 */
	local end_list = AIList();
	local max = 10;
	if (originalRoadListLen < max + 1)
		max = originalRoadListLen - 1;
	if (isProducingSide) {		
		for (local i = 0; i < max; i++) {
			end_list.AddItem(originalRoadList[originalRoadListLen - (i + 2)].tile, originalRoadList[originalRoadListLen - (i + 2)].tile);
		}
	} else {
		for (local i = 0; i < max; i++) {
			end_list.AddItem(originalRoadList[i + 1].tile, originalRoadList[i + 1].tile); 
		}		
	}

	Log.logError("start tiles: " + start_list.Count());
	Log.logError("End tiles: " + end_list.Count());

	// We try to build a path to connect the disconnected road station.
	local roadStationPathInfo = pathfinder.FindFastestRoad(start_list, end_list, true, false, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 3);
			
	if (roadStationPathInfo == null) {
		Log.logError("couldn't build the road station, aborting! (null)");
		return false;
	}
	
	// Debug; Show the calculated route.
	foreach (at in roadStationPathInfo.roadList) {
		AISign.BuildSign(at.tile, "X");
	}
			
	// Try to build it, remember that the start position is the location for the new
	// road station. But the path is stored backwards, so the new location is the
	// very last item on the roadList!
	local pathBuilder = PathBuilder(null, AIEngine.GetMaxSpeed(world.cargoTransportEngineIds[connection.cargoID]));
	local buildResult = pathBuilder.BuildPath(roadStationPathInfo.roadList, false);
	
	AISign.BuildSign(roadStationPathInfo.roadList[roadStationPathInfo.roadList.len() - 1].tile, "New station");
	if (buildResult && AIRoad.BuildRoadStation(roadStationPathInfo.roadList[roadStationPathInfo.roadList.len() - 1].tile, roadStationPathInfo.roadList[roadStationPathInfo.roadList.len() - 2].tile, isTruck, false, true)) {
		// We're done so update the connection.
		local connectionTile = -1;
		
		// Now that we've updated the original roadList, we need to update
		// the connection to reflect this change. So we try to find the
		// point where the new piece of road overlaps with the original
		// pathlist and overwrite that part.		
		for (local i = 0; i < 10; i++) {
			if (!isProducingSide && originalRoadList[i + 1].tile == roadStationPathInfo.roadList[0].tile) {
				connectionTile = i + 1;
				break;
			} else if (isProducingSide && originalRoadList[originalRoadListLen - (i + 2)].tile == roadStationPathInfo.roadList[0].tile) {
				connectionTile = originalRoadListLen - (i + 2);
				break;
			}
		}
		
		if (connectionTile == -1) {
			Log.logError("Couldn't find connection point with original road, aborting!");
			quit();
		}
		
		// Now, the road list is stored from accepting side to the production side. But the
		// new road for the road station is always stored from the original road to the new
		// road station. So if we calculate the road for the road station at the accepting side
		// we need to reverse the roadlist before adding them to the path info.
		if (!isProducingSide) {
			roadStationPathInfo.roadList.reverse();
			local arrayPart = connection.pathInfo.roadList.slice(connectionTile + 1);
			roadStationPathInfo.roadList.extend(arrayPart);
			connection.pathInfo.roadList = roadStationPathInfo.roadList;
		} else {
			connection.pathInfo.roadList = connection.pathInfo.roadList.slice(0, connectionTile);
			connection.pathInfo.roadList.extend(roadStationPathInfo.roadList);
		}
		return true;
	} else {
		Log.logError("couldn't build the road station, aborting!");
		Log.logError(AIError.GetLastErrorString());
		return false;
	}
}
