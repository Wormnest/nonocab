/**
 * Action class for the creation of roads.
 */
class BuildRoadAction extends Action
{
	connection = null;         // Connection object of the road to build.
	buildDepot = false;        // Should we create a depot?
	buildRoadStations = false; // Should we build road stations?
	directions = null;         // A list with all directions.
	
	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, buildDepot, buildRoadStations) {
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.connection = connection;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
		Action.constructor();
	}
}

function BuildRoadAction::Execute() {

	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local accounter = AIAccounting();

	local isConnectionBuild = connection.pathInfo.build;
	local newConnection = null;
	local originalRoadList = null;

	// If the connection is already build we will try to add additional road stations.
	if (isConnectionBuild) {
		newConnection = Connection(0, connection.travelFromNode, connection.travelToNode, 0, null);
		originalRoadList = clone connection.pathInfo.roadList;
	}

	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_ROAD);
	assert (bestEngineIDs != null);
	local transportingEngineID = bestEngineIDs[0];
	local pathFinderHelper = RoadPathFinderHelper(AIEngine.IsArticulated(transportingEngineID));
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
	// For existing routs, we want the new path to coher to the existing
	// path as much as possible, therefor we calculate no additional
	// penalties for turns so the pathfinder can find the existing
	// route as quick as possible.
	if (isConnectionBuild) {
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
		connection.pathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetProducingTiles(connection.cargoID, stationRadius, 1, 1), connection.travelToNode.GetAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	else 
		newConnection.pathInfo = pathFinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);

	// If we need to build additional road stations we will temporaly overwrite the 
	// road list of the connection with the roadlist which will build the additional
	// road stations. 
	if (isConnectionBuild) {

		if (newConnection.pathInfo == null)
			return false;

		connection.pathInfo.roadList = newConnection.pathInfo.roadList;
		connection.pathInfo.build = true;
	} else if (connection.pathInfo == null) {
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_ROAD);
		connection.forceReplan = true;
		return false;
	}
	
	// Check if we can build the road stations.
	if (buildRoadStations) {
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(connection.pathInfo.roadList[0].tile), AICompany.COMPANY_SELF) < -200)
			return false;
			
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile), AICompany.COMPANY_SELF) < -200)
			return false;	
	}	

	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();

	// Build the actual road.
	local pathBuilder = PathBuilder(roadList, transportingEngineID);

	if (!pathBuilder.RealiseConnection(buildRoadStations)) {
		if (isConnectionBuild)
			connection.pathInfo.roadList = originalRoadList;
		else
			connection.forceReplan = true;
		Log.logError("BuildRoadAction: Failed to build a road " + AIError.GetLastErrorString());
		return false;
	}
		
	if (buildRoadStations) {
		
		local roadVehicleType = AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIRoad.ROADVEHTYPE_BUS : AIRoad.ROADVEHTYPE_TRUCK; 
		if (!BuildRoadStation(connection, roadList[0].tile, roadList[1].tile, roadVehicleType, isConnectionBuild, true) ||
			!BuildRoadStation(connection, roadList[len - 1].tile, roadList[len - 2].tile, roadVehicleType, isConnectionBuild, isConnectionBuild)) {
				Log.logError("BuildRoadAction: Road station couldn't be build! " + AIError.GetLastErrorString());
				if (isConnectionBuild)
					connection.pathInfo.roadList = originalRoadList;
				else
					connection.forceReplan = true;				
			return false;
		}
		
		connection.pathInfo.nrRoadStations++;

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not to near each
		// other.
		if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {

			local stationType = roadVehicleType == AIRoad.ROADVEHTYPE_TRUCK ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
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

			local otherDepot = BuildDepot(roadList, 3, 1);
			if (otherDepot == null)
				return false;

			connection.pathInfo.depotOtherEnd = otherDepot;
		}
	}
	
	// We must make sure that the original road list is restored because we join the new
	// road station with the existing one, but OpenTTD only recognices the original one!
	// If we don't do this all vehicles which are build afterwards get wrong orders and
	// the AI fails :(.
	if (isConnectionBuild)
		connection.pathInfo.roadList = originalRoadList;
	// We only specify a connection as build if both the depots and the roads are build.
	else
		connection.UpdateAfterBuild(AIVehicle.VT_ROAD, roadList[len - 1].tile, roadList[0].tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
	if (!connection.pathInfo.refittedForArticulatedVehicles &&
	    AIEngine.IsArticulated(transportingEngineID))
	{
		assert(buildRoadStations);
		connection.pathInfo.refittedForArticulatedVehicles = true;
	}

	connection.lastChecked = AIDate.GetCurrentDate();
	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	return true;
}

function BuildRoadAction::BuildRoadStation(connection, roadStationTile, frontRoadStationTile, roadVehicleType, isConnectionBuild, joinAdjacentStations) {
	
	// Determine which kind of road station we are looking for. This depends if the 
	// vehicle type to be constructed is articulated or not.
	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_ROAD);
	assert (bestEngineIDs != null);
	local transportingEngineID = bestEngineIDs[0];
	
	if (AIEngine.IsArticulated(transportingEngineID))
	{
		if (!AIRoad.IsDriveThroughRoadStationTile(roadStationTile) && 
			!AIRoad.BuildDriveThroughRoadStation(roadStationTile, frontRoadStationTile, roadVehicleType, joinAdjacentStations ? AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW)) {
			return false;
		}
	} else {
		if (!AIRoad.IsRoadStationTile(roadStationTile) && 
			!AIRoad.BuildRoadStation(roadStationTile, frontRoadStationTile, roadVehicleType, joinAdjacentStations ? AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW)) {
			return false;
		}
	}

	return AIStation.IsValidStation(AIStation.GetStationID(roadStationTile));
}

function BuildRoadAction::BuildDepot(roadList, startPoint, searchDirection) {

	local len = roadList.len();
	local depotLocation = null;
	local depotFront = null;

	// Look for a suitable spot and test if we can build there.
	for (local i = startPoint; i > 1 && i < len - 1; i += searchDirection) {
			
		foreach (direction in directions) {
			if (direction == roadList[i].direction || direction == -roadList[i].direction)
				continue;
			if (Tile.IsBuildable(roadList[i].tile + direction, false) && AIRoad.CanBuildConnectedRoadPartsHere(roadList[i].tile, roadList[i].tile + direction, roadList[i + 1].tile)) {
				
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
					} else
						break;
				}
			}
		}
		
		if (depotLocation != null)
			return depotLocation;
	}

	return null;
}
