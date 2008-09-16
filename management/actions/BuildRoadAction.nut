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
	
	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, buildDepot, buildRoadStations)
	{
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.connection = connection;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
		this.pathfinder = RoadPathFinding();
		Action.constructor(null);
	}
}


function BuildRoadAction::Execute()
{
	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local abc = AIExecMode();
	if (!pathfinder.CreateRoad(connection)) {
		Log.logError("Failed to build a road");
		return;
	}
	
	connection.pathInfo.build = true;
	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();
	
	if (buildRoadStations) {
		if (!AIRoad.BuildRoadStation(roadList[0].tile, roadList[1].tile, true, false, true)) {
			Log.logError("Road station couldn't be build! Not handled yet!");

			// Find a new way to connect the industry:
			local start_list = connection.toIndustryNode.GetAcceptingTiles();
			start_list.RemoveItem(roadList[0].tile);
			local end_list = AIList();
			
			for (local i = 0; i < 10; i++) {
				end_list.AddItem(roadList[i + 1].tile, roadList[i + 1].tile); 
			}
			
			local pathInfo = pathfinder.FindFastestRoad(start_list, end_list, true, false);
			
			if (pathInfo == null) {
				Log.logError("couldn't build the road station, aborting!");
				return false;
			}
			
			// Try to build it.
			local buildResult = pathfinder.BuildRoad(pathInfo.roadList);
			
			if (buildResult.success && AIRoad.BuildRoadStation(pathInfo.roadList[0].tile, pathInfo.roadList[1].tile, true, false, true)) {
				// We're done so update the connection.
				local connectionTile = null;
				
				for (local i = 0; i < 10; i++) {
					if (roadList[i + 1].tile == pathInfo.roadList[0].tile) {
						connectionTile = i + 1;
						break;
					}
				}
			 
			 	// Update connection info.
			 	connection.pathInfo.roadList = pathInfo.roadList.extend(connection.pathInfo.roadList.splice(connectionTile));
			} else {
				Log.logError("couldn't build the road station, aborting!");
				return false;
			}	
		} 
		
		if (!AIRoad.BuildRoadStation(roadList[len - 1].tile, roadList[len - 2].tile, true, false, true)) {
			Log.logError("Road station couldn't be build! Not handled yet!");
			
			// Find a new way to connect the industry:
			local start_list = connection.fromIndustryNode.GetProducingTiles();
			start_list.RemoveItem(roadList[len - 1].tile);
			local end_list = AIList();
			
			for (local i = 0; i < 10; i++) {
				end_list.AddItem(roadList[len - (i + 2)].tile, roadList[len - (i + 2)].tile); 
			}
			
			local pathInfo = pathfinder.FindFastestRoad(start_list, end_list, true, false);			
			
			if (pathInfo == null) {
				Log.logError("couldn't build the road station, aborting!");
				return false;
			}
			
			// Try to build it.
			local buildResult = pathfinder.BuildRoad(pathInfo.roadList);
			local len2 = pathInfo.roadList.len();
			
			if (buildResult.success && AIRoad.BuildRoadStation(pathInfo.roadList[len2 - 1].tile, pathInfo.roadList[len2 - 2].tile, true, false, true)) {
				// We're done so update the connection.
				local connectionTile = null;
				
				for (local i = 0; i < 10; i++) {
					if (roadList[len - (i + 2)].tile == pathInfo.roadList[len2 - 1].tile) {
						connectionTile = len - (i + 2);
						break;
					}
				}
			 
			 	// Update connection info.
			 	connection.pathInfo.roadList = connection.pathInfo.roadList.splice(0, connectionTile).extend(pathInfo.roadList);
			} else {
				Log.logError("couldn't build the road station, aborting!");
				return false;
			}
		} 
	}

	// Check if we need to build a depot.	
	if (buildDepot) {
		local depotLocation = null;
		local depotFront = null;
		
		// Look for a suitable spot and test if we can build there.
		for (local i = 2; i < len - 1; i++) {
			
			foreach (direction in directions) {
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
						local test = AIExecMode();
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
	}
	
	CallActionHandlers();
}