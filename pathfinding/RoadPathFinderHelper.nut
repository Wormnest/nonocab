class RoadPathFinderHelper extends PathFinderHelper {

	costForRoad 	= 20;		// Cost for utilizing an existing road, bridge, or tunnel.
	costForNewRoad	= 50;		// Cost for building a new road.
	costForTurn 	= 60;		// Additional cost if the road makes a turn.
	costForBridge 	= 65;		// Cost for building a bridge.
	costForTunnel 	= 65;		// Cost for building a tunnel.
	costForSlope 	= 85;		// Additional cost if the road heads up or down a slope.
	costTillEnd     = 50;           // The cost for each tile till the end.

	standardOffsets = null;
	dummyAnnotatedTile = null;
	
	constructor() {
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];

		// Optimalization, use a prefat annotated tile for heuristics.
		dummyAnnotatedTile = AnnotatedTile();
		dummyAnnotatedTile.type = Tile.ROAD;
		dummyAnnotatedTile.parentTile = dummyAnnotatedTile;
	}

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
	 * @param maxSpeed The maximum speed of the vehicle.
	 * @param forward Traverse the roadList in the given order if true, otherwise 
	 * traverse it from back to the begin.
	 * @return The number of days it takes a vehicle to traverse the given road
	 * with the given maximum speed.
	 */
	function GetTime(roadList, maxSpeed, forward);

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

function RoadPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {

	foreach (i, value in startList) {
	
		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.type = Tile.ROAD;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		// Check if we can actually start here!
		if(checkStartPositions) {
		
			if (!Tile.IsBuildable(i) || 
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

	local newEndLocations = AIList();
	
	foreach (i, value in endList) {
		if (checkEndPositions) {
			if (!Tile.IsBuildable(i) || 
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
					
				newEndLocations.AddItem(i, i);
			}
		}
	}

	if (checkEndPositions)
		endList = newEndLocations;
}


function RoadPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {

	if (at.type != Tile.ROAD)
		return false;

	// If we need to check the end positions then we either have to be able to build a road station
	// Either the slope is flat or it is downhill, othersie we can't build a depot here
	// Don't allow a tunnel to be near the planned end points because it can do terraforming, there by ruining the prospected location.
	if (checkEndPositions && (!AIRoad.BuildRoadStation(at.tile, at.parentTile.tile, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_JOIN_ADJACENT) || Tile.GetSlope(at.tile, at.direction) == 1 || at.parentTile.type == Tile.TUNNEL)) {

		// Something went wrong, the original end point isn't valid anymore! We do a quick check and remove any 
		// endpoints that aren't valid anymore.
		end.RemoveValue(at.tile);

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
			Log.logDebug("End list is empty, original goal isn't satisviable anymore.");
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
		
		// Check if we can exploit excising bridges and tunnels.
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
				    
					local annotatedTile = AnnotatedTile();
					annotatedTile.type = type;
					annotatedTile.direction = offset;
					annotatedTile.tile = otherEnd;
					annotatedTile.bridgeOrTunnelAlreadyBuild = true;
					annotatedTile.distanceFromStart = costForRoad * (length < 0 ? -length : length);
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
				if (tmp = GetBridge(nextTile, offset))
					tileArray.push(tmp);
				if (tmp = GetTunnel(nextTile, currentTile))
					tileArray.push(tmp);
			}

			if (!isInClosedList) {
			
				// Besides the tunnels and bridges, we also add the tiles
				// adjacent to the 
				if (AIRoad.BuildRoad(currentTile, nextTile) || AIRoad.AreRoadTilesConnected(currentTile, nextTile)
				|| (AITile.GetHeight(currentTile) == AITile.GetHeight(nextTile) && 
				AITile.GetSlope(currentTile) + AITile.GetSlope(nextTile) == 0 &&
				(AITile.IsBuildable(currentTile) || AIRoad.IsRoadTile(currentTile)) &&
				(AITile.IsBuildable(nextTile) || AIRoad.IsRoadTile(nextTile)))) {

					local annotatedTile = AnnotatedTile();
					annotatedTile.type = Tile.ROAD;
					annotatedTile.direction = offset;
					annotatedTile.tile = nextTile;
					annotatedTile.bridgeOrTunnelAlreadyBuild = false;
	
					// Check if the road is sloped.
					if (Tile.IsSlopedRoad(currentAnnotatedTile.parentTile, currentTile, nextTile))
						annotatedTile.distanceFromStart = costForSlope;
				
					// Check if the road makes a turn.
					if (currentAnnotatedTile.direction != offset)
						annotatedTile.distanceFromStart += costForTurn;
	
					// Check if there is already a road here.
					if (AIRoad.IsRoadTile(nextTile)) {
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

	return tileArray;
}

function RoadPathFinderHelper::ProcessClosedTile(tile, direction) {
	if (AITunnel.BuildTunnel(AIVehicle.VT_ROAD, tile))
		return true;

	for (local i = 1; i < 30; i++) {
		local bridge_list = AIBridgeList_Length(i);
		local target = tile + i * direction;
		if (!AIMap.DistanceFromEdge(target))
			return false;
		if (AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), tile, target))
			return true;
	}

	return false;
}

function RoadPathFinderHelper::GetBridge(startNode, direction) {

	if (Tile.GetSlope(startNode, direction) != 2) return null;

	for (local i = 1; i < 30; i++) {
		local bridge_list = AIBridgeList_Length(i);
		local target = startNode + i * direction;
		if (!AIMap.DistanceFromEdge(target))
			return null;

		if (Tile.GetSlope(target, direction) == 1 && !bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), startNode, target) && AIRoad.BuildRoad(target, target + direction) && AIRoad.BuildRoad(startNode, startNode - direction)) {

			local annotatedTile = AnnotatedTile();
			annotatedTile.type = Tile.BRIDGE;
			annotatedTile.direction = direction;
			annotatedTile.tile = target;
			annotatedTile.bridgeOrTunnelAlreadyBuild = false;
			annotatedTile.distanceFromStart = costForBridge * i;
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
	if (tunnel_length >= 1 && tunnel_length < 20 && prev_tile == previousNode && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, startNode) && AIRoad.BuildRoad(other_tunnel_end, other_tunnel_end + direction) && AIRoad.BuildRoad(startNode, startNode - direction)) {
		local annotatedTile = AnnotatedTile();
		annotatedTile.type = Tile.TUNNEL;
		annotatedTile.direction = direction;
		annotatedTile.tile = other_tunnel_end;
		annotatedTile.bridgeOrTunnelAlreadyBuild = false;
		annotatedTile.distanceFromStart = costForTunnel * (tunnel_length < 0 ? -tunnel_length : tunnel_length);
		annotatedTile.forceForward = forceForward;
		return annotatedTile;
	}
	return null;
}

function RoadPathFinderHelper::GetTime(roadList, maxSpeed, forward) {

	local lastDirection = roadList[0];
	local currentSpeed = 0;
	local carry = 0;
	local days = 0;
	local lastDirection = 0;

	for (local i = 0; i < roadList.len(); i++) {
		local tile = roadList[i].tile;
		local currentDirection = roadList[i].direction;
		local slope = Tile.GetSlope(tile, currentDirection);

		local tileLength = 0;

		switch (roadList[i].type) {
			case Tile.ROAD:
				if(lastDirection != currentDirection) {		// Bend
					tileLength = Tile.bendedRoadLength - carry;
					currentSpeed = maxSpeed / 2;
				} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
					tileLength = Tile.upDownHillRoadLength - carry;
					
					local slowDowns = 0;
		
					local quarterTileLength = tileLength / 4;
					local qtl_carry = 0;
					
					// Speed decreases 10% 4 times per tile
					for (local j = 0; j < 4; j++) {
						local qtl = quarterTileLength - qtl_carry;
						while (qtl > 0) {
							qtl -= currentSpeed;
							days++;
						}
						
						currentSpeed *= 0.9;
						qtl_carry = -qtl;
						if (currentSpeed < 34) {
							currentSpeed = 34;
							break;
						}
					}
					
				} else if (slope == 2 && forward || slope == 1 && !forward) {			// Downhill
					tileLength = Tile.upDownHillRoadLength - carry;
		
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						days++;
						
						currentSpeed += 74;
						if (currentSpeed >= maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				} else {					// Straight
					tileLength = Tile.straightRoadLength - carry;
					
					// Calculate the number of days needed to traverse the tile
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						days++;
		
						currentSpeed += 34;
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
				tileLength = Tile.straightRoadLength * length - carry;
				while (tileLength > 0) {
					tileLength -= currentSpeed;
					days++;
					
					currentSpeed += 34;
					if (currentSpeed > maxSpeed) {
						currentSpeed = maxSpeed;
						break;
					}
				}
				break;
		}
			
		if (tileLength > 0) {
			local div = (tileLength / currentSpeed).tointeger();

			carry = tileLength - (currentSpeed * div);
			days += div;
		} else {
			carry = -tileLength;
		}
		lastDirection = currentDirection;

	}
	return days.tointeger();
}

