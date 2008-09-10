/**
 * Action class for the creation of roads.
 */
class BuildRoadAction extends Action
{
	connection = null;			// Connection object of the road to build.
	buildDepot = false;			// Should we create a depot?
	buildRoadStations = false;	// Should we build road stations?
	directions = null;			// A list with all directions.
	
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
		Action.constructor(null);
	}
}


function BuildRoadAction::Execute()
{
	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local abc = AIExecMode();
	if (!RoadPathFinding.CreateRoad(connection.pathInfo)) {
		Log.logError("Failed to build a road");
		return;
	}
	
	local roadList = connection.pathInfo.roadList;
	
	if (buildRoadStations) {
		local len = connection.pathInfo.roadList.len();
		local a = connection.pathInfo.roadList[0];
		AIRoad.BuildRoadStation(roadList[0].tile, roadList[1].tile, true, false, true);
		AIRoad.BuildRoadStation(roadList[len - 1].tile, roadList[len - 2].tile, true, false, true);
	}

	// Check if we need to build a depot.	
	if (buildDepot) {
		local depotLocation = null;
		local depotFront = null;
		
		// Look for a suitable spot and test if we can build there.
		for (local i = 2; i < roadList.len() - 1; i++) {
			
			foreach (direction in directions) {
				if (Tile.IsBuildable(roadList[i].tile + direction) && AIRoad.CanBuildConnectedRoadPartsHere(roadList[i].tile, roadList[i].tile + direction, roadList[i + 1].tile)) {
					
					// Switch to test mode so we don't build the depot, but just test its location.
					local test = AITestMode();
					if (AIRoad.BuildRoadDepot(roadList[i].tile + direction, roadList[i].tile)) {
						
						// We can't build the depot instantly, because OpenTTD crashes if we
						// switch to exec mode at this point (stupid bug...).
						depotLocation = roadList[i].tile + direction;
						depotFront = roadList[i].tile;
						connection.pathInfo.depot = depotLocation;
						break;
					}
				}
			}
			
			if (depotFront != null)
				break;
		}
		
		// If we found the correct location switch to exec mode and build it.
		// Note that we need to build the road first, else we are unable to do
		// so again in the future.
		local test = AIExecMode();
		AIRoad.BuildRoad(depotLocation, depotFront);
		AIRoad.BuildRoadDepot(depotLocation, depotFront);
	}
	
	CallActionHandlers();
}