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

	local isConnectionBuild = connection.pathInfo.build;
	local newConnection = null;
	local originalRailList = null;

	// If the connection is already build we will try to add additional rail stations.
	if (isConnectionBuild) {
		newConnection = Connection(0, connection.travelFromNode, connection.travelToNode, 0, null);
		originalRailList = clone connection.pathInfo.roadList;
	}

	local pathFinderHelper = RailPathFinderHelper();
	local pathFinder = RoadPathFinding(pathFinderHelper);
	
	// For existing routs, we want the new path to coher to the existing
	// path as much as possible, therefor we calculate no additional
	// penalties for turns so the pathfinder can find the existing
	// route as quick as possible.
	if (isConnectionBuild) {
		pathFinderHelper.costForTurn = pathFinderHelper.costForNewRail;
		pathFinderHelper.costTillEnd = pathFinderHelper.costForNewRail;
		pathFinderHelper.costForNewRail = pathFinderHelper.costForNewRail * 2;
		pathFinderHelper.costForBridge = pathFinderHelper.costForBridge * 2;
		pathFinderHelper.costForTunnel = pathFinderHelper.costForTunnel * 2;
	}
		
	local connectionPathInfo = null;
	local stationType = (!AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	if (!isConnectionBuild)
		connection.pathInfo = pathFinder.FindFastestRoad(connection.travelFromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1), connection.travelToNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	else 
		newConnection.pathInfo = pathFinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false), true, true, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, null);

	// If we need to build additional rail stations we will temporaly overwrite the 
	// road list of the connection with the roadlist which will build the additional
	// rail stations. 
	if (isConnectionBuild) {

		if (newConnection.pathInfo == null)
			return false;

		connection.pathInfo.roadList = newConnection.pathInfo.roadList;
		connection.pathInfo.build = true;
	} else if (connection.pathInfo == null) {
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
		if (!BuildRailStation(connection, roadList[0].tile, roadList[1].tile, isConnectionBuild, true, false) ||
			!BuildRailStation(connection, roadList[len - 1].tile, roadList[len - 2].tile, isConnectionBuild, isConnectionBuild, true)) {
				Log.logError("BuildRailAction: Rail station couldn't be build! " + AIError.GetLastErrorString());
				if (isConnectionBuild)
					connection.pathInfo.roadList = originalRailList;
				else
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

	// Build the RoRo station.
	local endNodes = AITileList();
	endNodes.AddTile(roadList[0].tile + roadList[0].direction * 3);
	//AISign.BuildSign(roadList[0].tile + roadList[0].direction * 3, "BEGIN RETURN ROUTE");
	
	local beginNodes = AITileList();
	beginNodes.AddTile(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 3);
	//AISign.BuildSign(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 3, "BEGIN RETURN ROUTE");
	
	local tilesToIgnore = [];
	foreach (roadTile in connection.pathInfo.roadList) {
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
	
	local switchSignals = false;
	local secondPath = pathFinder.FindFastestRoad(endNodes, beginNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, tilesToIgnore);
	if (secondPath != null) {
		local pathBuilder = RailPathBuilder(secondPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
		if (!pathBuilder.RealiseConnection(false)) {
			Log.logWarning("Failed to build RoRo-station!");
			secondPath = null;
		} else {
			AIRail.BuildRailTrack(roadList[0].tile + roadList[0].direction * 3, (endOrthogonalDirection == 1 ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW));
			AIRail.BuildRailTrack(roadList[roadList.len() - 1].tile - roadList[roadList.len() - 1].direction * 3, (startOrthogonalDirection == 1 ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW));
		}
	} 
	
	if (secondPath == null) {
		// If we failed to do so, we will now connect the two front ends.
		endNodes = AITileList();
		endNodes.AddTile(roadList[0].tile - roadList[0].direction + endOrthogonalDirection);
		AISign.BuildSign(roadList[0].tile - roadList[0].direction + endOrthogonalDirection, "!");
		
		beginNodes = AITileList();
		beginNodes.AddTile(roadList[roadList.len() - 1].tile + roadList[roadList.len() - 1].direction + startOrthogonalDirection);
		AISign.BuildSign(roadList[roadList.len() - 1].tile + roadList[roadList.len() - 1].direction + startOrthogonalDirection, "?");
		
		
		tilesToIgnore = [];
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

		secondPath = pathFinder.FindFastestRoad(beginNodes, endNodes, false, false, stationType, AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation()) * 1.2 + 20, tilesToIgnore);

		if (secondPath != null) {
			local pathBuilder = RailPathBuilder(secondPath.roadList, world.cargoTransportEngineIds[AIVehicle.VT_RAIL][connection.cargoID], world.pathFixer);
			if (!pathBuilder.RealiseConnection(false)) {
				secondPath = null;
				Log.logError("Failed to build a front-to-front station");
			} else {
				AIRail.BuildRailTrack(roadList[0].tile - roadList[0].direction + endOrthogonalDirection, (endOrthogonalDirection == 1 ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW));
				AIRail.BuildRailTrack(roadList[roadList.len() - 1].tile + roadList[roadList.len() - 1].direction + startOrthogonalDirection, (startOrthogonalDirection == 1 ? AIRail.RAILTRACK_NW_SE : AIRail.RAILTRACK_NE_SW));
				switchSignals = true;
			}
		} 
	}
	
	if (secondPath == null) {
		// TODO: Build bypass lane!
		Log.logWarning("Side track not implemented yet!");
		return false;
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
	
	// Build the signals.
	BuildSignals(roadList, false);
	
	if (secondPath != null)
		BuildSignals(secondPath.roadList, switchSignals);
	
	
	// We must make sure that the original road list is restored because we join the new
	// rail station with the existing one, but OpenTTD only recognices the original one!
	// If we don't do this all vehicles which are build afterwards get wrong orders and
	// the AI fails :(.
	if (isConnectionBuild)
		connection.pathInfo.roadList = originalRailList;
	// We only specify a connection as build if both the depots and the rails are build.
	else
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

	// Look for a suitable spot and test if we can build there.
	for (local i = startPoint; i > 1 && i < len; i += searchDirection) {
		
		// Only allow a depot at a piece of the track that goes straight!
		if (roadList[i].lastBuildRailTrack != AIRail.RAILTRACK_NE_SW && roadList[i].lastBuildRailTrack != AIRail.RAILTRACK_NW_SE)
			continue;

		foreach (direction in directions) {
			if (direction == roadList[i].direction || direction == -roadList[i].direction || (roadList[i].direction != 1 && roadList[i].direction != -1 && roadList[i].direction != AIMap.GetMapSizeX() && roadList[i].direction != -AIMap.GetMapSizeX()))
				continue;
			if (Tile.IsBuildable(roadList[i].tile + direction, false) && AIRoad.CanBuildConnectedRoadPartsHere(roadList[i].tile, roadList[i].tile + direction, roadList[i + 1].tile)) {
				
				// Switch to test mode so we don't build the depot, but just test its location.
				{
					local test = AITestMode();
					if (AIRail.BuildRailDepot(roadList[i].tile + direction, roadList[i].tile)) {
						
						
						if (direction == 1) {
							if (!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NE_SW) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_SW_SE) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NW_SW))
									continue;
						} else if (direction == -1) {
							if (!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NE_SW) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NW_NE) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NE_SE))
									continue
						} else if (direction == AIMap.GetMapSizeX()) {
							if (!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NW_SE) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_SW_SE) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NE_SE))
									continue;
						} else if (direction == -AIMap.GetMapSizeX()) {
							if (!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NE_SW) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NW_NE) ||
								!AIRail.BuildRailTrack(roadList[i].tile, AIRail.RAILTRACK_NW_SW))
									continue;
						}						
						
						
						// We can't build the depot instantly, because OpenTTD crashes if we
						// switch to exec mode at this point (stupid bug...).
						depotLocation = roadList[i].tile + direction;
						depotFront = roadList[i].tile;
					}
				}
				
				if (depotLocation) {
					local abc = AIExecMode();
					
/*
RAILTRACK_NE_SW 	Track along the x-axis (north-east to south-west).
RAILTRACK_NW_SE 	Track along the y-axis (north-west to south-east).
RAILTRACK_NW_NE 	Track in the upper corner of the tile (north).
RAILTRACK_SW_SE 	Track in the lower corner of the tile (south).
RAILTRACK_NW_SW 	Track in the left corner of the tile (west).
RAILTRACK_NE_SE 	Track in the right corner of the tile (east). 
*/

					// Build the rails leading to the depot.
					if (direction == 1) {
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NE_SW);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_SW_SE);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NW_SW);
					} else if (direction == -1) {
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NE_SW);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NW_NE);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NE_SE);
					} else if (direction == AIMap.GetMapSizeX()) {
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NW_SE);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_SW_SE);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NE_SE);
					} else if (direction == -AIMap.GetMapSizeX()) {
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NE_SW);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NW_NE);
						AIRail.BuildRailTrack(depotFront, AIRail.RAILTRACK_NW_SW);
					}
					
					// If we found the correct location switch to exec mode and build it.
					// Note that we need to build the road first, else we are unable to do
					// so again in the future.
					if (!AIRail.BuildRailDepot(depotLocation, depotFront)) {
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

function BuildRailAction::BuildSignals(roadList, reverse) {

	local abc = AIExecMode();
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
	local tilesAfterCrossing = 4;
	for (local a = 1; a < roadList.len() - 1; a++) {
		
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

		if (++tilesAfterCrossing > 4 && a % 4 == 0 || isTileBeforeCrossing) {
			
			local direction = (reverse ? -roadList[a].direction : roadList[a].direction);
			//local direction = roadList[a].direction;
			local nextTile = 0;
			if (direction == AIMap.GetMapSizeX() || direction == -AIMap.GetMapSizeX() || direction == 1 || direction == -1)
				nextTile = roadList[a].tile + direction;
				
			// Going South.
			else if (direction == AIMap.GetMapSizeX() + 1) {
				if (roadList[a].lastBuildRailTrack == AIRail.RAILTRACK_NW_SW)
					nextTile = roadList[a].tile + 1;
				else
					nextTile = roadList[a].tile + AIMap.GetMapSizeX();
			}
			// Going North.
			else if (direction == -AIMap.GetMapSizeX() - 1) {
				if (roadList[a].lastBuildRailTrack == AIRail.RAILTRACK_NW_SW)
					nextTile = roadList[a].tile - AIMap.GetMapSizeX();
				else
					nextTile = roadList[a].tile - 1;
			}
			// Going West.
			else if (direction == -AIMap.GetMapSizeX() + 1) {
				if (roadList[a].lastBuildRailTrack == AIRail.RAILTRACK_NW_NE)
					nextTile = roadList[a].tile - AIMap.GetMapSizeX();
				else				
					nextTile = roadList[a].tile + 1;
			}
			// Going East.
			else if (direction == AIMap.GetMapSizeX() - 1) {
				if (roadList[a].lastBuildRailTrack == AIRail.RAILTRACK_NW_NE)
					nextTile = roadList[a].tile - 1;
				else
					nextTile = roadList[a].tile + AIMap.GetMapSizeX();
			}
	
			AIRail.BuildSignal(roadList[a].tile, nextTile, AIRail.SIGNALTYPE_NORMAL);
		}
	}
}
