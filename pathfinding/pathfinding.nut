
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding 
{
	// The length of various road pieces
	static straightRoadLength 	= 28.5;					// Road length / 24 (easier to calculate km/h)
	static bendedRoadLength 	= 20;//28.5;
	static upDownHillRoadLength = 28.5;

	costForRoad 	= 30;		// Cost for utilizing an existing road, bridge, or tunnel.
	costForNewRoad	= 50;		// Cost for building a new road.
	costForTurn 	= 75;		// Additional cost if the road makes a turn.
	costForBridge 	= 120;		// Cost for building a bridge.
	costForTunnel 	= 150;		// Cost for building a tunnel.
	costForSlope 	= 75;		// Additional cost if the road heads up or down a slope.
	
	static toBuildLater = [];		// List of build actions which couldn't be completed the moment
									// they were issued due to temporal problems, but should be able
									// to complete in the (near) future.
									
	/**
	 * We need functions to calibrate penalties and stuff. We want functions
	 * to build the *fastest*, *cheapest*, *optimal throughput*, etc. We aren't
	 * allowed to write C++ so we need to script this information :).
	 */
	//function FallBackCreateRoad(buildResult);
	//function CreateRoad(connection);			// Create the best road from start to end
	//function BuildRoad(roadList);
	//function GetSlope(tile, currentDirection);
	//function GetTime(roadList, maxSpeed, forward);
	//function FindFastestRoad(start, end, checkStartPositions, checkEndPositions);
}


/**
 * Check if this road tile is a slope.
 */
function RoadPathFinding::GetSlope(tile, currentDirection)
{
	// 0: No slope.
	// 1: Slope upwards.
	// 2: Slope downwards.

	if (currentDirection == 1) { 		// West
		if ((AITile.GetSlope(tile) & AITile.SLOPE_NE) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_SW) != 0) // Eastern slope must be flat and one point of the western slope must be high
			return 1;
		else if ((AITile.GetSlope(tile) & AITile.SLOPE_SW) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_NE) != 0) // Western slope must be flat and one point of the eastern slope must be high
			return 2;
	} else if (currentDirection == -1) {	// East
		if ((AITile.GetSlope(tile) & AITile.SLOPE_SW) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_NE) != 0) // Western slope must be flat and one point of the eastern slope must be high
			return 1;
		else if ((AITile.GetSlope(tile) & AITile.SLOPE_NE) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_SW) != 0) // Eastern slope must be flat and one point of the western slope must be high
			return 2;
	} else if (currentDirection == -AIMap.GetMapSizeX()) {	// North
		if ((AITile.GetSlope(tile) & AITile.SLOPE_SE) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_NW) != 0) // Southern slope must be flat and one point of the northern slope must be high
			return 1;
		else if ((AITile.GetSlope(tile) & AITile.SLOPE_NW) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_SE) != 0) // Northern slope must be flat and one point of the southern slope must be high
			return 2;
	} else if (currentDirection == AIMap.GetMapSizeX()) {	// South
		if ((AITile.GetSlope(tile) & AITile.SLOPE_NW) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_SE) != 0) // Northern slope must be flat and one point of the southern slope must be high

			return 1;
		else if ((AITile.GetSlope(tile) & AITile.SLOPE_SE) == 0 && (AITile.GetSlope(tile) & AITile.SLOPE_NW) != 0) // Southern slope must be flat and one point of the northern slope must be high
			return 2;
	}

	return 0;
}

/**
 * Get the time it takes a vehicle to travel among the given road.
 * @param roadList Array of annotated tiles which compounds the road.
 * @param maxSpeed The maximum speed of the vehicle.
 * @param forward Traverse the roadList in the given order if true, otherwise 
 * traverse it from back to the begin.
 * @return The number of days it takes a vehicle to traverse the given road
 * with the given maximum speed.
 */
function RoadPathFinding::GetTime(roadList, maxSpeed, forward)
{
	local lastDirection = roadList[0];
	local currentSpeed = 0;
	local carry = 0;
	local days = 0;
	local lastDirection = 0;

	for (local i = 0; i < roadList.len(); i++) {
		local tile = roadList[i].tile;
		local currentDirection = roadList[i].direction;
		local slope = GetSlope(tile, currentDirection);

		local tileLength = 0;

		switch (roadList[i].type) {
			case Tile.ROAD:
				if(lastDirection != currentDirection) {		// Bend
					tileLength = bendedRoadLength - carry;
					currentSpeed = maxSpeed / 2;
				} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
					tileLength = upDownHillRoadLength - carry;
					
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
					tileLength = upDownHillRoadLength - carry;
		
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
					tileLength = straightRoadLength - carry;
					
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
				local length = (tile - AIBridge.GetOtherBridgeEnd(tile)) / currentDirection;
				if (length < 0) length = -length;
				 
				tileLength = straightRoadLength * length - carry;
				
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
				
			case Tile.TUNNEL:
				local length = (tile - AITunnel.GetOtherTunnelEnd(tile)) / currentDirection;
				if (length < 0) length = -length;
				 
				tileLength = straightRoadLength * length - carry;
				
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

		assert (carry >= 0);

		lastDirection = currentDirection;

	}
	return days.tointeger();
}

/**
 * A* pathfinder to find the fastest path from start to end.
 * @param start An AIAbstractList which contains all the nodes the path can start from.
 * @param end An AIAbstractList which contains all the nodes the path can stop at. The
 * middle point of these values will be used to guide the pathfinder to its goal.
 * @param checkBuildability Check the start and end points before finding a road.
 * @return A PathInfo instance which contains the found path (if any).
 */
function RoadPathFinding::FindFastestRoad(start, end, checkStartPositions, checkEndPositions, stationType, maxPathLength)
{
	if(start.IsEmpty())
	{
		Log.logError("Could not find a fasted road for an empty startlist.");
		return null;
	}
	if(end.IsEmpty())
	{
		Log.logError("Could not find a fasted road for an empty endlist.");
		return null;
	}

	local test = AITestMode();

	local pq = null;
	local expectedEnd = null;

	// Calculate the central point of the end array
	local x = 0;
	local y = 0;

	for(local i = end.Begin(); end.HasNext(); i = end.Next()) {
		x += AIMap.GetTileX(i);
		y += AIMap.GetTileY(i);
	}

	expectedEnd = AIMap.GetTileIndex(x / end.Count(), y / end.Count());
	
	// We must also keep track of all tiles we've already processed, we use
	// a table for that purpose.
	local closedList = {};

	// We keep a separate list for start tiles
	local startList = {};
	
	local hasStartPoint = false;
	
	// Start by constructing a fibonacci heap and by adding all start nodes to it.
	pq = FibonacciHeap();
	for(local i = start.Begin(); start.HasNext(); i = start.Next()) {
		// Check if we can actually start here!
		if(checkStartPositions && !Tile.IsBuildable(i)) {
			continue;
		}
 
 		hasStartPoint = true;
 		
		local annotatedTile = AnnotatedTile(i, null, 0, 0, Tile.ROAD, 0);
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		pq.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * 30);
		startList[i] <- i;
	}
	
	// Check if we have a node from which to build.
	if (!hasStartPoint) {
		Log.logDebug("Pathfinder: No start points for this road; Abort: original #start points: " + start.Count());
		return null;
	}

	// Now with the open and closed list we're ready to do some grinding!!!
	while (pq.Count != 0)
	{
		local at = pq.Pop();	
		
		// Get the node with the best utility value
		if(at.length > maxPathLength || closedList.rawin(at.tile))
			continue;

		// Check if this is the end already, if so we've found the shortest route.
		if(end.HasItem(at.tile) && 
		
			// If we need to check the end positions then we either have to be able to build a road station
			(!checkEndPositions || (AIRoad.BuildRoadStation(at.tile, at.parentTile.tile, true, false, true)/* || AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH*/) ||
			// or a roadstation must already be in place, facing the correct direction and be ours.
			(AIRoad.IsRoadStationTile(at.tile) && AIStation.HasStationType(at.tile, stationType) && AIRoad.GetRoadStationFrontTile(at.tile) == at.parentTile.tile && AITile.GetOwner(at.tile) == AICompany.MY_COMPANY))) {			
				
			local resultList = [];
			local resultTile = at;
			
			while (resultTile.parentTile != resultTile) {
				resultList.push(resultTile);
				resultTile = resultTile.parentTile;
			}
			
			resultList.push(resultTile);
			return PathInfo(resultList, null);
		}
		
		// Get all possible tiles from this annotated tile (North, South, West,
		// East) and check if we're already at the end or if new roads are possible
		// from those tiles.
		local directions = Tile.GetNeighbours(at);
		
		/**
		 * neighbour is an array with 4 elements:
		 * [0] = TileIndex
		 * [1] = Direction from parent (TileIndex - Parent.TileIndex)
		 * [2] = Type (i.e. TUNNEL, BRIDGE, or ROAD)
		 * [3] = Utility costs
		 * [4] = *TUNNEL and BRIDGE types only*Already built
		 */
		local neighbour = 0;
		foreach (neighbour in directions) {
		
			// Skip if this node is already processed or if we can't build on it.
			if (closedList.rawin(neighbour[0]) || (neighbour[2] == Tile.ROAD && !AIRoad.AreRoadTilesConnected(neighbour[0], at.tile) && !AIRoad.BuildRoad(neighbour[0], at.tile)/* && AIError.GetLastError() == AIError.ERR_AREA_NOT_CLEAR */)) {
				continue;
			}
			
			// Are we dealing with a tunnel or bridge?
			if (neighbour[2] != Tile.ROAD) {
				
				local length = (neighbour[0] - at.tile) / neighbour[1];
				if (length < 0) length = -length;
				
				// Treat already build bridges and tunnels the same as already build roads.
				if (neighbour[4]) {
					neighbour[3] = costForRoad * length;
				} else if (neighbour[2] == Tile.TUNNEL) {
					neighbour[3] = costForTunnel * length;
				} else {
					neighbour[3] = costForBridge * length;
				}
			}
			
			// This is a normal road
			else {
				
				// Check if the road is sloped.
				if (Tile.IsSlopedRoad(at.parentTile, at.tile, neighbour[0])) {
					neighbour[3] = costForSlope;
				}
				
				// Check if the road makes a turn.
				if (at.direction != neighbour[1]) {
					neighbour[3] += costForTurn;
				}
				
				// Check if there is already a road here.
				if (AIRoad.IsRoadTile(neighbour[0])) {
					neighbour[3] += costForRoad;
				} else {
					neighbour[3] += costForNewRoad;
				}
			}
			
			neighbour[3] += at.distanceFromStart;

			// Add this neighbour node to the queue.
			pq.Insert(AnnotatedTile(neighbour[0], at, neighbour[3], neighbour[1], neighbour[2], at.length + 1), neighbour[3] + AIMap.DistanceManhattan(neighbour[0], expectedEnd) * 30);
		}
		
		// Done! Don't forget to put at into the closed list
		closedList[at.tile] <- at.tile;
	}

	// Oh oh... No result found :(
	Log.logWarning("No path found!");
	return null;
}

/**
 * Util class to hold a tile and the heuristic value for
 * pathfinding.
 */
class AnnotatedTile 
{
	tile = null;			// Instance of AITile
	parentTile = null;		// Needed for backtracking!
	distanceFromStart = null;	// 'Distance' already travelled from start tile
	direction = null;		// The direction the road travels to this point.
	type = null;			// What type of infrastructure is this?
	length = null;			// The length of the path.

	// A Tile is about 612km on a side :)

	constructor(tile, parentTile, distanceFromStart, direction, type, length)
	{
		this.tile = tile;
		this.parentTile = parentTile;
		this.distanceFromStart = distanceFromStart;
		this.direction = direction;
		this.type = type;
		this.length = length;
	}
}
