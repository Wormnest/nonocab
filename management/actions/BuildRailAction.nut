/**
 * Action class for the creation of rails.
 */
class BuildRailAction extends BuildConnectionAction
{
	buildDepot = false;         // Should we create a depot?
	buildRailStations = false;  // Should we build rail stations?
	directions = null;          // A list with all directions.
	stationsConnectedTo = null; // The stations we've shared a connection with.
	railStationFromTile = -1;   // The location of the rail station at the source location.
	railStationToTile = -1;     // The location of the rail station at the dropoff location.
	transportingEngineID = null; // Cache transportingEngineID.
	
	static TERRAFORM_TILES = 4; // Number of tiles to terraform in front and back of station (originally 3).
	static STATION_LENGTH  = 3; // Length in tiles of station.
	static STATION_PLATFORMS = 2; // Number of platforms per station.
	
	/**
	 * @param connection The connection object with info about the connection we need to build.
	 * @param buildDepot Should we build a depot or not.
	 * @param buildRailStaions Should we build rail stations or not.
	 */
	constructor(connection, buildDepot, buildRailStations) {
		BuildConnectionAction.constructor(connection);
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.buildDepot = buildDepot;
		this.buildRailStations = buildRailStations;
		stationsConnectedTo = [];
		railStationFromTile = -1;
		railStationToTile = -1;
	}
}

function BuildRailAction::Execute() {

	Log.logInfo("Build rail tracks from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local accounter = AIAccounting();

	if (connection.pathInfo.build) {
		
		FailedToExecute("We do not support extending existing rail stations, skipping!");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		return false;
	}

	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_RAIL);
	if (bestEngineIDs == null) {
		FailedToExecute("Could not find a suitable engine!");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		return false;
	}
	transportingEngineID = bestEngineIDs[0];
	local bestRailType = TrainConnectionAdvisor.GetBestRailType(transportingEngineID);
	local pathFinderHelper = RailPathFinderHelper(bestRailType);
	pathFinderHelper.updateClosedList = false
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
	
	local stationType = AIStation.STATION_TRAIN;
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	pathFinderHelper.startAndEndDoubleStraight = true;
	//pathFinderHelper.costForTurn = 20;
	
	/// @todo doing complete pathfinding here seems like a waste of time if we don't use the result except for the station building.
	pathFinder.pathFinderHelper.PathType = RailPathFinderHelper.PATH_TYPE_PRE;
	local prePathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1),
		connection.travelToNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType,
		AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	
	if (prePathInfo == null) {
		FailedToExecute("Could not find a path for rail.");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		connection.forceReplan = true;
		return false;
	}

	local roadList = prePathInfo.roadList;
	local len = roadList.len();
	local tilesToIgnore = null;
	
	// Check if we can build the rail stations.
	if (buildRailStations) {
		
		// Check if we can get permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(roadList[0].tile), AICompany.COMPANY_SELF) < -200) {
			FailedToExecute("Authorities do not like us. Can't build rail station.");
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
			return false;
		}
			
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(roadList[roadList.len() - 1].tile), AICompany.COMPANY_SELF) < -200) {
			FailedToExecute("Authorities do not like us. Can't build rail station.");
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
			return false;
		}

		local abc = AIExecMode();
		Log.logInfo("Building rail stations.")
		local stationBuildingFailed = false;
		if (!BuildRailStation(connection, roadList[0].tile, roadList[1].tile, false, false, false))
			stationBuildingFailed = true;
		else if(!BuildRailStation(connection, roadList[len - 1].tile, roadList[len - 2].tile, false, false, true)) {
			stationBuildingFailed = true;
			AITile.DemolishTile(roadList[0].tile);
		}
		
		if (stationBuildingFailed) {
			FailedToExecute("BuildRailAction: Rail station couldn't be built! " + AIError.GetLastErrorString());
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
			return false;
		}
		
		// Save the locations of the rail stations so we can remove them later if needed.
		railStationFromTile = roadList[len - 1].tile;
		railStationToTile = roadList[0].tile;
		
		// After building the stations make sure the rail approaches the station correctly.
		local endOrthogonalDirection = (roadList[0].tile - roadList[1].tile == 1 || roadList[0].tile - roadList[1].tile == -1) ?
			AIMap.GetMapSizeX() : 1;
		local startOrthogonalDirection = (roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == 1 ||
			roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == -1) ? AIMap.GetMapSizeX() : 1;
		
		tilesToIgnore = [];
		// Start station.
		for (local j = 1; j < STATION_LENGTH; j++) {
			for (local i = -2; i < STATION_LENGTH+2; i++) {
				// End station.
				tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j);
				tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j);
				
				// Begin station.
				tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j);
				tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j);
			}
		}
		
		connection.pathInfo.nrRoadStations++;
	}
	
	local beginNodes = AITileList();
	beginNodes.AddTile(roadList[len - 1].tile);
	local endNodes = AITileList();
	endNodes.AddTile(roadList[0].tile);
	//AISign.BuildSign(roadList[len - 1].tile, "0");
	//AISign.BuildSign(roadList[0].tile, "1");
	pathFinder.pathFinderHelper.PathType = RailPathFinderHelper.PATH_TYPE_FIRST;
	connection.pathInfo = pathFinder.FindFastestRoad(beginNodes, endNodes, false, false, stationType,
		AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.3 + 20, tilesToIgnore);

	if (connection.pathInfo == null) {
		if (buildRailStations) {
			local ex = AIExecMode();
			AITile.DemolishTile(roadList[0].tile);
			AITile.DemolishTile(roadList[len - 1].tile);
		}
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		FailedToExecute("Couldn't find a connection to build the rail road!");
		return false;
	}
	roadList = connection.pathInfo.roadList;
	len = roadList.len();

	// Build the actual rails.
	local pathBuilder = RailPathBuilder(connection.pathInfo.roadList, transportingEngineID);
	pathBuilder.stationIDsConnectedTo = [AIStation.GetStationID(railStationFromTile), AIStation.GetStationID(railStationToTile)];
	if (!pathBuilder.RealiseConnection(false/*buildRailStations*/)) { // Since stations are already built here we should use false.
		connection.forceReplan = true;
		if (pathBuilder.lastBuildIndex != -1)
			connection.pathInfo.roadList = connection.pathInfo.roadList.slice(pathBuilder.lastBuildIndex);
		else
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		FailedToExecute("BuildRailAction: Failed to build a rail " + AIError.GetLastErrorString());
		return false;
	}
	
	stationsConnectedTo = pathBuilder.stationIDsConnectedTo;

	// Build the return parth using a RoRo station type.
	/// @todo If building a roro station fails we could try to build a station with entrance and exit on the same side.
	if (!BuildRoRoStation(stationType, pathFinder)) {
		FailedToExecute("Failed to build the RoRo station and return path...");
		return false;
	}
	
	Log.logDebug("Build depots!");
	// Check if we need to build a depot.
	if (buildDepot && connection.pathInfo.depot == null) {
		
		local depot = BuildDepot(roadList, len - 10, -1);

		// Check if we could actualy build a depot:
		if (depot == null) {
			// Since we already built a lot of give it another try starting a little farther away from the station
			depot = BuildDepot(roadList, len - 20, -1);
			if (depot == null) {
				// Still a failure: we give up.
				FailedToExecute("Failed to build a depot.");
				return false;
			}
		}

		connection.pathInfo.depot = depot;

		local otherDepot = BuildDepot(connection.pathInfo.roadListReturn, connection.pathInfo.roadListReturn.len() - 10, -1);
		if (otherDepot == null) {
			// Since we already built a lot of give it another try starting a little farther away from the station
			otherDepot = BuildDepot(connection.pathInfo.roadListReturn, connection.pathInfo.roadListReturn.len() - 20, -1);
			if (otherDepot == null) {
				// Still a failure: we give up.
				FailedToExecute("Failed to build a depot.");
				return false;
			}
		}

		connection.pathInfo.depotOtherEnd = otherDepot;
	}
	
	// We only declare a connection built if both the depots and the rails are built.
	connection.UpdateAfterBuild(AIVehicle.VT_RAIL, roadList[len - 1].tile, roadList[0].tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));

	connection.lastChecked = AIDate.GetCurrentDate();
	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	
	// Now that everything is built, make sure the connections we share a rail with are linked.
	local connectionManager = connection.connectionManager;
	foreach (station in stationsConnectedTo) {
		local connectionConnectedTo = connectionManager.GetConnection(station);
		if (connectionConnectedTo == null) {
			Log.logWarning("Station " + station + " is not linked to a connection! Probably caused by an incomplete savegame.");
			Log.logWarning("We wanted to connect it with connection " + connection.ToString());
		}
		else
			connectionManager.MakeInterconnected(connection, connectionConnectedTo);
	}
	
	return true;
}

function BuildRailAction::CleanupTile(at) {
	
	// If the tile we are asked to remove has been marked as already built it means that the piece of rail to
	// destroy is part of another rail network and cannot be removed lest we disrupt that other connection. Similarly
	// if the rail is crossing a road we will not remove it, because it might disrupt a road network.
	if (at.alreadyBuild || AIRoad.IsRoadTile(at.tile))
		return;

	local railTracks = AIRail.GetRailTracks(at.tile);
	if (at.type != Tile.ROAD) {
		local cnt = 0;
		while (!AITile.DemolishTile(at.tile)) {
			cnt++;
			if (cnt == 10)
				break;
			AIController.Sleep(10);
		}
		if (cnt == 10)
			Log.logError("We failed to remove a piece of track at tile " + at.tile + ", railtrack = " + at.lastBuildRailTrack);
	}
	else {
		if (at.lastBuildRailTrack != -1) {
			local cnt = 0;
			while (!AIRail.RemoveRailTrack(at.tile, at.lastBuildRailTrack)) {
				cnt++;
				if (cnt == 10)
					break;
				AIController.Sleep(10);
			}
			if (cnt == 10)
				Log.logError("We failed to remove a piece of track at tile " + at.tile + ", railtrack = " + at.lastBuildRailTrack);
		}
	}
}

function BuildRailAction::CleanupAfterFailure() {
	local test = AIExecMode();
	// Remove all the stations and depots, including all their tiles.
	if (connection.pathInfo == null)
		return;
	assert (!connection.pathInfo.build);
	
	// Destroy the stations.
	if (railStationFromTile != -1)
		AITile.DemolishTile(railStationFromTile);
	if (railStationToTile != -1)
		AITile.DemolishTile(railStationToTile);

	if (connection.pathInfo.roadList) {
		Log.logDebug("Removing rails.");
		foreach (at in connection.pathInfo.roadList) {
			CleanupTile(at);
		}
	}
	
	if (connection.pathInfo.roadListReturn) {
		Log.logDebug("Removing rails for the return track.");
		foreach (at in connection.pathInfo.roadListReturn) {
			CleanupTile(at);
		}
	}
	
	if (connection.pathInfo.extraRoadBits) {
		Log.logDebug("Removing other rail tracks.");
		foreach (extraArray in connection.pathInfo.extraRoadBits) {
			foreach (at in extraArray) {
				CleanupTile(at);
			}
		}
	}
	
	if (connection.pathInfo.depot) {
		Log.logDebug("Removing first depot.");
		AITile.DemolishTile(connection.pathInfo.depot);
	}
	if (connection.pathInfo.depotOtherEnd) {
		Log.logDebug("Removing second depot.");
		AITile.DemolishTile(connection.pathInfo.depotOtherEnd);
	}
}

function BuildRailAction::BuildRailStation(connection, railStationTile, frontRailStationTile, isConnectionBuild, joinAdjacentStations, isStartStation) {
	
	local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
	local direction;
	local terraFormFrom;
	local width;
	local height;
	local min_width;
	local min_height;
	if (railStationTile - frontRailStationTile < AIMap.GetMapSizeX() &&
	    railStationTile - frontRailStationTile > -AIMap.GetMapSizeX()) {
		direction = AIRail.RAILTRACK_NE_SW;
		
		if (railStationTile - frontRailStationTile == -1)
			railStationTile -= STATION_LENGTH-1; // Original 2;
		terraFormFrom = railStationTile - TERRAFORM_TILES;
		min_width = STATION_LENGTH +1;
		width = STATION_LENGTH + 2*TERRAFORM_TILES + 1; // Original: 10
		height = STATION_PLATFORMS;
		min_height = STATION_PLATFORMS;
		
	} else {
		direction = AIRail.RAILTRACK_NW_SE;
		
		if (railStationTile - frontRailStationTile == -AIMap.GetMapSizeX())
			railStationTile -= (STATION_LENGTH-1) * AIMap.GetMapSizeX();
			
		terraFormFrom = railStationTile - TERRAFORM_TILES * AIMap.GetMapSizeX();
		width = STATION_PLATFORMS;
		min_width = STATION_PLATFORMS;
		min_height = STATION_LENGTH + 1;
		height = STATION_LENGTH + 2*TERRAFORM_TILES + 1; // Original: 10
	}

	if (!AIRail.IsRailStationTile(railStationTile))
	{
		local preferedHeight = -1;
		
		if (direction == AIRail.RAILTRACK_NW_SE)
			preferedHeight = Terraform.CalculatePreferedHeight(railStationTile, STATION_PLATFORMS, STATION_LENGTH);
		else
			preferedHeight = Terraform.CalculatePreferedHeight(railStationTile, STATION_LENGTH, STATION_PLATFORMS); 
		Log.logDebug("Terraform station area to height " + preferedHeight);
		if (!Terraform.Terraform(terraFormFrom, width, height, preferedHeight)) {
			// Try terraforming only the station area itself
			Log.logDebug("Terraforming failed. Try only station itself.");
			Terraform.Terraform(terraFormFrom, min_width, min_height, preferedHeight);
		}

		if (connection.travelFromNode.nodeType == "i" &&
		    connection.travelToNode.nodeType == "i")
		{
			if (!AIRail.BuildNewGRFRailStation(railStationTile, direction, STATION_PLATFORMS, STATION_LENGTH, joinAdjacentStations ?
				AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW, connection.cargoID, 
		        AIIndustry.GetIndustryType(connection.travelFromNode.id),
		        AIIndustry.GetIndustryType(connection.travelToNode.id),
		        distance, isStartStation))
		        return false;
		}
		else if(!AIRail.BuildRailStation(railStationTile, direction, STATION_PLATFORMS, STATION_LENGTH, joinAdjacentStations ?
			AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW))
		{
			return false;
		}
	} else if (!isConnectionBuild) {
		if (isStartStation)
			connection.pathInfo.travelFromNodeStationID = AIStation.GetStationID(railStationTile);
		else
			connection.pathInfo.travelToNodeStationID = AIStation.GetStationID(railStationTile);
	}
	return true;
}

/// @todo Terraform depot spot to the same height as where it connects to the main track.
function BuildRailAction::BuildDepot(roadList, startPoint, searchDirection) {

	local len = roadList.len();
	local depotLocation = null;
	local depotFront = null;
	local mapSizeX = AIMap.GetMapSizeX();
	local directions = [1, -1, mapSizeX, -mapSizeX, 1 + mapSizeX, -1 + mapSizeX, 1 - mapSizeX, -1 - mapSizeX];

	// Look for a suitable spot and test if we can build there.
	for (local i = startPoint; i > 1 && i < len - 1; i += searchDirection) {
		if (roadList[i].direction != roadList[i + 1].direction || roadList[i].direction != roadList[i - 1].direction)
			continue;
		
		local directions;
		// Determine which directions we can go to.
		switch (roadList[i].lastBuildRailTrack) {
			 case AIRail.RAILTRACK_NE_SW:
			 	directions = [mapSizeX, -mapSizeX];
			 	break;
			 case AIRail.RAILTRACK_NW_SE:
			 	directions = [1, -1];
			 	break;
			 case AIRail.RAILTRACK_NW_SW:
			 	directions = [1 - mapSizeX];
			 	break;
			 case AIRail.RAILTRACK_NE_SE:
			 	directions = [-1 + mapSizeX];
			 	break;
			 case AIRail.RAILTRACK_NW_NE:
			 	directions = [-1 - mapSizeX];
			 	break;
			 case AIRail.RAILTRACK_SW_SE:
			 	directions = [1 + mapSizeX];
			 	break;
			 default:
			 	assert(false);
		}
		
		foreach (direction in directions) {
			
			local railsToBuild = [];
			local depotTile = null;
			
			// Check if we are going straight.
			if (direction == 1 || direction == -1) {
				depotTile = roadList[i].tile + 2 * direction;
				railsToBuild.push(roadList[i].tile + direction);
				railsToBuild.push(AIRail.RAILTRACK_NE_SW);
				
				if (direction == 1) {
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_SW_SE);
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NW_SW);
				} else {
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NW_NE);
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NE_SE);
				}
			} else if (direction == mapSizeX || direction == -mapSizeX) {
				depotTile = roadList[i].tile + 2 * direction;
				railsToBuild.push(roadList[i].tile + direction);
				railsToBuild.push(AIRail.RAILTRACK_NW_SE);
				
				if (direction == mapSizeX) {
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_SW_SE);
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NE_SE);
				} else {
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NW_NE);
					railsToBuild.push(roadList[i].tile);
					railsToBuild.push(AIRail.RAILTRACK_NW_SW);
				}
			} else {
				if (direction == 1 + mapSizeX) {
					depotTile = roadList[i].tile + mapSizeX + 3;
					railsToBuild.push(roadList[i].tile + mapSizeX + 2);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile + mapSizeX + 1);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile + mapSizeX + 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SW);
					railsToBuild.push(roadList[i].tile + 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile + mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
				} else if (direction == 1 - mapSizeX) {
					depotTile = roadList[i].tile - mapSizeX + 3;
					railsToBuild.push(roadList[i].tile - mapSizeX + 2);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile - mapSizeX + 1);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile - mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile + 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile + 1 - mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_SW_SE);
				} else if (direction == -1 + mapSizeX) {
					depotTile = roadList[i].tile + mapSizeX - 3;
					railsToBuild.push(roadList[i].tile + mapSizeX - 2);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile + mapSizeX - 1);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile + mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile - 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile - 1 + mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_NW_NE);
				} else if (direction == -1 - mapSizeX) {
					depotTile = roadList[i].tile - 1 - 3 * mapSizeX;
					railsToBuild.push(roadList[i].tile - 2 * mapSizeX - 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile - 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile - mapSizeX);
					railsToBuild.push(AIRail.RAILTRACK_NE_SW);
					railsToBuild.push(roadList[i].tile - mapSizeX - 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SE);
					railsToBuild.push(roadList[i].tile - mapSizeX - 1);
					railsToBuild.push(AIRail.RAILTRACK_NW_SW);

				}
			}
			
			if (!AITile.IsBuildable(depotTile) || !AITile.IsBuildable(railsToBuild[0]))
				continue;
			
			// First test to see if we can build everything.
			{
				local test = AITestMode();
				if (!AIRail.BuildRailDepot(depotTile, railsToBuild[0]))
					continue;
				
				local problemsWhileBuilding = false;
				for (local j = 0; j < railsToBuild.len(); j += 2) {
					if (!AIRail.BuildRailTrack(railsToBuild[j], railsToBuild[j + 1])) {
						problemsWhileBuilding = true;
						break;
					}
				}
				
				if (problemsWhileBuilding)
					continue;
			}
			
			// Now do the actual building.
			if (!AIRail.BuildRailDepot(depotTile, railsToBuild[0]))
				continue;
			
			local problemsWhileBuilding = false;
			local depotRails = [];
			for (local j = 0; j < railsToBuild.len(); j += 2) {
				if (!AIRail.BuildRailTrack(railsToBuild[j], railsToBuild[j + 1])) {
					problemsWhileBuilding = true;
					break;
				}
				
				local at = AnnotatedTile();
				at.tile = railsToBuild[j];
				depotRails.push(at);
			}

			if (problemsWhileBuilding)
				continue;

			//if (!AIRail.BuildSignal(railsToBuild[0], depotTile, AIRail.SIGNALTYPE_NORMAL_TWOWAY)) {
			//	AISign.BuildSign(railsToBuild[0], "NO SIGNAL!??!");
			//	continue;
			//}
			connection.pathInfo.extraRoadBits.push(depotRails);
			
			// Remove all signals on the tiles between the entry and exit rails.
			local oneway_path_location;
			if (direction != 1 && direction != -1 && direction != mapSizeX && direction != -mapSizeX) {
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + mapSizeX);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - mapSizeX);
				
				oneway_path_location = i-2
			}
			else
				oneway_path_location = i-1;

			// Build a one way path signal just before the split to the depot. Remove any signal already present at that spot.
			RemoveSignal(roadList[oneway_path_location], searchDirection > 0);
			BuildSignal(roadList[oneway_path_location], searchDirection > 0, AIRail.SIGNALTYPE_PBS_ONEWAY);
			
			depotLocation = depotTile;
			break;
		} // end foreach direction
		
		
		if (depotLocation != null)
			return depotLocation;
	}

	// This is rare but it can happen that we are not able to build a depot.
	Log.logDebug("We failed to find a suitable location to build a depot");
	return null;
}

function BuildRailAction::BuildRoRoStation(stationType, pathFinder) {
	// Build the RoRo station.
	Log.logInfo("Building RoRo station and return path.")
	assert (connection.pathInfo.roadListReturn == null);
	
	local roadList = connection.pathInfo.roadList;
	local endNodes = AITileList();
	endNodes.AddTile(roadList[0].tile + roadList[0].direction * 2);
	//AISign.BuildSign(roadList[0].tile + roadList[0].direction * 2, "0");
	
	local beginNodes = AITileList();
	beginNodes.AddTile(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 2);
	//AISign.BuildSign(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 2, "1");
	
	local tilesToIgnore = [];
	foreach (roadTile in roadList) {
		tilesToIgnore.push(roadTile.tile);
	}
	
	// Force the pathfinder to build a straight rail in front of the station by adding the following tiles to the
	// closed list.
	// XXX XXX XXX XXX
	// === STATION === === ===
	// === STATION === === ===
	// XXX XXX XXX XXX
	
	local endOrthogonalDirection = (roadList[0].tile - roadList[1].tile == 1 || roadList[0].tile - roadList[1].tile == -1) ?
		AIMap.GetMapSizeX() : 1;
	local startOrthogonalDirection = (roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == 1 ||
		roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == -1) ? AIMap.GetMapSizeX() : 1;
	
	// Start station.
	for (local j = 1; j < STATION_LENGTH; j++) {
		for (local i = -2; i < STATION_LENGTH+2; i++) {
			// End station.
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j);
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j);
			
			// Begin station.
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j);
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j);
			
			// Debug signs
			//AISign.BuildSign(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j, "E0");
			//AISign.BuildSign(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j, "E1");
			//AISign.BuildSign(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j, "B0");
			//AISign.BuildSign(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j, "B1");
		}
	}

	// Build the signals.
	BuildSignal(roadList[1], false, AIRail.SIGNALTYPE_NORMAL);
	BuildSignals(roadList, false, 10, roadList.len() - 10, 6, AIRail.SIGNALTYPE_NORMAL);
	// Temporary signal to make sure pathfinding doesn't connect wrong for the second entry platform. This signal can be anything except SIGNALTYPE_NORMAL.
	BuildSignal(roadList[roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);

	Log.logInfo("Find second rail path.")
	pathFinder.pathFinderHelper.startAndEndDoubleStraight = true;
	pathFinder.pathFinderHelper.PathType = RailPathFinderHelper.PATH_TYPE_SECOND;
	local secondPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType,
		AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.4 + 40, tilesToIgnore);
	if (secondPath == null)
		return false;
	Log.logInfo("Build second rail path.")
	
	local pathBuilder = RailPathBuilder(secondPath.roadList, transportingEngineID);
	pathBuilder.stationIDsConnectedTo = [AIStation.GetStationID(railStationFromTile), AIStation.GetStationID(railStationToTile)];
	if (!pathBuilder.RealiseConnection(false)) {

		if (pathBuilder.lastBuildIndex != -1) {
			secondPath.roadList = secondPath.roadList.slice(pathBuilder.lastBuildIndex);
			connection.pathInfo.roadListReturn = secondPath.roadList;
		}
		Log.logWarning("Failed to build second path!");
		return false;
	}
	stationsConnectedTo.extend(pathBuilder.stationIDsConnectedTo);
	
	BuildSignal(secondPath.roadList[1], false, AIRail.SIGNALTYPE_NORMAL);
	BuildSignals(secondPath.roadList, false, 10, secondPath.roadList.len() - 10, 6, AIRail.SIGNALTYPE_NORMAL);
	// Temporary signal to make sure pathfinding doesn't connect wrong for the second entry platform. This signal can be anything except SIGNALTYPE_NORMAL.
	BuildSignal(secondPath.roadList[secondPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	
	connection.pathInfo.roadListReturn = secondPath.roadList;

	Log.logInfo("Connect other platforms.")
	// Now connect the other platforms.
	pathFinder.pathFinderHelper.startAndEndDoubleStraight = false;
	local toStartStationPath = ConnectRailToStation(roadList, roadList[0].tile + endOrthogonalDirection, pathFinder,
		stationType, false, true);
	if (toStartStationPath == null)
		return false;
	local toEndStationPath = ConnectRailToStation(roadList, roadList[roadList.len() - 1].tile + startOrthogonalDirection,
		pathFinder, stationType, true, true);
	if (toEndStationPath == null)
		return false;
	local toStartStationReturnPath = ConnectRailToStation(secondPath.roadList, secondPath.roadList[0].tile + startOrthogonalDirection,
		pathFinder, stationType, false, true);
	if (toStartStationReturnPath == null)
		return false;
	local toEndStationReturnPath = ConnectRailToStation(secondPath.roadList, secondPath.roadList[secondPath.roadList.len() - 1].tile +
		endOrthogonalDirection, pathFinder, stationType, true, true);
	if (toEndStationReturnPath == null)
		return false;

	
	// Figure out the index where the extra rails meet.
	local startIndex = -1;
	local returnStartIndex = -1;
	for (local i = 0; i < roadList.len(); i++) {
		if (roadList[i].tile == toStartStationPath.roadList[0].tile) {
			startIndex = i;
			break;
		}
	}
	
	for (local i = 0; i < secondPath.roadList.len(); i++) {
		if (secondPath.roadList[i].tile == toStartStationReturnPath.roadList[0].tile) {
			returnStartIndex = i;
			break;
		}
	}
	
	local endIndex = -1;
	local returnEndIndex = -1;
	for (local i = roadList.len() - 1; i > -1; i--) {
		if (roadList[i].tile == toEndStationPath.roadList[0].tile) {
			endIndex = i;
			break;
		}
	}
		
	for (local i = secondPath.roadList.len() - 1; i > -1; i--) {
		if (secondPath.roadList[i].tile == toEndStationReturnPath.roadList[0].tile) {
			returnEndIndex = i;
			break;
		}
	}

	// Remove the intermediate signals.
	RemoveSignals(roadList, false, 2, startIndex);
	RemoveSignals(roadList, false, endIndex, roadList.len() - 2);
	
	RemoveSignals(secondPath.roadList, false, 2, returnStartIndex);
	RemoveSignals(secondPath.roadList, false, returnEndIndex, secondPath.roadList.len() - 2);
	
	// Remove the exit signals at station entry needed to block wrong pathfinding.
	RemoveSignal(roadList[roadList.len() - 2], false);
	RemoveSignal(secondPath.roadList[secondPath.roadList.len() - 2], false);

	/// @todo Handle when these signals can't be built.

	// Exit of destination station
	BuildSignal(toStartStationPath.roadList[toStartStationPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_NORMAL);
	BuildSignal(toStartStationPath.roadList[0], true, AIRail.SIGNALTYPE_NORMAL);
	// Entry of source station
	BuildSignal(toEndStationPath.roadList[0], false, AIRail.SIGNALTYPE_PBS_ONEWAY);

	// And now the same for the return path
	BuildSignal(toStartStationReturnPath.roadList[toStartStationReturnPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_NORMAL);
	BuildSignal(toStartStationReturnPath.roadList[0], true, AIRail.SIGNALTYPE_NORMAL);
	BuildSignal(toEndStationReturnPath.roadList[0], false, AIRail.SIGNALTYPE_PBS_ONEWAY);

	return true;
}

function BuildRailAction::ConnectRailToStation(connectingRoadList, stationPoint, pathFinder, stationType, reverse, buildFromEnd) {
	
	// Connect the other platforms.
	local beginNodes = AITileList();
	local maxLength = connectingRoadList.len() - 2;
	if (maxLength > 20)
		maxLength = 20;
	for (local a = 2; a < maxLength; a++)
		beginNodes.AddTile(connectingRoadList[(reverse ? connectingRoadList.len() - a : a)].tile);
	
	local endNodes = AITileList();
	endNodes.AddTile(stationPoint);
	//AISign.BuildSign(connectingRoadList[(reverse ? connectingRoadList.len() - a : a)].tile, "BEGIN NODE");
	///AISign.BuildSign(stationPoint, "END NODE");
	//if (reverse)
	//	AISign.BuildSign(connectingRoadList[connectingRoadList.len()-2].tile, "R");
	//else
	//	AISign.BuildSign(connectingRoadList[2].tile, "N");
	//AISign.BuildSign(stationPoint, "E");
	pathFinder.pathFinderHelper.Reset();
	pathFinder.pathFinderHelper.reverseSearch = !reverse;
	pathFinder.pathFinderHelper.costForTurn = 0;
	pathFinder.pathFinderHelper.costForRail = 300;
	pathFinder.pathFinderHelper.costForNewRail = 300;
	pathFinder.pathFinderHelper.costTillEnd = 0;
	pathFinder.pathFinderHelper.startAndEndDoubleStraight = false;
	
	local toPlatformPath;
	pathFinder.pathFinderHelper.PathType = RailPathFinderHelper.PATH_TYPE_PRE;
	pathFinder.pathFinderHelper.AllowNonSharedRailTracking = false;
	toPlatformPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, 30, null);
	pathFinder.pathFinderHelper.AllowNonSharedRailTracking = true;
	pathFinder.pathFinderHelper.reverseSearch = false;

	if (toPlatformPath != null) {
		local pathBuilder = RailPathBuilder(toPlatformPath.roadList, transportingEngineID);
		pathBuilder.stationIDsConnectedTo = [AIStation.GetStationID(railStationFromTile), AIStation.GetStationID(railStationToTile)];
		if (!pathBuilder.RealiseConnection(false)) {
			//AISign.BuildSign(stationPoint, "TO HERE!");
			Log.logError("Failed to connect a rail piece to the rail station.");
			return null;
		}

		//BuildSignal(toPlatformPath.roadList[toPlatformPath.roadList.len() - 2], !reverse, AIRail.SIGNALTYPE_EXIT);
		//BuildSignal(toPlatformPath.roadList[0], !reverse, AIRail.SIGNALTYPE_ENTRY);
	} else {
		//AISign.BuildSign(stationPoint, "TO HERE!");
		Log.logError("Failed to connect a platform to the rail tracks.");
		return null;
	}
	connection.pathInfo.extraRoadBits.push(toPlatformPath.roadList);
	
	return toPlatformPath;
}

function BuildRailAction::IsSingleRailTrack(railTracks) {
	//local railTracks = AIRail.GetRailTracks(tile);
	return railTracks == 1 || railTracks == 2 || railTracks == 4 || railTracks == 8 || railTracks == 16 ||
		railTracks == 32 || railTracks == 64 || railTracks == 128;
}

/// @todo After a bridge or tunnel we add a signal but after that it would be ideal if we continued with the spacing from before the bridge/tunnel as if it hadn't been there.
function BuildRailAction::BuildSignals(roadList, reverse, startIndex, endIndex, spread, signalType) {

	local abc = AIExecMode();
	
	// Signals on rails in N-S and E-W direction vice versa need a different computation since they don't use full tiles.
	// Use a variable here that keeps track of the whole or half track parts we have passed.
	local signal_spread = spread * 2;
	local track_length = signal_spread; // We want a signal to be set right at the start position.

	// Now build the signals.
	for (local a = startIndex; a < endIndex; a++) {

		local isTileBeforeCrossing = false;
		local needSignal = false;
		
		// Only build a signal every so many steps, or if we're facing a crossing.
		// Because we are moving from the end station to the begin station, we need
		// to check if the previous tile was a crossing.

		// Don't build signals on tunnels or bridges.
		if (roadList[a].type != Tile.ROAD) {
			continue;
		}

		// Check if the previous or next tile was a bridge / tunnel.
		if (roadList[a - 1].type != Tile.ROAD || roadList[a + 1].type != Tile.ROAD) {
			needSignal = true;
		}
		else {
			// Get railtracks for next track piece
			local railTracks = AIRail.GetRailTracks(roadList[a + 1].tile);
			// Check if the next tile is a crossing
			if (roadList[a + 1].type == Tile.ROAD && RailPathFinderHelper.DoRailsCross(roadList[a + 1].lastBuildRailTrack, (railTracks & ~(roadList[a + 1].lastBuildRailTrack)))) {
				isTileBeforeCrossing = true;
				needSignal = true;
			}
		}
		// Check length of current rail track
		local railTracks = AIRail.GetRailTracks(roadList[a].tile);
		switch (railTracks) {
			case AIRail.RAILTRACK_NW_NE: // Track in the upper corner of the tile (north).
			case AIRail.RAILTRACK_SW_SE: // Track in the lower corner of the tile (south).
			case AIRail.RAILTRACK_NW_SW: // Track in the left corner of the tile (west).
			case AIRail.RAILTRACK_NE_SE: // Track in the right corner of the tile (east).
				// Just a half tile track
				track_length++;
				break;
			default:
				// A whole tile track
				track_length += 2;
		}

		if (track_length >= signal_spread || needSignal) {
			if (!isTileBeforeCrossing || roadList[a].reusedPieces != 1)
				BuildSignal(roadList[a], reverse, signalType);
			else { // Just before splitting off from a shared track we put a one way PBS signal
				// In case that track already has a signal remove that first.
				RemoveSignal(roadList[a], reverse);
				BuildSignal(roadList[a], reverse, AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			if (isTileBeforeCrossing) {
				/// @todo In this case we should also check the track we are merging with just before the crossing and add a signal there if necessary.
				track_length = -1;
			}
			else
				track_length = 0;
		}
	}
}

function BuildRailAction::BuildSignal(roadAnnotatedTile, reverse, signalType) {
	local direction = (reverse ? -roadAnnotatedTile.direction : roadAnnotatedTile.direction);
	//local direction = roadList[a].direction;
	local nextTile = GetSignalFrontTile(roadAnnotatedTile.tile, roadAnnotatedTile.lastBuildRailTrack, direction);

	if (AIRail.GetSignalType(roadAnnotatedTile.tile, nextTile) == AIRail.SIGNALTYPE_NONE)
		AIRail.BuildSignal(roadAnnotatedTile.tile, nextTile, signalType);	
}

function BuildRailAction::RemoveSignals(roadList, reverse, startIndex, endIndex) {

	local abc = AIExecMode();

	// Now remove the signals.
	for (local a = startIndex; a < endIndex; a++) {
		
		// Only build a signal every so many steps, or if we're facing a crossing.
		// Because we are moving from the end station to the begin station, we need
		// to check if the previous tile was a crossing.
		RemoveSignal(roadList[a], reverse);
	}
}

function BuildRailAction::RemoveSignal(roadAnnotatedTile, reverse) {
	local direction = (reverse ? -roadAnnotatedTile.direction : roadAnnotatedTile.direction);
	//local direction = roadList[a].direction;
	local nextTile = GetSignalFrontTile(roadAnnotatedTile.tile, roadAnnotatedTile.lastBuildRailTrack, direction);

	//	AISign.BuildSign(roadAnnotatedTile.tile, "RS");
	AIRail.RemoveSignal(roadAnnotatedTile.tile, nextTile);
}

function BuildRailAction::GetSignalFrontTile(tile, railTrack, direction) {
	local nextTile = null;
	if (direction == AIMap.GetMapSizeX() || direction == -AIMap.GetMapSizeX() || direction == 1 || direction == -1)
		nextTile = tile + direction;
		
	// Going South.
	else if (direction == AIMap.GetMapSizeX() + 1) {
		if (railTrack == AIRail.RAILTRACK_NW_SW)
			nextTile = tile + 1;
		else
			nextTile = tile + AIMap.GetMapSizeX();
	}
	// Going North.
	else if (direction == -AIMap.GetMapSizeX() - 1) {
		if (railTrack == AIRail.RAILTRACK_NW_SW)
			nextTile = tile - AIMap.GetMapSizeX();
		else
			nextTile = tile - 1;
	}
	// Going West.
	else if (direction == -AIMap.GetMapSizeX() + 1) {
		if (railTrack == AIRail.RAILTRACK_NW_NE)
			nextTile = tile - AIMap.GetMapSizeX();
		else				
			nextTile = tile + 1;
	}
	// Going East.
	else if (direction == AIMap.GetMapSizeX() - 1) {
		if (railTrack == AIRail.RAILTRACK_NW_NE)
			nextTile = tile - 1;
		else
			nextTile = tile + AIMap.GetMapSizeX();
	}
	return nextTile;
}
