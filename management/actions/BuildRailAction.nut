/**
 * Action class for the creation of rails.
 */
class BuildRailAction extends Action
{
	connection = null;          // Connection object of the rails to build.
	buildDepot = false;         // Should we create a depot?
	buildRailStations = false;  // Should we build rail stations?
	directions = null;          // A list with all directions.
	world = null;               // The world.
	stationsConnectedTo = null; // The stations we've shared a connection with.
	railStationFromTile = -1;   // The location of the rail station at the source location.
	railStationToTile = -1;     // The location of the rail station at the dropoff location.
	
	/**
	 * @param pathList A PathInfo object, the rails to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRailStaions Should rail stations be build?
	 */
	constructor(connection, buildDepot, buildRailStations, world) {
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.connection = connection;
		this.buildDepot = buildDepot;
		this.buildRailStations = buildRailStations;
		this.world = world;
		stationsConnectedTo = [];
		railStationFromTile = -1;
		railStationToTile = -1;
		Action.constructor();
	}
}

function BuildRailAction::Execute() {

	Log.logInfo("Build a rail from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local accounter = AIAccounting();

	if (connection.pathInfo.build) {
		
		assert(false);
		Log.logWarning("We do not support extending existing rail stations, skipping!");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		return false;
	}

///	local bestRailType = TrainConnectionAdvisor.GetBestRailType(world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID]);
	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_RAIL);
	assert (bestEngineIDs != null);
	local transportingEngineID = bestEngineIDs[0];
	local bestRailType = TrainConnectionAdvisor.GetBestRailType(transportingEngineID);
	local pathFinderHelper = RailPathFinderHelper(bestRailType);
	pathFinderHelper.updateClosedList = false
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
		
	local stationType = AIStation.STATION_TRAIN;
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	pathFinderHelper.startAndEndDoubleStraight = true;
	//pathFinderHelper.costForTurn = 20;
	local prePathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1), connection.travelToNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	
	if (prePathInfo == null) {
		Log.logWarning("Couldn't find a connection to build the rail road!");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		connection.forceReplan = true;
		return false;
	}

	//local roadList = connection.pathInfo.roadList;
	local roadList = prePathInfo.roadList;
	local len = roadList.len();
	local tilesToIgnore = null;
	
	// Check if we can build the rail stations.
	if (buildRailStations) {
		
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(roadList[0].tile), AICompany.COMPANY_SELF) < -200) {
			connection.forceReplan = true;
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
			return false;
		}
			
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(roadList[roadList.len() - 1].tile), AICompany.COMPANY_SELF) < -200) {
			connection.forceReplan = true;
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
			return false;
		}

		local abc = AIExecMode();
		local stationBuildingFailed = false;
		if (!BuildRailStation(connection, roadList[0].tile, roadList[1].tile, false, false, false))
			stationBuildingFailed = true;
		else if(!BuildRailStation(connection, roadList[len - 1].tile, roadList[len - 2].tile, false, false, true)) {
			stationBuildingFailed = true;
			AITile.DemolishTile(roadList[0].tile);
		}
		
		if (stationBuildingFailed) {
			Log.logError("BuildRailAction: Rail station couldn't be build! " + AIError.GetLastErrorString());
			connection.forceReplan = true;	
			connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);			
			return false;
		}
		
		// Safe the locations of the rail stations so we can demolish them later.
		railStationFromTile = roadList[len - 1].tile;
		railStationToTile = roadList[0].tile;
		
		// After building the stations make sure the rail approach the station in the right way.
		local endOrthogonalDirection = (roadList[0].tile - roadList[1].tile == 1 || roadList[0].tile - roadList[1].tile == -1) ? AIMap.GetMapSizeX() : 1;
		local startOrthogonalDirection = (roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == 1 || roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == -1) ? AIMap.GetMapSizeX() : 1;
		
		tilesToIgnore = [];
		// Start station.
		for (local j = 1; j < 3; j++) {
			for (local i = -2; i < 5; i++) {
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
	connection.pathInfo = pathFinder.FindFastestRoad(beginNodes, endNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, tilesToIgnore);

	if (connection.pathInfo == null) {
		Log.logWarning("Couldn't find a connection to build the rail road!");
		if (buildRailStations) {
			local ex = AIExecMode();
			AITile.DemolishTile(roadList[0].tile);
			AITile.DemolishTile(roadList[len - 1].tile);
		}
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		connection.forceReplan = true;
		return false;
	}
	roadList = connection.pathInfo.roadList;
	len = roadList.len();

	// Build the actual rails.
	//local pathBuilder = RailPathBuilder(connection.pathInfo.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
	local pathBuilder = RailPathBuilder(connection.pathInfo.roadList, transportingEngineID, world.pathFixer);
	pathBuilder.stationIDsConnectedTo = [AIStation.GetStationID(railStationFromTile), AIStation.GetStationID(railStationToTile)];
	if (!pathBuilder.RealiseConnection(buildRailStations)) {
		connection.forceReplan = true;
		if (pathBuilder.lastBuildIndex != -1)
			connection.pathInfo.roadList = connection.pathInfo.roadList.slice(pathBuilder.lastBuildIndex);
		Log.logError("BuildRailAction: Failed to build a rail " + AIError.GetLastErrorString());
		return false;
	}
	
	stationsConnectedTo = pathBuilder.stationIDsConnectedTo;

	// Build the second part. First we try to establish a RoRo Station type. Otherwise we'll connect the two fronts to eachother.
	if (!BuildRoRoStation(stationType, pathFinder)) {
		Log.logWarning("Failed to build the RoRo station...");
//		if (!BuildTerminusStation(stationType, pathFinder)) {
//			Log.logWarning("Failed to build the Terminus station...");
			connection.forceReplan = true;
			return false;
//		}
	}
	
	Log.logDebug("Build depot!");
	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		
		local depot = BuildDepot(roadList, len - 10, -1);

		// Check if we could actualy build a depot:
		if (depot == null) {
			Log.logError("Failed to build a depot :(");
			connection.forceReplan = true;
			return false;
		}

		connection.pathInfo.depot = depot;

		local otherDepot = BuildDepot(connection.pathInfo.roadListReturn, connection.pathInfo.roadListReturn.len() - 10, -1);
		if (otherDepot == null) {
			Log.logError("Failed to build a depot :(");
			connection.forceReplan = true;
			return false;
		}

		connection.pathInfo.depotOtherEnd = otherDepot;
	}
	
	// We only declare a connection built if both the depots and the rails are build.
	connection.UpdateAfterBuild(AIVehicle.VT_RAIL, roadList[len - 1].tile, roadList[0].tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));

	connection.lastChecked = AIDate.GetCurrentDate();
	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	
	// Now that everything is build, make sure the connections we share a rail with are linked.
	local connectionManager = connection.connectionManager;
	foreach (station in stationsConnectedTo) {
		local connectionConnectedTo = connectionManager.GetConnection(station);
		if (connectionConnectedTo == null) {
			Log.logWarning("WTF!!!" + station + " is not linked to a connection!?");
			assert(false);
		}
		connectionManager.MakeInterconnected(connection, connectionConnectedTo);
	}
	
	return true;
}

function BuildRailAction::CleanupTile(at, considerRemovedTracks) {
	
	// If the tile we are asked to remove has been marked as already built it means that the piece of rail to
	// destroy is part of another rail network and cannot be removed lest we disrupt that other connection. Similary
	// if the rail is crossing a road we will not remove it, because it might disrupt a road network.
	if (at.alreadyBuild || AIRoad.IsRoadTile(at.tile))
		return;

	// Create an inverted bitmap off all the tracks which should already have been
	// removed. By taking the inverted bitmap and applying an ADD operation only
	// the remaining tracks on the tile will be checked. So if this connection built
	// on a tile multiple times also these will be removed! :)
	local additionalTracks = 0;
	if (considerRemovedTracks.rawin(at.tile))
		additionalTracks = considerRemovedTracks.rawget(at.tile);

	local railTracks = AIRail.GetRailTracks(at.tile);
	if (at.type != Tile.ROAD || IsSingleRailTrack(railTracks & (~additionalTracks)))
		while (!AITile.DemolishTile(at.tile));
	else
		considerRemovedTracks[at.tile] <- (additionalTracks | at.lastBuildRailTrack);
}

function BuildRailAction::CleanupAfterFailure() {
	local test = AIExecMode();
	// Remove all the stations and depots build, including all their tiles.
	if (connection.pathInfo == null)
		return;
	assert (!connection.pathInfo.build);
	
	// During demolition we keep track of a list of all tiles which could not be removed
	// because there are more than 1 rail tracks on a tile. We keep track of the rail tiles
	// which should have been removed and when we revisit the same track we will not consider
	// the track which should have been removed the previous time.
	local considerRemovedTracks = {};
	
	// Destroy the stations.
	if (railStationFromTile != -1)
		AITile.DemolishTile(railStationFromTile);
	if (railStationToTile != -1)
		AITile.DemolishTile(railStationToTile);

	if (connection.pathInfo.roadList) {
		Log.logDebug("We have a roadlist!");
		foreach (at in connection.pathInfo.roadList) {
			CleanupTile(at, considerRemovedTracks);
		}
	}
	
	if (connection.pathInfo.roadListReturn) {
		Log.logDebug("We have a roadListReturn!");
		foreach (at in connection.pathInfo.roadListReturn) {
			CleanupTile(at, considerRemovedTracks);
		}
	}
	
	if (connection.pathInfo.extraRoadBits) {
		Log.logDebug("We have a extraRoadBits!");
		foreach (extraArray in connection.pathInfo.extraRoadBits) {
			foreach (at in extraArray) {
				CleanupTile(at, considerRemovedTracks);
			}
		}
	}
	
	if (connection.pathInfo.depot) {
		Log.logDebug("We have a depot!");
		AITile.DemolishTile(connection.pathInfo.depot);
	}
	if (connection.pathInfo.depotOtherEnd) {
		Log.logDebug("We have a depotOtherEnd!");
		AITile.DemolishTile(connection.pathInfo.depotOtherEnd);
	}
//	quit();
}

function BuildRailAction::BuildRailStation(connection, railStationTile, frontRailStationTile, isConnectionBuild, joinAdjacentStations, isStartStation) {
	
	local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
	local direction;
	local terraFormFrom;
	local width;
	local height;
	if (railStationTile - frontRailStationTile < AIMap.GetMapSizeX() &&
	    railStationTile - frontRailStationTile > -AIMap.GetMapSizeX()) {
		direction = AIRail.RAILTRACK_NE_SW;
		
		if (railStationTile - frontRailStationTile == -1)
			railStationTile -= 2;
		terraFormFrom = railStationTile - 3;
		width = 10;
		height = 2;
		
	} else {
		direction = AIRail.RAILTRACK_NW_SE;
		
		if (railStationTile - frontRailStationTile == -AIMap.GetMapSizeX())
			railStationTile -= 2 * AIMap.GetMapSizeX();
			
		terraFormFrom = railStationTile - 3 * AIMap.GetMapSizeX();
		width = 2;
		height = 10;
	}

	if (!AIRail.IsRailStationTile(railStationTile))
	{
		local preferedHeight = -1;
		
		if (direction == AIRail.RAILTRACK_NW_SE)
			preferedHeight = Terraform.CalculatePreferedHeight(railStationTile, 2, 3);
		else
			preferedHeight = Terraform.CalculatePreferedHeight(railStationTile, 3, 2); 
		Terraform.Terraform(terraFormFrom, width, height, preferedHeight);

		if (connection.travelFromNode.nodeType == "i" &&
		    connection.travelToNode.nodeType == "i")
		{
			if (!AIRail.BuildNewGRFRailStation(railStationTile, direction, 2, 3, joinAdjacentStations ? AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW, connection.cargoID, 
		        AIIndustry.GetIndustryType(connection.travelFromNode.id),
		        AIIndustry.GetIndustryType(connection.travelToNode.id),
		        distance, isStartStation))
		        return false;
		}
		else if(!AIRail.BuildRailStation(railStationTile, direction, 2, 3, joinAdjacentStations ? AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW))
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
			
			// No do it for real! :)
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
			
			// Remove all signals on the tile between the entry and exit rails.
			if (direction != 1 && direction != -1 && direction != mapSizeX && direction != -mapSizeX) {
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + mapSizeX);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - mapSizeX);
				
				// Next build a one way signal so trains never get stuck here and no other connection is
				// going to build a signal here!
				BuildSignal(roadList[i], searchDirection > 0, AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			depotLocation = depotTile;
			break;
		}
		
		
		if (depotLocation != null)
			return depotLocation;
	}

	assert(false);
	return null;
}

function BuildRailAction::BuildRoRoStation(stationType, pathFinder) {
	//return false;
	// Build the RoRo station.
	local roadList = connection.pathInfo.roadList;
	local endNodes = AITileList();
	endNodes.AddTile(roadList[0].tile + roadList[0].direction * 2);
	//AISign.BuildSign(roadList[0].tile + roadList[0].direction * 3, "BEGIN RETURN ROUTE");
	
	local beginNodes = AITileList();
	beginNodes.AddTile(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 2);
	//AISign.BuildSign(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 3, "BEGIN RETURN ROUTE");
	
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
	
	local endOrthogonalDirection = (roadList[0].tile - roadList[1].tile == 1 || roadList[0].tile - roadList[1].tile == -1) ? AIMap.GetMapSizeX() : 1;
	local startOrthogonalDirection = (roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == 1 || roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == -1) ? AIMap.GetMapSizeX() : 1;
	
	// Start station.
	for (local j = 1; j < 3; j++) {
		for (local i = -2; i < 5; i++) {
			// End station.
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j);
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j);
			
			// Begin station.
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j);
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j);
		}
	}

	// Build the signals.
	BuildSignal(roadList[1], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(roadList[roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignals(roadList, false, 10, roadList.len() - 10, 6, AIRail.SIGNALTYPE_NORMAL);

	pathFinder.pathFinderHelper.startAndEndDoubleStraight = true;
	local secondPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 40, tilesToIgnore);
	if (secondPath == null)
		return false;
	
	local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_RAIL);
	assert (bestEngineIDs != null);
	local transportingEngineID = bestEngineIDs[0];
	local pathBuilder = RailPathBuilder(secondPath.roadList, transportingEngineID, world.pathFixer);
	//local pathBuilder = RailPathBuilder(secondPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
	//pathBuilder.stationIDsConnectedTo = stationsConnectedTo;
	pathBuilder.stationIDsConnectedTo = [AIStation.GetStationID(railStationFromTile), AIStation.GetStationID(railStationToTile)];
	if (!pathBuilder.RealiseConnection(false)) {

		if (pathBuilder.lastBuildIndex != -1) {
			secondPath.roadList = secondPath.roadList.slice(pathBuilder.lastBuildIndex);
			connection.pathInfo.roadListReturn = secondPath.roadList;
		}
		Log.logWarning("Failed to build RoRo-station!");		
		return false;
	}
	stationsConnectedTo.extend(pathBuilder.stationIDsConnectedTo);
	
	BuildSignal(secondPath.roadList[1], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(secondPath.roadList[secondPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignals(secondPath.roadList, false, 10, secondPath.roadList.len() - 10, 6, AIRail.SIGNALTYPE_NORMAL);
	
	
	connection.pathInfo.roadListReturn = secondPath.roadList;

	// Now play to connect the other platforms.
	pathFinder.pathFinderHelper.startAndEndDoubleStraight = false;
	local toStartStationPath = ConnectRailToStation(roadList, roadList[0].tile + endOrthogonalDirection, pathFinder, stationType, false, true);
	if (toStartStationPath == null)
		return false;
	local toEndStationPath = ConnectRailToStation(roadList, roadList[roadList.len() - 1].tile + startOrthogonalDirection, pathFinder, stationType, true, true);
	if (toEndStationPath == null)
		return false;
	local toStartStationReturnPath = ConnectRailToStation(secondPath.roadList, secondPath.roadList[0].tile + startOrthogonalDirection, pathFinder, stationType, false, true);
	if (toStartStationReturnPath == null)
		return false;
	local toEndStationReturnPath = ConnectRailToStation(secondPath.roadList, secondPath.roadList[secondPath.roadList.len() - 1].tile + endOrthogonalDirection, pathFinder, stationType, true, true);
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
	
	// TODO: Handle when these signals can't be build.
	BuildSignal(toStartStationPath.roadList[toStartStationPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toStartStationPath.roadList[0], true, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toEndStationPath.roadList[toEndStationPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toEndStationPath.roadList[0], false, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toStartStationReturnPath.roadList[toStartStationReturnPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toStartStationReturnPath.roadList[0], true, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toEndStationReturnPath.roadList[toEndStationReturnPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toEndStationReturnPath.roadList[0], false, AIRail.SIGNALTYPE_ENTRY);
	return true;
}

function BuildRailAction::ConnectRailToStation(connectingRoadList, stationPoint, pathFinder, stationType, reverse, buildFromEnd) {
	
	// Now play to connect the other platforms.
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
	pathFinder.pathFinderHelper.Reset();
	pathFinder.pathFinderHelper.reverseSearch = !reverse;
	pathFinder.pathFinderHelper.costForTurn = 0;
	pathFinder.pathFinderHelper.costForRail = 300;
	pathFinder.pathFinderHelper.costForNewRail = 300;
	pathFinder.pathFinderHelper.costTillEnd = 0;
	pathFinder.pathFinderHelper.startAndEndDoubleStraight = false;
	
	local toPlatformPath;
	toPlatformPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, 30, null);
	pathFinder.pathFinderHelper.reverseSearch = false;

	if (toPlatformPath != null) {
		local bestEngineIDs = connection.GetBestTransportingEngine(AIVehicle.VT_RAIL);
		assert (bestEngineIDs != null);
		local transportingEngineID = bestEngineIDs[0];
		
		local pathBuilder = RailPathBuilder(toPlatformPath.roadList, transportingEngineID, world.pathFixer);
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
		Log.logError("Failed to connect a rail piece to the rail station.");
		return null;
	}
	connection.pathInfo.extraRoadBits.push(toPlatformPath.roadList);
	
	return toPlatformPath;
}

function BuildRailAction::IsSingleRailTrack(railTracks) {
	//local railTracks = AIRail.GetRailTracks(tile);
	return railTracks == 1 || railTracks == 2 || railTracks == 4 || railTracks == 8 || railTracks == 16 || railTracks == 32 || railTracks == 64 || railTracks == 128;
}

function BuildRailAction::BuildSignals(roadList, reverse, startIndex, endIndex, spread, signalType) {

	local abc = AIExecMode();
	//AISign.BuildSign(roadList[startIndex].tile, "SIGNALS FROM HERE");
	//AISign.BuildSign(roadList[endIndex].tile, "SIGNALS TILL HERE");

	// Now build the signals.
	local tilesAfterCrossing = spread;
	for (local a = startIndex; a < endIndex; a++) {

		local isTileBeforeCrossing = false;
		if (tilesAfterCrossing < 0) {
			RemoveSignal(roadList[a], true);
			RemoveSignal(roadList[a], false);
			if (tilesAfterCrossing == -1)
				tilesAfterCrossing = spread;
		}
		
		// Only build a signal every so many steps, or if we're facing a crossing.
		// Because we are moving from the end station to the begin station, we need
		// to check if the previous tile was a crossing.

		// Don't build signals on tunnels or bridges.
		if (roadList[a].type != Tile.ROAD)
			continue;

		// Check if the next tile is a crossing or if the previous tile was a bridge / tunnel.
		local railTracks = AIRail.GetRailTracks(roadList[a + 1].tile);
		if (roadList[a - 1].type != Tile.ROAD || roadList[a].type != Tile.ROAD || RailPathFinderHelper.DoRailsCross(roadList[a + 1].lastBuildRailTrack, (railTracks & ~(roadList[a + 1].lastBuildRailTrack)))) {
		//	if (tilesAfterCrossing >= 0)
				isTileBeforeCrossing = true;

			tilesAfterCrossing = -spread;
		}

		if (++tilesAfterCrossing > spread && (a - startIndex) % spread == 0 || isTileBeforeCrossing)
			BuildSignal(roadList[a], reverse, signalType);
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
