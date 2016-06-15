/**
 * Action class for the creation of roads.
 */
class BuildRoadAction extends BuildConnectionAction
{
	buildDepot = false;        // Should we create a depot?
	buildRoadStations = false; // Should we build road stations?
	directions = null;         // A list with all directions.

	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, buildDepot, buildRoadStations) {
		BuildConnectionAction.constructor(connection);
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
	}
}

function BuildRoadAction::FailedToExecute(reason) {
	if (reason != null)
		Log.logError("Failed to build the road connection, because: " + reason);
	
	// If the connection wasn't built before we need to inform the connection that we need to replan because we are unable to built it.
	if (!connection.pathInfo.build)
		connection.forceReplan = true;
}

function BuildRoadAction::Execute() {

	Log.logInfo("Build a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local accounter = AIAccounting();
	
	// Find the best engine for this connection so we know what kind of stations we need to build. In this case we only need 
	// to consider articulated vehicles and 'normal' vehicles. For articulated vehicles we need to build drive through stations.
	// Wormnest: I don't understand why this has to be determined again here. In the report it should
	// have already been decided what engine we want to use so why do it again here.
	// OTOH GetBestTransportingEngine just returns that best engine for the connection unless it can't be built anymore so I guess this is OK.
	// But for new connections I guess the best engine etc hasn't been entered into the connection even if we had a report which told us about the best engine.
	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_ROAD);
	if (bestEngineIDs == null) {
		FailedToExecute("Could not find a suitable engine!");
		return false;
	}
	local transportingEngineID = bestEngineIDs[0];
	local transportingEngineIsArticulated = AIEngine.IsArticulated(transportingEngineID);
	local pathFinderHelper = RoadPathFinderHelper(transportingEngineIsArticulated);
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
	// For existing routs, we want the new path to coher to the existing
	// path as much as possible, therefor we calculate no additional
	// penalties for turns so the pathfinder can find the existing
	// route as quick as possible.
	if (connection.pathInfo.build) {
		pathFinderHelper.costForTurn = pathFinderHelper.costForNewRoad;
		pathFinderHelper.costTillEnd = pathFinderHelper.costForNewRoad;
		pathFinderHelper.costForNewRoad = pathFinderHelper.costForNewRoad * 2;
		pathFinderHelper.costForBridge = pathFinderHelper.costForBridge * 2;
		pathFinderHelper.costForTunnel = pathFinderHelper.costForTunnel * 2;
	}
		
	local connectionPathInfo = null;
	local stationType = (!AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	local bestPathToBuild = null;
	if (connection.pathInfo.build)
		/// @todo The distance may need to be increased if we want to support reusing existing roads more
		/// @todo because that usually means the distance will increase.
		bestPathToBuild = pathFinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false),
			true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	else
		/// @todo The distance may need to be increased if we want to support reusing existing roads more
		/// @todo because that usually means the distance will increase.
		bestPathToBuild = pathFinder.FindFastestRoad(connection.travelFromNode.GetProducingTiles(connection.cargoID, stationRadius, 1, 1),
			connection.travelToNode.GetAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType,
			AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);

	if (bestPathToBuild == null) {
		FailedToExecute("No path found!");
		return false;
	}
	
	// Check if we have enough restapa to build the stations.
	if (buildRoadStations) {
		if (AITown.GetRating(AITile.GetClosestTown(bestPathToBuild.roadList[0].tile), AICompany.COMPANY_SELF) < -200)
			return false;
			
		if (AITown.GetRating(AITile.GetClosestTown(bestPathToBuild.roadList[bestPathToBuild.roadList.len() - 1].tile), AICompany.COMPANY_SELF) < -200)
			return false;	
	}	

	local roadToBuild = bestPathToBuild.roadList;
	local roadListLength = roadToBuild.len();

	// Build the actual road.
	local pathBuilder = PathBuilder(roadToBuild, transportingEngineID);

	if (!pathBuilder.RealiseConnection(buildRoadStations)) {
		FailedToExecute("Failed to build a road " + AIError.GetLastErrorString());
		return false;
	}
		
	if (buildRoadStations) {
		
		local roadVehicleType = AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIRoad.ROADVEHTYPE_BUS : AIRoad.ROADVEHTYPE_TRUCK; 
		if (!BuildRoadStation(transportingEngineIsArticulated, roadToBuild[0].tile, roadToBuild[1].tile, roadVehicleType, true) ||
		    !BuildRoadStation(transportingEngineIsArticulated, roadToBuild[roadListLength - 1].tile, roadToBuild[roadListLength - 2].tile, roadVehicleType, connection.pathInfo.build)) {
			FailedToExecute("Road station couldn't be build! " + AIError.GetLastErrorString());
			return false;
		}
		
		connection.pathInfo.nrRoadStations++;

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not to near each
		// other.
		if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {

			local stationType = roadVehicleType == AIRoad.ROADVEHTYPE_TRUCK ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
			connection.travelFromNode.AddExcludeTiles(connection.cargoID, roadToBuild[roadListLength - 1].tile, AIStation.GetCoverageRadius(stationType));
			connection.travelToNode.AddExcludeTiles(connection.cargoID, roadToBuild[0].tile, AIStation.GetCoverageRadius(stationType));
		}
	}

	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		
		local depot = BuildDepot(roadToBuild, roadListLength - 4, -1);

		if (depot == null) {
			FailedToExecute("Could not build a depot at the loading site! " + AIError.GetLastErrorString());
			return false;
		}

		connection.pathInfo.depot = depot;

		if (connection.bilateralConnection) {

			local otherDepot = BuildDepot(roadToBuild, 3, 1);
			if (otherDepot == null) {
				FailedToExecute("Could not build a depot at the dropoff site! " + AIError.GetLastErrorString());
				return false;
			}

			connection.pathInfo.depotOtherEnd = otherDepot;
		}
	}
	
	// If the build was successful and the connection wasn't build before we add the road list to the path info so we know what road supports
	// the connection for future reference.
	if (!connection.pathInfo.build) {
		connection.pathInfo.roadList = roadToBuild;
		connection.UpdateAfterBuild(AIVehicle.VT_ROAD, roadToBuild[roadListLength - 1].tile, roadToBuild[0].tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));
	}

	// Make it known that the connection can support articulated vehicles if we built drive through stations.
	if (transportingEngineIsArticulated)
		connection.pathInfo.refittedForArticulatedVehicles = true;

	connection.lastChecked = AIDate.GetCurrentDate();
	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	return true;
}

function BuildRoadAction::BuildRoadStation(buildDriveThroughStation, roadStationTile, frontRoadStationTile, roadVehicleType, joinAdjacentStations) {
	
	if (buildDriveThroughStation)
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
