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
		this.pathfinder = RoadPathFinding(PathFinderHelper());
		this.world = world;
		Action.constructor();
	}
}


function BuildRoadAction::Execute()
{
	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");

	local isConnectionBuild = connection.pathInfo.build;
	local newConnection = null;
	local originalRoadList = null;

	// If the connection is already build we will try to add additional road stations.
	if (isConnectionBuild) {
		newConnection = Connection(0, connection.travelFromNode, connection.travelToNode, 0, 0);
		originalRoadList = clone connection.pathInfo.roadList;
	}
	
	{
		// Replan the route.
		local pathFinder = RoadPathFinding(PathFinderHelper());
		local connectionPathInfo = null;
		if (!isConnectionBuild)
			connection.pathInfo = pathfinder.FindFastestRoad(connection.travelFromNode.GetProducingTiles(connection.cargoID), connection.travelToNode.GetAcceptingTiles(connection.cargoID), true, true, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 2);
		else 
			newConnection.pathInfo = pathfinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false), true, true, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 2);


		// If we need to build additional road stations we will temporaly overwrite the 
		// road list of the connection with the roadlist which will build the additional
		// road stations. 
		if (isConnectionBuild) {

			if (newConnection.pathInfo == null)
				return false;

			connection.pathInfo.roadList = newConnection.pathInfo.roadList;
			connection.pathInfo.build = true;
		}

		else if (connection.pathInfo == null) {
			connection.pathInfo = PathInfo(null, 0);
			connection.pathInfo.forceReplan = true;
			return false;
		}
	}

	local pathBuilder = PathBuilder(connection, world.cargoTransportEngineIds[connection.cargoID], world.pathFixer);
	
	if (!pathBuilder.RealiseConnection(buildRoadStations)) {
		if (!isConnectionBuild)
			connection.pathInfo.forceReplan = true;
		else
			connection.pathInfo.roadList = originalRoadList;
		Log.logError("BuildRoadAction: Failed to build a road " + AIError.GetLastErrorString());
		return false;
	}
		
	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();

	if (buildRoadStations) {

		// This breaks?!
		//local abc = AIExecMode();
		local isTruck = !AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS);
		if (!AIRoad.IsRoadStationTile(roadList[0].tile) && !AIRoad.BuildRoadStation(roadList[0].tile, roadList[1].tile, isTruck, false, isConnectionBuild)) {
			
			Log.logError("BuildRoadAction: Road station couldn't be build!");
			if (!isConnectionBuild)
				connection.pathInfo.forceReplan = true;
			else
				connection.pathInfo.roadList = originalRoadList;
			return false;
		} else if (!isConnectionBuild) {
			connection.travelToNodeStationID = AIStation.GetStationID(roadList[0].tile);
			assert(AIStation.GetStationID(connection.travelToNodeStationID));
		}
		
		if (!AIRoad.IsRoadStationTile(roadList[len - 1].tile) && !AIRoad.BuildRoadStation(roadList[len - 1].tile, roadList[len - 2].tile, isTruck, false, isConnectionBuild)) {
			
			Log.logError("BuildRoadAction: Road station couldn't be build! Not handled yet!");
			if (!isConnectionBuild)
				connection.pathInfo.forceReplan = true;
			else
				connection.pathInfo.roadList = originalRoadList;
			return false;
		} else if (!isConnectionBuild) {
			connection.travelFromNodeStationID = AIStation.GetStationID(roadList[len - 1].tile);
			assert(AIStation.GetStationID(connection.travelFromNodeStationID));		
		}
	}

	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		local depotLocation = null;
		local depotFront = null;
		
		// Look for a suitable spot and test if we can build there.
		for (local i = len - 4; i > 1; i--) {
			
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
	
	// We must make sure that the original road list is restored because we join the new
	// road station with the existing one, but OpenTTD only recognices the original one!
	// If we don't do this all vehicles which are build afterwards get wrong orders and
	// the AI fails :(.
	if (isConnectionBuild)
		connection.pathInfo.roadList = originalRoadList;
	// We only specify a connection as build if both the depots and the roads are build.
	else
		connection.pathInfo.build = true;
	
	connection.lastChecked = AIDate.GetCurrentDate();
	
	CallActionHandlers();
	return true;
}

