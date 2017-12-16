class RoadPathFinderHelper extends PathFinderHelper {

	static MAX_ROAD_BRIDGE_LENGTH = 15;
	static MAX_ROAD_TUNNEL_LENGTH = 15;

	costForRoad 	= 50;       // Cost for utilizing an existing road, bridge, or tunnel. (Original: 100)
	costForNewRoad	= 1200;     // Cost for building a new road. (Original: 1000)
	costForTurn 	= 200;      // Additional cost if the road makes a turn. (Original: 200)
	costForBridge 	= 2000;     // Cost for building a bridge. (original: 1250)
	costForTunnel 	= 1750;     // Cost for building a tunnel. (original: 1050)
	costForSlope 	= 500;      // Additional cost if the road heads up or down a slope.
	costTillEnd     = 1200;     // The cost for each tile till the end.

	standardOffsets = null;
	dummyAnnotatedTile = null;
	buildStationsFunction = null;
	buildDriveThroughStations = null;
	
	vehicleType = AIVehicle.VT_ROAD;
	
	constructor(buildDriveThroughStations_) {
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
		
		// If maintenance costs setting is turned on then infrastructure will costs us increasingly more
		// the more we use. Thus make the cost of new roads increasingly expensive here too.
		// Maybe we should also do that for bridges and tunnels?
		if (AIGameSettings.GetValue("infrastructure_maintenance") == 1) {
			// Get the number of road pieces we already have
			local roadpieces = AIInfrastructure.GetRoadPieceCount(AICompany.COMPANY_SELF, AIRoad.ROADTYPE_ROAD);
			costForNewRoad = 1200 + (roadpieces * 2 / 15);
		}

		// Optimalization, use a prefat annotated tile for heuristics.
		dummyAnnotatedTile = AnnotatedTile();
		dummyAnnotatedTile.type = Tile.ROAD;
		dummyAnnotatedTile.parentTile = dummyAnnotatedTile;
		
		SetStationBuilder(buildDriveThroughStations_);
	}
	
	function GetTimeLimit() {
		return 45;	// The maximum time in days we should try to find a path (for roads 45 days should be fine I think).
	}

	/**
	 * By using this function you can configure if the road pathfinder should work
	 * with 'normal' station or drive through stations.
	 * @param buildDriveThroughStations_ Determines if it should build drive through
	 * stations.
	 */
	function SetStationBuilder(buildDriveThroughStations_);

	/**
	 * Search for all tiles which are reachable from the given tile, either by road or
	 * by building bridges and tunnels or exploiting existing onces.
	 * @param currentAnnotatedTile An instance of AnnotatedTile from where to search from.
	 * @param onlyRoads Take only roads into acccount?
	 * @param closedList All tiles which should not be considered.
	 * @return An array of annotated tiles.
	 */
	function GetNeighbours(currentAnnotatedTile, onlyRoads, closedList);

	/**
	 * Get the time it takes a vehicle to travel among the given road.
	 * @param roadList Array of annotated tiles which compounds the road.
	 * @param engineID The ID of the engine being used.
	 * @param forward Traverse the roadList in the given order if true, otherwise 
	 * traverse it from back to the begin.
	 * @return The number of days it takes a vehicle to traverse the given road
	 * with the given maximum speed.
	 */
	function GetTime(roadList, engineID, forward);

	/**
	 * Process all possible start locations and add all start locations to the
	 * given heap.
	 */
	function ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd);

	/**
	 * Process all end positions and update the endList which will be the ultimate list.
	 */
	function ProcessEndPositions(endList, checkEndPositions);

	/**
	 * Check if the given end tile is a valid end tile.
	 */
	function CheckGoalState(at, end, checkEndPosition, closedList);
	
	/**
	 * Search for all bridges which can be build.
	 * @param startTile The start location for the bridge.
	 * @param direction The direction the bridge must head.
	 * @return An array of tile IDs of all possible end points.
	 */
	function GetBridge(startTile, direction);
	
	/**
	 * Search for all tunnels which can be build.
	 * @param startTile The start location for the tunnel.
	 * @param direction The direction the tunnel must head.
	 * @return An array of tile IDs of all possible end points.
	 */	
	function GetTunnel(startTile, direction);	

}

function RoadPathFinderHelper::SetStationBuilder(buildDriveThroughStations_) {
	buildDriveThroughStations = buildDriveThroughStations_;
	if (buildDriveThroughStations)
		buildStationsFunction = AIRoad.BuildDriveThroughRoadStation;
	else
		buildStationsFunction = AIRoad.BuildRoadStation;
}

function RoadPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {

	foreach (i, value in startList) {
	
		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.type = Tile.ROAD;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		// Check if we can actually start here!
		if(checkStartPositions) {
		
			if (!Tile.IsBuildable(i, buildDriveThroughStations) || 
				AITown.GetRating(AITile.GetClosestTown(i), AICompany.COMPANY_SELF) <= -200)
				continue;
			
			// We preprocess all start nodes to see if a road station can be build on them.
			local neighbours = GetNeighbours(annotatedTile, true, emptyList);
			
			// We only consider roads which don't go down hill because we can't build road stations
			// on them!
			foreach (neighbour in neighbours) {
				local slope = Tile.GetSlope(i, neighbour.direction);
				if (slope == 2)
					continue;
					
				neighbour.distanceFromStart += (slope == 0 ? costForRoad : costForSlope);
				neighbour.parentTile = annotatedTile;
				neighbour.length = 1;
				
				heap.Insert(neighbour, AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
			}
		} else
			heap.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * costTillEnd);
	}
}

function RoadPathFinderHelper::ProcessEndPositions(endList, checkEndPositions) {

	local newEndLocations = AITileList();
	
	foreach (i, value in endList) {
		if (checkEndPositions) {
			if (!Tile.IsBuildable(i, buildDriveThroughStations) || 
				AITown.GetRating(AITile.GetClosestTown(i), AICompany.COMPANY_SELF) <= -200)
				continue;
			dummyAnnotatedTile.tile = i;

			// We preprocess all end nodes to see if a road station can be build on them.
			local neighbours = GetNeighbours(dummyAnnotatedTile, true, emptyList);

			// We only consider roads which don't go down hill because we can't build road stations
			// on them!
			foreach (neighbour in neighbours) {
				if (Tile.GetSlope(i, neighbour.direction) == 2)
					continue;
					
				newEndLocations.AddTile(i);
			}
		}
	}

	if (checkEndPositions) {
		endList.Clear();
		endList.AddList(newEndLocations);
	}
}


function RoadPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {

	if (at.type != Tile.ROAD)
		return false;

	// If we need to check the end positions then we either have to be able to build a road station
	// Either the slope is flat or it is downhill, othersie we can't build a depot here
	// Don't allow a tunnel to be near the planned end points because it can do terraforming, there by ruining the prospected location.
	if (checkEndPositions && (!buildStationsFunction(at.tile, at.parentTile.tile, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_JOIN_ADJACENT) ||
		Tile.GetSlope(at.tile, at.direction) == 1 || at.parentTile.type == Tile.TUNNEL)) {

		// Something went wrong, the original end point isn't valid anymore! We do a quick check and remove any 
		// endpoints that aren't valid anymore.
		end.RemoveTile(at.tile);

		// Check the remaining nodes too!
		local listToRemove = AITileList();

		foreach (i, value in end) {

			dummyAnnotatedTile.tile = i;
	
			// We preprocess all end nodes to see if a road station can be build on them.
			local neighbours = GetNeighbours(dummyAnnotatedTile, true, closedList);

			// We only consider roads which don't go down hill because we can't build road stations
			// on them!
			local foundSuitableNeighbour = false;
			foreach (neighbour in neighbours) {
				if (Tile.GetSlope(i, neighbour.direction) != 2) {
					foundSuitableNeighbour = true;
					break;
				}
			}

			if (!foundSuitableNeighbour)
				listToRemove.AddTile(i);
		}

		end.RemoveList(listToRemove);

		if (end.IsEmpty()) {
			Log.logDebug("End list is empty, original goal isn't satisfiable anymore.");
			return null;
		}
		return false;
	}
	return true;
}

function RoadPathFinderHelper::GetNeighbours(currentAnnotatedTile, onlyRoads, closedList) {

	local tileArray = [];
	local offsets;
	
	/**
	 * If the tile we want to build from is a bridge or tunnel, the only acceptable way 
	 * to go is foreward. If we fail to do so the pathfinder will try to build invalid
	 * roadpieces by building over the endpoints of bridges and tunnels.
	 */
	if (currentAnnotatedTile.type == Tile.ROAD && !currentAnnotatedTile.parentTile.forceForward)
		offsets = standardOffsets;
	else
		offsets = [currentAnnotatedTile.direction];

	foreach (offset in offsets) {
		
		// Don't build in the wrong direction.
		if (offset == -currentAnnotatedTile.direction)
			continue;
		
		local currentTile = currentAnnotatedTile.tile;
		local nextTile = currentTile + offset;
		local isInClosedList = false;

		// Skip if this node is already processed.
		if (closedList.rawin(nextTile))
			isInClosedList = true;

		// Check if we can actually build this piece of road or if the slopes render this impossible.
		if (!AIRoad.CanBuildConnectedRoadPartsHere(currentTile, currentAnnotatedTile.parentTile.tile, nextTile))
			continue;

		local isBridgeOrTunnelEntrance = false;
		
		// Check if we can exploit existing bridges and tunnels.
		if (!onlyRoads && AITile.HasTransportType(nextTile, AITile.TRANSPORT_ROAD)) {
			local type = Tile.NONE;
			local otherEnd;
			if (AIBridge.IsBridgeTile(nextTile)) {
				type = Tile.BRIDGE;
				otherEnd = AIBridge.GetOtherBridgeEnd(nextTile);
			} else if (AITunnel.IsTunnelTile(nextTile)) {
				type = Tile.TUNNEL;
				otherEnd = AITunnel.GetOtherTunnelEnd(nextTile);
			}

			if (type != Tile.NONE) {

				local length = otherEnd - nextTile;
				local mapSizeX = AIMap.GetMapSizeX();
				
				// Make sure we're heading in the same direction as the bridge or tunnel we try
				// to connect to, else we end up with false road pieces which try to connect to the
				// side of a bridge.
				if (-length >= mapSizeX && offset == -mapSizeX ||		// North
				     length <  mapSizeX && length > 0 && offset ==  1 ||	// West
				     length >= mapSizeX && offset ==  mapSizeX ||		// South
				    -length <  mapSizeX && length < 0 && offset == -1) {	// East

					if (length > mapSizeX || length < -mapSizeX)
						length /= mapSizeX;
				    
				    if (length < 0)
				    	length = -length;
				    
					local annotatedTile = AnnotatedTile();
					annotatedTile.type = type;
					annotatedTile.direction = offset;
					annotatedTile.tile = otherEnd;
					annotatedTile.alreadyBuild = true;
					annotatedTile.distanceFromStart = costForRoad * length;
					annotatedTile.length = currentAnnotatedTile.length + length;
					tileArray.push(annotatedTile);
					isBridgeOrTunnelEntrance = true;
				}
			}
		}


		/** 
		 * If it is neither a tunnel or a bridge, we try to build one
		 * our selves.
		 */
		if (!isBridgeOrTunnelEntrance) {

			if (!onlyRoads) {
				local tmp;
				if ((tmp = GetBridge(nextTile, offset)) != null || (tmp = GetTunnel(nextTile, currentTile)) != null) {
					tmp.length += currentAnnotatedTile.length;
					tileArray.push(tmp);
				}
			}

			// Don't allow crossings with rail!
			if (!isInClosedList && !AIRail.IsRailTile(nextTile)) {
			
				// Besides the tunnels and bridges, we also add the tiles
				// adjacent to the 
				if (AIRoad.BuildRoad(currentTile, nextTile) || AIRoad.AreRoadTilesConnected(currentTile, nextTile)
				|| (AITile.GetMinHeight(currentTile) == AITile.GetMinHeight(nextTile) && 
				AITile.GetSlope(currentTile) + AITile.GetSlope(nextTile) == 0 &&
				(AITile.IsBuildable(currentTile) || AIRoad.IsRoadTile(currentTile)) &&
				(AITile.IsBuildable(nextTile) || AIRoad.IsRoadTile(nextTile)))) {

					local annotatedTile = AnnotatedTile();
					annotatedTile.type = Tile.ROAD;
					annotatedTile.direction = offset;
					annotatedTile.tile = nextTile;
					annotatedTile.alreadyBuild = false;
					annotatedTile.length = currentAnnotatedTile.length + 1;
	
					// Check if the road is sloped.
					/// @todo Differentiate between slope up and down? However roads are usually used in both directions.
					if (Tile.IsSlopedRoad(currentAnnotatedTile.parentTile.tile, currentTile, nextTile))
						annotatedTile.distanceFromStart = costForSlope;
				
					// Check if the road makes a turn.
					if (currentAnnotatedTile.direction != offset)
						annotatedTile.distanceFromStart += costForTurn;
	
					// Check if there is already a road here.
					if (AIRoad.IsRoadTile(nextTile)) {
						/// @todo Can/Should we check if there is already a lot of traffic here?
						annotatedTile.distanceFromStart += costForRoad;
						if (AIRoad.IsDriveThroughRoadStationTile(nextTile))
							annotatedTile.distanceFromStart += costForRoad * 10;
					}
					else
						annotatedTile.distanceFromStart += costForNewRoad;
	
					tileArray.push(annotatedTile);
				}
			}
		}
	}

	/*foreach(at in tileArray) {
		if (at.type == null) {
			Log.logError("NULL type - ROAD!")
			Log.logWarning("Problem Tile " + AIMap.GetTileX(at.tile) + ", " + AIMap.GetTileY(at.tile));
		}
	}*/

	return tileArray;
}

function RoadPathFinderHelper::ProcessTile(isInClosedList, tile, direction) {

	if (!isInClosedList)
		return true;

	if (AITunnel.BuildTunnel(AIVehicle.VT_ROAD, tile))
		return true;

	for (local i = 1; i < MAX_ROAD_BRIDGE_LENGTH; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = tile + i * direction;
		if (!AIMap.DistanceFromEdge(target))
			return false;
		if (AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), tile, target))
			return true;
	}

	return false;
}

function RoadPathFinderHelper::GetBridge(startNode, direction) {

	local isRailTile = AIRail.IsRailTile(startNode + direction);
	if (Tile.GetSlope(startNode, direction) != 2 && !isRailTile) return null;

	for (local i = 1; i < MAX_ROAD_BRIDGE_LENGTH; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = startNode + i * direction;
		if (!AIMap.DistanceFromEdge(target))
			return null;

		if ((Tile.GetSlope(target, direction) == 1 || isRailTile) && !bridge_list.IsEmpty() &&
			AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), startNode, target) &&
			AIRoad.BuildRoad(target, target + direction) &&
			AIRoad.BuildRoad(startNode, startNode - direction)) {

			local annotatedTile = AnnotatedTile();
			annotatedTile.type = Tile.BRIDGE;
			annotatedTile.direction = direction;
			annotatedTile.tile = target;
			annotatedTile.alreadyBuild = false;
			annotatedTile.distanceFromStart = costForBridge * (i + 1);
			annotatedTile.length = i + 1;
			return annotatedTile;
		}
	}
	return null;
}
	
function RoadPathFinderHelper::GetTunnel(startNode, previousNode) {

	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return null;
	
	/** Try to build a tunnel */
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(startNode);
	if (!AIMap.IsValidTile(other_tunnel_end)) return null;

	local tunnel_length = AIMap.DistanceManhattan(startNode, other_tunnel_end);
	local direction = (other_tunnel_end - startNode) / tunnel_length;

	// Check if the slope at the tunnel's end is good. This means: the base
	// of the other end isn't going to terraform which might form unsatisfiable.
	local forceForward = false;
	local slopeOtherEnd = AITile.GetSlope(other_tunnel_end);
	if (direction ==  1 && (slopeOtherEnd & AITile.SLOPE_SW) != 0 ||			// West
	    direction == -1 && (slopeOtherEnd & AITile.SLOPE_NE) != 0 ||			// East
	    direction == -AIMap.GetMapSizeX() && (slopeOtherEnd & AITile.SLOPE_NW) != 0 ||	// North
 	    direction ==  AIMap.GetMapSizeX() && (slopeOtherEnd & AITile.SLOPE_SE) != 0)	// South
		// Do something!
		forceForward = true;
		
	
	local prev_tile = startNode - direction;
	if (tunnel_length >= 1 && tunnel_length < MAX_ROAD_TUNNEL_LENGTH && prev_tile == previousNode && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, startNode) && AIRoad.BuildRoad(other_tunnel_end, other_tunnel_end + direction) && AIRoad.BuildRoad(startNode, startNode - direction)) {
		local annotatedTile = AnnotatedTile();
		annotatedTile.type = Tile.TUNNEL;
		annotatedTile.direction = direction;
		annotatedTile.tile = other_tunnel_end;
		annotatedTile.alreadyBuild = false;
		annotatedTile.distanceFromStart = costForTunnel * (tunnel_length < 0 ? -tunnel_length : tunnel_length);
		annotatedTile.forceForward = forceForward;
		annotatedTile.length = tunnel_length; 
		return annotatedTile;
	}
	return null;
}

/**
 * After loading a savegame we need to fix certain parts of roadList otherwise GetTime will always return 0.
 * Seems we can use this also for RailPathFinderHelper. Probably should be moved to PathFinderHelper.
 * @note I'm not sure whether direction of the first and last tile are correct. It looks like they should be [-1,-1].
 * @param roadList The roadList that needs to be fixed.
 */
function RoadPathFinderHelper::FixRoadlist(roadList)
{
	Log.logDebug("Fixing roadlist after loading a savegame.");
	if ((roadList == null) || (roadList.len() == 0)) {
		Log.logError("Invalid roadList " + (roadList == null ? "is null." : "length is 0."));
		return;
	}

	//Log.logDebug("!! Length roadList: " + roadList.len());
	local rlen = roadList.len();
	for (local i = 0; i < rlen; i++) {
		if ((roadList[i].type != null) && (roadList[i].type != Tile.NONE)) {
			Log.logWarning("Tile Type unexpected! Skipping.");
			continue;
		}
		local tile = roadList[i].tile;
		if (AIBridge.IsBridgeTile(tile))
			roadList[i].type = Tile.BRIDGE;
		else if (AITunnel.IsTunnelTile(tile))
			roadList[i].type = Tile.TUNNEL;
		else
			roadList[i].type = Tile.ROAD;
		
		if (i < rlen-1)
			roadList[i].direction = roadList[i+1].tile - tile;
		else // What to do here? [-1,-1]?
			roadList[i].direction = roadList[i-1].direction; //????
	}
}

function RoadPathFinderHelper::GetTime(roadList, engineID, forward) {

	local maxSpeed = AIEngine.GetMaxSpeed(engineID);
	local lastDirection = roadList[0];
	local currentSpeed = 0;
	local carry = 0;
	local hours = 0;
	local lastDirection = 0;

	for (local i = 0; i < roadList.len(); i++) {
		local tile = roadList[i].tile;
		local currentDirection = roadList[i].direction;
		local slope = Tile.GetSlope(tile, currentDirection);

		local tileLength = 0;

		switch (roadList[i].type) {
			case Tile.ROAD:
				if(lastDirection != currentDirection) {		// Bend
					tileLength = (Tile.bendedRoadLength) * 24 - carry;
					currentSpeed = maxSpeed / 2;
				} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
					tileLength = (Tile.upDownHillRoadLength * 24) - carry;
					
					local slowDowns = 0;
		
					local quarterTileLength = tileLength / 4;
					local qtl_carry = 0;
					
					// Speed decreases 10% 4 times per tile
					for (local j = 0; j < 4; j++) {
						local qtl = quarterTileLength - qtl_carry;
						while (qtl > 0) {
							qtl -= currentSpeed;
							hours++;
						}
						
						currentSpeed *= 0.9;
						qtl_carry = -qtl;
						if (currentSpeed < 34) {
							currentSpeed = 34;
							break;
						}
					}
					
				} else if (slope == 2 && forward || slope == 1 && !forward) {			// Downhill
					tileLength = (Tile.upDownHillRoadLength * 24) - carry;
		
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						hours++;
						
						currentSpeed += 74;
						if (currentSpeed >= maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				} else {					// Straight
					tileLength = (Tile.straightRoadLength * 24) - carry;
					
					// Calculate the number of days needed to traverse the tile
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						hours++;
		
						currentSpeed += 37;
						if (currentSpeed > maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				}
				break;
				
			case Tile.BRIDGE:
			case Tile.TUNNEL:
				local length = (tile - roadList[i + 1].tile) / currentDirection;
				if (length < 0) length = -length;
				tileLength = Tile.straightRoadLength * length * 24 - carry;
				while (tileLength > 0) {
					tileLength -= currentSpeed;
					hours++;
					
					currentSpeed += 37;
					if (currentSpeed > maxSpeed) {
						currentSpeed = maxSpeed;
						break;
					}
				}
				break;
			default:
				// Should not happen anymore but leave this in just in case.
				Log.logError("Road Get TravelTime: Unexpected roadList type! i = " + i);
				AISign.BuildSign(tile, "x");
				AISign.BuildSign(roadList[0].tile, "0");
				AISign.BuildSign(roadList[roadList.len()-1].tile, "1");
				break;
		}
			
		if (tileLength > 0 && currentSpeed > 0) {
			local div = (tileLength / currentSpeed).tointeger();

			carry = tileLength - (currentSpeed * div);
			hours += div;
		} else {
			carry = -tileLength;
		}
		lastDirection = currentDirection;

	}
	return (hours / 24).tointeger();
}

