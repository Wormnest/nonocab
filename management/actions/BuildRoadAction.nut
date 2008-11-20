/**
 * Action class for the creation of roads.
 */
class BuildRoadAction extends Action
{
	connection = null;		// Connection object of the road to build.
	buildDepot = false;		// Should we create a depot?
	buildRoadStations = false;	// Should we build road stations?
	directions = null;		// A list with all directions.
	world = null;			// The world.
	vehicleAdvisor = null;		// The advisor to manage the road vehicles.
	
	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, buildDepot, buildRoadStations, world, vehicleAdv) {
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.connection = connection;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
		this.world = world;
		vehicleAdvisor = vehicleAdv;
		Action.constructor();
	}
}


function BuildRoadAction::Execute() {

	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");

	local isConnectionBuild = connection.pathInfo.build;
	local newConnection = null;
	local originalRoadList = null;

	// If the connection is already build we will try to add additional road stations.
	if (isConnectionBuild) {
		newConnection = Connection(0, connection.travelFromNode, connection.travelToNode, 0);
		originalRoadList = clone connection.pathInfo.roadList;
	}


	local pathFinderHelper = RoadPathFinderHelper();
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
	// For non-existing roads we want the AI to find the best route possible.
	if (!isConnectionBuild)
		pathFinderHelper.costTillEnd = pathFinderHelper.costForRoad;
		
	// For existing routs, we want the new path to coher to the existing
	// path as much as possible, therefor we calculate no additional
	// penalties for turns so the pathfinder can find the existing
	// route as quick as possible.
	else {
		pathFinderHelper.costForTurn = pathFinderHelper.costForNewRoad;
		pathFinderHelper.costTillEnd = pathFinderHelper.costForNewRoad;
		pathFinderHelper.costForNewRoad = pathFinderHelper.costForNewRoad * 2;
		pathFinderHelper.costForBridge = pathFinderHelper.costForBridge * 2;
		pathFinderHelper.costForTunnel = pathFinderHelper.costForTunnel * 2;
	}
		
	local connectionPathInfo = null;
	local stationType = (!AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	if (!isConnectionBuild)
		connection.pathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetProducingTiles(connection.cargoID, stationRadius, 1, 1), connection.travelToNode.GetAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 3);
	else 
		newConnection.pathInfo = pathFinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 3);

	// If we need to build additional road stations we will temporaly overwrite the 
	// road list of the connection with the roadlist which will build the additional
	// road stations. 
	if (isConnectionBuild) {

		if (newConnection.pathInfo == null)
			return false;

		connection.pathInfo.roadList = newConnection.pathInfo.roadList;
		connection.pathInfo.build = true;
	} else if (connection.pathInfo == null) {
		connection.pathInfo = PathInfo(null, 0);
		connection.forceReplan = true;
		return false;
	}	

	// Build the actual road.
	local pathBuilder = PathBuilder(connection, world.cargoTransportEngineIds[AIVehicle.VEHICLE_ROAD][connection.cargoID], world.pathFixer);

	if (!pathBuilder.RealiseConnection(buildRoadStations)) {
		if (isConnectionBuild)
			connection.pathInfo.roadList = originalRoadList;
		else
			connection.forceReplan = true;
		Log.logError("BuildRoadAction: Failed to build a road " + AIError.GetLastErrorString());
		return false;
	}
		
	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();

	if (buildRoadStations) {

		local isTruck = !AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS);
		if (!AIRoad.IsRoadStationTile(roadList[0].tile) && !AIRoad.BuildRoadStation(roadList[0].tile, roadList[1].tile, isTruck, false, true)) {
			
			Log.logError("BuildRoadAction: Road station couldn't be build! " + AIError.GetLastErrorString());
			if (isConnectionBuild)
				connection.pathInfo.roadList = originalRoadList;
			else
				connection.forceReplan = true;
			return false;
		} else if (!isConnectionBuild) {
			connection.travelToNodeStationID = AIStation.GetStationID(roadList[0].tile);
			assert(AIStation.GetStationID(connection.travelToNodeStationID));
		}
		
		if (!AIRoad.IsRoadStationTile(roadList[len - 1].tile) && !AIRoad.BuildRoadStation(roadList[len - 1].tile, roadList[len - 2].tile, isTruck, false, isConnectionBuild)) {
			
			Log.logError("BuildRoadAction: Road station couldn't be build! Not handled yet!" + AIError.GetLastErrorString());
			if (isConnectionBuild)
				connection.pathInfo.roadList = originalRoadList;
			else
				connection.forceReplan = true;
			return false;
		} else if (!isConnectionBuild) {
			connection.travelFromNodeStationID = AIStation.GetStationID(roadList[len - 1].tile);
			assert(AIStation.GetStationID(connection.travelFromNodeStationID));		
		}

		connection.pathInfo.nrRoadStations++;

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not to near each
		// other.
		if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {

			local stationType = isTruck ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
			connection.travelFromNode.AddExcludeTiles(connection.cargoID, roadList[len - 1].tile, AIStation.GetCoverageRadius(stationType));
			connection.travelToNode.AddExcludeTiles(connection.cargoID, roadList[0].tile, AIStation.GetCoverageRadius(stationType));
		}
	}

	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		
		local depot = BuildDepot(roadList, len - 4, -1);

		// Check if we could actualy build a depot:
		if (depot == null)
			return false;

		connection.pathInfo.depot = depot;

		if (connection.bilateralConnection) {

			depot = BuildDepot(roadList, 3, 1);
			if (depot == null)
				return false;

			connection.pathInfo.depotOtherEnd = depot;
		}
	}
	
	// We must make sure that the original road list is restored because we join the new
	// road station with the existing one, but OpenTTD only recognices the original one!
	// If we don't do this all vehicles which are build afterwards get wrong orders and
	// the AI fails :(.
	if (isConnectionBuild)
		connection.pathInfo.roadList = originalRoadList;
	// We only specify a connection as build if both the depots and the roads are build.
	else {
		connection.pathInfo.build = true;
		connection.vehicleTypes = AIVehicle.VEHICLE_ROAD;
		connection.pathInfo.buildDate = AIDate.GetCurrentDate();
		vehicleAdvisor.connections.push(connection);
	}
	
	connection.lastChecked = AIDate.GetCurrentDate();
	
	CallActionHandlers();
	return true;
}

function BuildRoadAction::BuildDepot(roadList, startPoint, searchDirection) {

	local len = roadList.len();
	local depotLocation = null;
	local depotFront = null;

	// Look for a suitable spot and test if we can build there.
	for (local i = startPoint; i > 1; i += searchDirection) {
			
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
					}
				}
				
				if (depotLocation) {
					local abc = AIExecMode();
					// If we found the correct location switch to exec mode and build it.
					// Note that we need to build the road first, else we are unable to do
					// so again in the future.
					if (!AIRoad.BuildRoad(depotLocation, depotFront) || !AIRoad.BuildRoadDepot(depotLocation, depotFront)) {
						depotLocation = null;
						depotFront = null;
					} else {
						break;
					}
				}
			}
		}
		
		if (depotLocation != null)
			return depotLocation;
	}

	return null;
}
