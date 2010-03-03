/**
 * Action class for the creation of rails.
 */
class BuildRailAction extends Action
{
	connection = null;		// Connection object of the rails to build.
	buildDepot = false;		// Should we create a depot?
	buildRailStations = false;	// Should we build rail stations?
	directions = null;		// A list with all directions.
	world = null;			// The world.
	
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
		Action.constructor();
	}
}

function BuildRailAction::Execute() {

	Log.logInfo("Build a rail from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + ".");
	local accounter = AIAccounting();

	if (connection.pathInfo.build) {
		Log.logWarning("We do not support extending existing rail stations, skipping!");
		return false;
	}

	local pathFinderHelper = RailPathFinderHelper();
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
		
	local stationType = (!AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	connection.pathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1), connection.travelToNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	
	if (connection.pathInfo == null) {
		Log.logWarning("Couldn't find a connection to build the rail road!");
		connection.pathInfo = PathInfo(null, null, 0, AIVehicle.VT_RAIL);
		connection.forceReplan = true;
		return false;
	}
	
	// Check if we can build the rail stations.
	if (buildRailStations) {
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(connection.pathInfo.roadList[0].tile), AICompany.COMPANY_SELF) < -200)
			return false;
			
		// Check if we have enough permission to build here.
		if (AITown.GetRating(AITile.GetClosestTown(connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile), AICompany.COMPANY_SELF) < -200)
			return false;	
	}	

	// Build the actual rails.
	local pathBuilder = RailPathBuilder(connection.pathInfo.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);

	if (!pathBuilder.RealiseConnection(buildRailStations)) {
		if (isConnectionBuild)
			connection.pathInfo.roadList = originalRailList;
		else
			connection.forceReplan = true;
		Log.logError("BuildRailAction: Failed to build a rail " + AIError.GetLastErrorString());
		return false;
	}
		
	local roadList = connection.pathInfo.roadList;
	local len = roadList.len();

	if (buildRailStations) {
		local abc = AIExecMode();
		if (!BuildRailStation(connection, roadList[0].tile, roadList[1].tile, false, true, false) ||
			!BuildRailStation(connection, roadList[len - 1].tile, roadList[len - 2].tile, false, false, true)) {
			Log.logError("BuildRailAction: Rail station couldn't be build! " + AIError.GetLastErrorString());
			connection.forceReplan = true;				
			return false;
		}
		
		connection.pathInfo.nrRoadStations++;

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not to near each
		// other.
		if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {

			// TODO: Fix this :)
			//local stationType = roadVehicleType == AIRail.ROADVEHTYPE_TRUCK ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
			//connection.travelFromNode.AddExcludeTiles(connection.cargoID, roadList[len - 1].tile, AIStation.GetCoverageRadius(stationType));
			//connection.travelToNode.AddExcludeTiles(connection.cargoID, roadList[0].tile, AIStation.GetCoverageRadius(stationType));
		}
	}

	// Build the second part. First we try to establish a RoRo Station type. Otherwise we'll connect the two fronts to eachother.
	if (!BuildRoRoStation(stationType, pathFinder)) {
		Log.logWarning("Failed to build the RoRo station...");
		if (!BuildTerminusStation(stationType, pathFinder)) {
			Log.logWarning("Failed to build the Terminus station...");
			return false;
		}
	}
	
	Log.logError("Build depot!");
	// Check if we need to build a depot.	
	if (buildDepot && connection.pathInfo.depot == null) {
		
		local depot = BuildDepot(roadList, len - 10, -1);

		// Check if we could actualy build a depot:
		if (depot == null) {
			Log.logError("Failed to build a depot :(");
			return false;
		}

		connection.pathInfo.depot = depot;

		if (connection.bilateralConnection) {

			depot = BuildDepot(connection.pathInfo.roadListReturn, 10, 1);
			if (depot == null) {
				Log.logError("Failed to build a depot :(");
				return false;
			}

			connection.pathInfo.depotOtherEnd = depot;
		}
	}
	
	// We only specify a connection as build if both the depots and the rails are build.
	connection.UpdateAfterBuild(AIVehicle.VT_RAIL, roadList[len - 1].tile, roadList[0].tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK));

	connection.lastChecked = AIDate.GetCurrentDate();
	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	return true;
}

function BuildRailAction::BuildRailStation(connection, railStationTile, frontRailStationTile, isConnectionBuild, joinAdjacentStations, isStartStation) {
	
	AISign.BuildSign(railStationTile, "Original location");
	
	local direction;
	if (railStationTile - frontRailStationTile < AIMap.GetMapSizeX() &&
	    railStationTile - frontRailStationTile > -AIMap.GetMapSizeX()) {
		direction = AIRail.RAILTRACK_NE_SW;
		
		if (railStationTile - frontRailStationTile == -1)
			railStationTile -= 2;
		
	} else {
		direction = AIRail.RAILTRACK_NW_SE;
		
		if (railStationTile - frontRailStationTile == -AIMap.GetMapSizeX())
			railStationTile -= 2 * AIMap.GetMapSizeX();
	}

	AISign.BuildSign(railStationTile, "Final location");

	if (!AIRail.IsRailStationTile(railStationTile) && 
		!AIRail.BuildRailStation(railStationTile, direction, 2, 3, joinAdjacentStations ? AIStation.STATION_JOIN_ADJACENT : AIStation.STATION_NEW)) {
		AISign.BuildSign(railStationTile, "Couldn't build STATION " + (direction == AIRail.RAILTRACK_NE_SW ? "NE_SW" : "NW_SE"));
		return false;
	} else if (!isConnectionBuild) {
		connection.travelToNodeStationID = AIStation.GetStationID(railStationTile);
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
		
		//AISign.BuildSign(roadList[i].direction, "GIVE IT A TRY! :)");
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
			for (local j = 0; j < railsToBuild.len(); j += 2) {
				if (!AIRail.BuildRailTrack(railsToBuild[j], railsToBuild[j + 1])) {
					problemsWhileBuilding = true;
					break;
				}
			}

			if (problemsWhileBuilding)
				continue;

			if (!AIRail.BuildSignal(railsToBuild[0], depotTile, AIRail.SIGNALTYPE_NORMAL_TWOWAY)) {
				AISign.BuildSign(railsToBuild[0], "NO SIGNAL!??!");
				continue;
			} 
			
			// Remove all signals on the tile between the entry and exit rails.
			if (direction != 1 && direction != -1 && direction != mapSizeX && direction != -mapSizeX) {
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - 1);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile + mapSizeX);
				AIRail.RemoveSignal(roadList[i].tile, roadList[i].tile - mapSizeX);
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
	for (local j = 1; j < 4; j++) {
		for (local i = -3; i < 6; i++) {
			// End station.
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j);
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j);
			
			// Begin station.
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j);
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j);
		}
	}

	local secondPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, tilesToIgnore);
	if (secondPath == null)
		return false;
	
	local pathBuilder = RailPathBuilder(secondPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
	if (!pathBuilder.RealiseConnection(false)) {
		Log.logWarning("Failed to build RoRo-station!");
		return false;
	}
	
	connection.pathInfo.roadListReturn = secondPath.roadList;

	// Now play to connect the other platforms.
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

	assert (startIndex != -1 && returnStartIndex != -1 && endIndex != -1 && returnEndIndex != -1);
	
	BuildSignal(toStartStationPath.roadList[toStartStationPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toStartStationPath.roadList[0], true, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toEndStationPath.roadList[toEndStationPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toEndStationPath.roadList[0], false, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toStartStationReturnPath.roadList[toStartStationReturnPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toStartStationReturnPath.roadList[0], true, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toEndStationReturnPath.roadList[toEndStationReturnPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(toEndStationReturnPath.roadList[0], false, AIRail.SIGNALTYPE_ENTRY);

	// Build the signals.
	BuildSignal(roadList[1], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(roadList[roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	//BuildSignals(roadList, false, 1, 4, AIRail.SIGNALTYPE_NORMAL);
	BuildSignals(roadList, false, startIndex, endIndex, 6, AIRail.SIGNALTYPE_NORMAL);

	BuildSignal(secondPath.roadList[1], false, AIRail.SIGNALTYPE_EXIT);
	BuildSignal(secondPath.roadList[secondPath.roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT);
	//BuildSignals(secondPath.roadList, false, 1, 4, AIRail.SIGNALTYPE_NORMAL);
	BuildSignals(secondPath.roadList, false, returnStartIndex, returnEndIndex, 6, AIRail.SIGNALTYPE_NORMAL);
	return true;
}

function BuildRailAction::BuildTerminusStation(stationType, pathFinder) {
	
	local roadList = connection.pathInfo.roadList;

	local endOrthogonalDirection = (roadList[0].tile - roadList[1].tile == 1 || roadList[0].tile - roadList[1].tile == -1) ? AIMap.GetMapSizeX() : 1;
	local startOrthogonalDirection = (roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == 1 || roadList[roadList.len() - 1].tile - roadList[roadList.len() - 2].tile == -1) ? AIMap.GetMapSizeX() : 1;

	// If we failed to do so, we will now connect the two front ends.
	local beginNodes = AITileList();
	beginNodes.AddTile(roadList[roadList.len() - 1].tile + startOrthogonalDirection);
	AISign.BuildSign(roadList[roadList.len() - 1].tile + startOrthogonalDirection, "?");

	local endNodes = AITileList();
	endNodes.AddTile(roadList[0].tile + endOrthogonalDirection);
	AISign.BuildSign(roadList[0].tile + endOrthogonalDirection, "!");	
	
	local tilesToIgnore = [];
	foreach (roadTile in connection.pathInfo.roadList) {
		tilesToIgnore.push(roadTile.tile);
	}

	// Start station.
	for (local j = 1; j < 4; j++) {
		for (local i = -3; i < 6; i++) {
			// End station.
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i + endOrthogonalDirection * j + endOrthogonalDirection);
			tilesToIgnore.push(roadList[0].tile + roadList[0].direction * i - endOrthogonalDirection * j + endOrthogonalDirection);
			
			// Start station.
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i + startOrthogonalDirection * j + startOrthogonalDirection);
			tilesToIgnore.push(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * i - startOrthogonalDirection * j + startOrthogonalDirection);
		}
	}

	local secondPath = pathFinder.FindFastestRoad(beginNodes, endNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, tilesToIgnore);

	if (secondPath == null)
		return false;
			
	local pathBuilder = RailPathBuilder(secondPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
	if (!pathBuilder.RealiseConnection(false))
		return false;
	connection.pathInfo.roadListReturn = secondPath.roadList;
	
	// Now play to connect the other platforms.
	local toStartStationPath = ConnectRailToStation(roadList, secondPath.roadList[0].tile, pathFinder, stationType, false, false);
	if (toStartStationPath == null)
		return false;
	local toStartStationReturnPath = ConnectRailToStation(secondPath.roadList, roadList[0].tile, pathFinder, stationType, false, false);
	if (toStartStationReturnPath == null)
		return false;
	local toEndStationPath = ConnectRailToStation(roadList, secondPath.roadList[secondPath.roadList.len() - 1].tile, pathFinder, stationType, true, true);
	if (toEndStationPath == null)
		return false;
	local toEndStationReturnPath = ConnectRailToStation(secondPath.roadList, roadList[roadList.len() - 1].tile, pathFinder, stationType, true, true);
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
	
	assert(startIndex != -1);
		
	for (local i = 0; i < secondPath.roadList.len(); i++) {
		if (secondPath.roadList[i].tile == toStartStationReturnPath.roadList[0].tile) {
			returnStartIndex = i;
			break;
		}
	}
	assert(returnStartIndex != -1);
	
	local endIndex = -1;
	local returnEndIndex = -1;
	for (local i = roadList.len() - 1; i > -1; i--) {
		if (roadList[i].tile == toEndStationPath.roadList[0].tile) {
			endIndex = i;
			break;
		}
	}
	assert(endIndex != -1);
		
	for (local i = secondPath.roadList.len() - 1; i > -1; i--) {
		if (secondPath.roadList[i].tile == toEndStationReturnPath.roadList[0].tile) {
			returnEndIndex = i;
			break;
		}
	}
	
/*	{
		local sdafs = AIExecMode();
		AISign.BuildSign(roadList[startIndex].tile, "StartIndex");
		AISign.BuildSign(secondPath.roadList[returnStartIndex].tile, "returnStartIndex");
		AISign.BuildSign(roadList[endIndex].tile, "endIndex");
		AISign.BuildSign(secondPath.roadList[returnEndIndex].tile, "returnEndIndex");
	}
*/
	assert (startIndex != -1 && returnStartIndex != -1 && endIndex != -1 && returnEndIndex != -1);

	BuildSignal(toEndStationPath.roadList[0], false, AIRail.SIGNALTYPE_ENTRY);
	BuildSignal(toStartStationReturnPath.roadList[toStartStationReturnPath.roadList.len() - 1], true, AIRail.SIGNALTYPE_ENTRY);

	// Build the signals.
	//BuildSignals(roadList, false, 1, 4, AIRail.SIGNALTYPE_NORMAL);
	BuildSignal(roadList[1], false, AIRail.SIGNALTYPE_EXIT_TWOWAY);
	BuildSignal(roadList[roadList.len() - 2], false, AIRail.SIGNALTYPE_EXIT_TWOWAY);
	BuildSignals(roadList, false, startIndex, endIndex, 6, AIRail.SIGNALTYPE_NORMAL);
	
	//BuildSignals(secondPath.roadList, true, 1, 4, AIRail.SIGNALTYPE_NORMAL);
	BuildSignal(secondPath.roadList[1], true, AIRail.SIGNALTYPE_EXIT_TWOWAY);
	BuildSignal(secondPath.roadList[secondPath.roadList.len() - 2], true, AIRail.SIGNALTYPE_EXIT_TWOWAY);
	BuildSignals(secondPath.roadList, true, returnStartIndex, returnEndIndex, 6, AIRail.SIGNALTYPE_NORMAL);

	return true;
}

function BuildRailAction::ConnectRailToStation(connectingRoadList, stationPoint, pathFinder, stationType, reverse, buildFromEnd) {
	
	// Now play to connect the other platforms.
	local beginNodes = AITileList();
	for (local a = 3; a < 20; a++)
	//local a = 20;
		beginNodes.AddTile(connectingRoadList[(reverse ? connectingRoadList.len() - a : a)].tile);
	
	local endNodes = AITileList();
	endNodes.AddTile(stationPoint);
	//AISign.BuildSign(connectingRoadList[(reverse ? connectingRoadList.len() - a : a)].tile, "BEGIN NODE");
	///AISign.BuildSign(stationPoint, "END NODE");
	pathFinder.pathFinderHelper.Reset();
	pathFinder.pathFinderHelper.costForTurn = 0;
	pathFinder.pathFinderHelper.costForRail = 300;
	pathFinder.pathFinderHelper.costForNewRail = 300;
	pathFinder.pathFinderHelper.costTillEnd = 0;
	
	local toPlatformPath;
	//if (buildFromEnd)
		toPlatformPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	//else
	//	toPlatformPath = pathFinder.FindFastestRoad(beginNodes, endNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	if (toPlatformPath != null) {
		local pathBuilder = RailPathBuilder(toPlatformPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
		pathBuilder.RealiseConnection(false);

		//BuildSignal(toPlatformPath.roadList[toPlatformPath.roadList.len() - 2], !reverse, AIRail.SIGNALTYPE_EXIT);
		//BuildSignal(toPlatformPath.roadList[0], !reverse, AIRail.SIGNALTYPE_ENTRY);
	} else {
		Log.logError("Failed to connect a rail piece to the rail station.");
		return null;
	}
	connection.pathInfo.extraRoadBits.push(toPlatformPath.roadList);
	
	return toPlatformPath;
}

function BuildRailAction::BuildSignals(roadList, reverse, startIndex, endIndex, spread, signalType) {

	local abc = AIExecMode();
	//AISign.BuildSign(roadList[startIndex].tile, "SIGNALS FROM HERE");
	//AISign.BuildSign(roadList[endIndex].tile, "SIGNALS TILL HERE");
	local singleRail = array(256);
	singleRail[1] = true;
	singleRail[2] = true;
	singleRail[4] = true;
	singleRail[8] = true;
	singleRail[16] = true;
	singleRail[32] = true;
	singleRail[64] = true;
	singleRail[128] = true;
	singleRail[255] = true;

	// Now build the signals.
	local tilesAfterCrossing = spread;
	for (local a = startIndex; a < endIndex; a++) {
		
		// Only build a signal every so many steps, or if we're facing a crossing.
		// Because we are moving from the end station to the begin station, we need
		// to check if the previous tile was a crossing.

		local isTileBeforeCrossing = false;
		// Check if the next tile is a crossing.
		if (!singleRail[AIRail.GetRailTracks(roadList[a + 1].tile)]) {
			tilesAfterCrossing = 0;
			AISign.BuildSign(roadList[a + 1].tile, "CROSSING");
			isTileBeforeCrossing = true;
		}

		if (++tilesAfterCrossing > spread && (a - startIndex) % spread == 0 || isTileBeforeCrossing)
			BuildSignal(roadList[a], reverse, signalType);
	}
}

function BuildRailAction::BuildSignal(roadAnnotatedTile, reverse, signalType) {
	local direction = (reverse ? -roadAnnotatedTile.direction : roadAnnotatedTile.direction);
	//local direction = roadList[a].direction;
	local nextTile = 0;
	if (direction == AIMap.GetMapSizeX() || direction == -AIMap.GetMapSizeX() || direction == 1 || direction == -1)
		nextTile = roadAnnotatedTile.tile + direction;
		
	// Going South.
	else if (direction == AIMap.GetMapSizeX() + 1) {
		if (roadAnnotatedTile.lastBuildRailTrack == AIRail.RAILTRACK_NW_SW)
			nextTile = roadAnnotatedTile.tile + 1;
		else
			nextTile = roadAnnotatedTile.tile + AIMap.GetMapSizeX();
	}
	// Going North.
	else if (direction == -AIMap.GetMapSizeX() - 1) {
		if (roadAnnotatedTile.lastBuildRailTrack == AIRail.RAILTRACK_NW_SW)
			nextTile = roadAnnotatedTile.tile - AIMap.GetMapSizeX();
		else
			nextTile = roadAnnotatedTile.tile - 1;
	}
	// Going West.
	else if (direction == -AIMap.GetMapSizeX() + 1) {
		if (roadAnnotatedTile.lastBuildRailTrack == AIRail.RAILTRACK_NW_NE)
			nextTile = roadAnnotatedTile.tile - AIMap.GetMapSizeX();
		else				
			nextTile = roadAnnotatedTile.tile + 1;
	}
	// Going East.
	else if (direction == AIMap.GetMapSizeX() - 1) {
		if (roadAnnotatedTile.lastBuildRailTrack == AIRail.RAILTRACK_NW_NE)
			nextTile = roadAnnotatedTile.tile - 1;
		else
			nextTile = roadAnnotatedTile.tile + AIMap.GetMapSizeX();
	}

	if (AIRail.GetSignalType(roadAnnotatedTile.tile, nextTile) == AIRail.SIGNALTYPE_NONE)
		AIRail.BuildSignal(roadAnnotatedTile.tile, nextTile, signalType);	
}
