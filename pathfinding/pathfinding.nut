
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding 
{
	// The length of various road pieces
	static straightRoadLength 	= 28.5;
	static bendedRoadLength 	= 28.5;
	static upDownHillRoadLength 	= 40;

	costForRoad 	= 30;		// Cost for utilizing an existing road, bridge, or tunnel.
	costForNewRoad	= 50;		// Cost for building a new road.
	costForTurn 	= 75;		// Additional cost if the road makes a turn.
	costForBridge 	= 120;		// Cost for building a bridge.
	costForTunnel 	= 150;		// Cost for building a tunnel.
	costForSlope 	= 75;		// Additional cost if the road heads up or down a slope.
	
	toBuildLater = [];		// List of build actions which couldn't be completed the moment
					// they were issued due to temporal problems, but should be able
					// to complete in the (near) future.
					// [0]: Build from
					// [1]: Build to
					// [2]: Tile type
	errorHandling	= false;	// True if we are in error solving mode.
	
	/**
	 * We need functions to calibrate penalties and stuff. We want functions
	 * to build the *fastest*, *cheapest*, *optimal throughput*, etc. We aren't
	 * allowed to write C++ so we need to script this information :).
	 */
	function CreateRoad(roadList);		// Create the best road from start to end
	function GetCostForRoad(roadList);	// Give the cost for the best road from start to end
	function FindFastestRoad(start, end);
	function GetTime(roadList, maxSpeed, forward);
}

/**
 * Store important info about a path we found! :)
 */
class PathInfo
{
	roadList = null;		// List of all road tiles the road needs to follow.
	roadCost = null;		// The cost to create this road.
	depot = null;			// The location of the depot.
	build = null;			// Is this path build?

	constructor(roadList, roadCost) {
		this.roadList = roadList;
		this.roadCost = roadCost;
		this.build = false;
	}
}

/**
 * If an error occurs during the construction phase, this method is called
 * to replan the road and finish what has been started.
 * @param roadList The part of the roadlist that hasn't been build yet.
 * @param buildFrom The tile we tried to build from before the error.
 * @param buildTo The tile we tried to build to before the error.
 * @param tileType The structure we tried to build; Tile.ROAD, Tile.BRIDGE, or Tile.TUNNEL.
 * @param error The error ID of the error which was thrown.
 * @return True if the CreateRoad method must continue with the rest of the
 * roadList (i.e. the link between buildFrom and buildTo is solved), otherwise
 * the CreateRoad method must be ceased as the pathfinder found a different 
 * road and will issue a new construction command.
 */
function RoadPathFinding::FallBackCreateRoad(roadList, buildFrom, buildTo, tileType, error)
{
	
	/**
	 * First determine whether the error is of temporeral nature (i.e. lack
	 * of money, a vehicle was in the way, etc) or a more serious one which
	 * requires us to replan this part of the road.
	 */
	switch (error) {
	
		// Temporal onces:
		case AIError.ERR_NOT_ENOUGH_CASH:
		case AIError.ERR_VEHICLE_IN_THE_WAY:
		case AIRoad.ERR_ROAD_WORKS_IN_PROGRESS:
			toBuildLater.push([buildFrom, buildTo, tileType]);
			return true;
			
		// Serious onces:
		case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
		case AIError.ERR_AREA_NOT_CLEAR:
		case AIError.ERR_OWNED_BY_ANOTHER_COMPANY:
		case AIError.ERR_FLAT_LAND_REQUIRED:
		case AIError.ERR_LAND_SLOPED_WRONG:
		case AIError.ERR_SITE_UNSUITABLE:
		case AIError.ERR_TOO_CLOSE_TO_EDGE:
		case AIRoad.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS:
		
			// Make sure we don't get caught in an infinite loop because we're
			// trying to build an unbuildable piece of road.
			if (errorHandling) {
				Utils.logError("Building road FAILED!");
				return false;
			}
			
			print("Fixing: " + AIError.GetLastErrorString() + "! " + tileType);
			{
				local a = AIExecMode();
				AISign.BuildSign(buildFrom, "From");
				AISign.BuildSign(buildTo, "To");
			}
				
			// Construct new start list.
			local start_list = AIList();
			start_list.add(buildFrom, buildFrom);
			
			local end_list = AIList();
			end_list.add(buildTo, buildTo);
			
			// Try to build it again, but only once!.
			local pathInfo = FindFastestRoad(start_list, end_list);
			
			errorHandling = true;
			CreateRoad(pathInfo);
			errorHandling = false;
			return false;
			
		// Trival onces:
		case AIError.ERR_ALREADY_BUILT:
		case AIRoad.ERR_ROAD_CANNOT_BUILD_ON_TOWN_ROAD:
		case AIError.ERR_PRECONDITION_FAILED:
			return true;
			
		default:
			Utils.logError("Unhandled error message: " + AIError.GetLastErrorString() + "!");
			return false;
	}
	
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 */
function RoadPathFinding::CreateRoad(pathList)
{
	local roadList = pathList.roadList;
	if(roadList == null || roadList.len() < 2)
		return false;
		
	local buildFrom = roadList[roadList.len() - 1].tile;
	local currentDirection = roadList[roadList.len() - 1].direction;
	
	for(local a = roadList.len() - 2; -1 < a; a--)		
	{
		local buildTo = roadList[a].tile;
		local direction = roadList[a].direction;
		
		switch (roadList[a].type) {
			case Tile.ROAD:
				/**
				 * Every time we make a call to the OpenTTD engine (i.e. build something) we hand over the
				 * control to the next AI, therefor we try to envoke as less calls as posible by building
				 * large segments of roads at the time instead of single tiles.
				 */
				if (direction != currentDirection) {
		
					// Check if we need to do some terraforming
					// Not needed ATM, as we make sure we only consider roads which
					// don't require terraforming
					// Terraform(buildFrom, currentDirection);
					
					if (!AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile)) {
						if (!FallBackCreateRoad(roadList.slice(a), buildFrom, roadList[a + 1].tile, Tile.ROAD, AIError.GetLastError()))
							return;
						
						
						local s = "Failed to build a road from " + AIMap.GetTileX(buildFrom) + ", " + AIMap.GetTileY(buildFrom) + " to " + AIMap.GetTileX(roadList[a + 1].tile) + ", " + AIMap.GetTileY(roadList[a + 1].tile);
						print(s);
						print(AIError.GetLastErrorString());
					}
					currentDirection = direction;
					buildFrom = roadList[a + 1].tile;
				}
				break;
			case Tile.TUNNEL:
				if (!AITunnel.IsTunnelTile(roadList[a + 1].tile + roadList[a].direction) && !AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, roadList[a + 1].tile + roadList[a].direction)) {
					if (!FallBackCreateRoad(roadList.slice(a), roadList[a + 1].tile + roadList[a].direction, null, Tile.TUNNEL, AIError.GetLastError()))
						return;
				}

				// Build road before the tunnel
				AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile);
				if (direction != roadList[a + 1].direction) {
					if (!AIRoad.BuildRoad(roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction)) {
						if (!FallBackCreateRoad(roadList.slice(a), roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction, Tile.ROAD, AIError.GetLastError()))
							return;
					}
				}
				
				if (a > 0)
					buildFrom = roadList[a - 1].tile;
				else
					buildFrom = roadList[0].tile;
				break;
			case Tile.BRIDGE:
			
				if (!AIBridge.IsBridgeTile(roadList[a + 1].tile + roadList[a].direction)) {
					local tileA = roadList[a].tile;
					local tileA1 = roadList[a + 1].tile;
					local direction = roadList[a].direction;
					
					local length = (roadList[a].tile - roadList[a + 1].tile) / roadList[a].direction;
					if (length < 0)
						length = -length;

					// Find the cheapest and fastest bridge (i.e. 48 km/h or more).
					local bridgeTypes = AIBridgeList_Length(length);
					local bestBridgeType = null;
					for (bridgeTypes.Begin(); bridgeTypes.HasNext(); ) {
						local bridge = bridgeTypes.Next();
						if (bestBridgeType == null || (AIBridge.GetPrice(bestBridgeType, length) > AIBridge.GetPrice(bridge, length) && AIBridge.GetMaxSpeed(bridge) >= 48)) {
							bestBridgeType = bridge;
						}
					}
					
					if (bestBridgeType == null)
					{
						local a = AIExecMode();
						AISign.BuildSign(roadList[a + 1].tile + roadList[a].direction, "From");
					}

					if (!AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bestBridgeType, roadList[a + 1].tile + roadList[a].direction, roadList[a].tile)) {
						if (!FallBackCreateRoad(roadList.slice(a), roadList[a + 1].tile + roadList[a].direction, null, Tile.BRIDGE, AIError.GetLastError()))
							return;
					}
				}
				
				// Build road before the tunnel
				AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile);
				if (direction != roadList[a + 1].direction) {
					if (!AIRoad.BuildRoad(roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction)) {
						if (!FallBackCreateRoad(roadList.slice(a), roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction, Tile.ROAD, AIError.GetLastError()))
							return;
					}
				}

				if (a > 0)
					buildFrom = roadList[a - 1].tile;
				else
					buildFrom = roadList[0].tile;
				break;
		}
	}
	
	// Build the last part
	AIRoad.BuildRoad(roadList[0].tile, buildFrom);
	return true;		
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function RoadPathFinding::GetCostForRoad(roadList)
{
	local test = AITestMode();		// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs

	this.CreateRoad(roadList);		// Fake the construction

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
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

		if(lastDirection != currentDirection) {		// Bend
			tileLength = bendedRoadLength - carry;
			currentSpeed = maxSpeed / 2;
		} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
			tileLength = upDownHillRoadLength - carry;
			
			local slowDowns = 0;

			while (tileLength > 0) {
				tileLength -= currentSpeed;
				days++;

				if (currentSpeed <= 34) {
					currentSpeed = 34;
					break;
				}
				// Speed decreases 10% 4 times per tile
				else if (tileLength < 970 - slowDowns * 242) {
					currentSpeed *= 0.9;
					slowDowns++;
				}

			}
		} else if (slope == 2 && forward || slope == 1 && !forward) {			// Downhill
			tileLength = upDownHillRoadLength - carry;

			while (tileLength > 0) {
				tileLength -= currentSpeed;
				days++;

				if (currentSpeed >= maxSpeed) {
					currentSpeed = maxSpeed;
					break;
				} else if (currentSpeed < maxSpeed) {
					currentSpeed += 74;
				}
			}
		} else {					// Straight
			tileLength = straightRoadLength - carry;
			
			// Calculate the number of days needed to traverse the tile
			while (tileLength > 0) {
				tileLength -= currentSpeed;
				days++;

				currentSpeed += 74;
				if (currentSpeed > maxSpeed) {
					currentSpeed = maxSpeed;
					break;
				}
			}
		}

		if (tileLength > 0) {
			local div = tileLength / currentSpeed;
			carry = tileLength - (currentSpeed * div);
			days += div;
		} else {
			carry = -tileLength;
		}

		lastDirection = currentDirection;

	}
	return days.tointeger();
}

/**
 * A* pathfinder to find the fastest path from start to end.
 * @param start An AIAbstractList which contains all the nodes the path can start from.
 * @param end An AIAbstractList which contains all the nodes the path can stop at. The
 * middle point of these values will be used to guide the pathfinder to its goal.
 * @return A PathInfo instance which contains the found path (if any).
 */
function RoadPathFinding::FindFastestRoad(start, end)
{
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
	
	// Start by constructing a fibonacci heap and by adding all start nodes to it.
	pq = FibonacciHeap();
	for(local i = start.Begin(); start.HasNext(); i = start.Next()) {
		// Check if we can actually start here!
		if(!Tile.IsBuildable(i))
			continue;
 
		local annotatedTile = AnnotatedTile(i, null, 0, 0, Tile.ROAD);
		annotatedTile.parentTile = annotatedTile;		// Small hack ;)
		pq.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * 30);
		startList[i] <- i;
	}


	// Now with the open and closed list we're ready to do some grinding!!!
	while (pq.Count != 0)
	{
		
		local at = pq.Pop();	

//		{
//			local a = AIExecMode();
//			AISign.BuildSign(at.tile, "A");
//		}
		
		// Get the node with the best utility value
		if(closedList.rawin(at.tile))
			continue;

		// Check if this is the end already, if so we've found the shortest route.
		if(end.HasItem(at.tile) && AIRoad.BuildRoadStation(at.tile, at.parentTile.tile, true, false, true)) {

			// determine size...
			local tmp = at;
			local tmp_size = 1;
			while(tmp.parentTile != tmp) {
				tmp = tmp.parentTile;
				tmp_size++;
			}

			// Create the result list
			local resultList = array(tmp_size);
			resultList[0] = at;

			// We want to return a PathInfo object, we need it for later assesments! :)
			local avg_speed = 0;
			local lastDirection = at.direction;

			tmp_size = 1;
			// Construct result list! :)
			while(at.parentTile != at) {
				at = at.parentTile;
				resultList[tmp_size] = at;
				tmp_size++;
			}
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
			if (closedList.rawin(neighbour[0]) || (neighbour[2] == Tile.ROAD && !AIRoad.AreRoadTilesConnected(neighbour[0], at.tile) && !AIRoad.BuildRoad(neighbour[0], at.tile))) {
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
			pq.Insert(AnnotatedTile(neighbour[0], at, neighbour[3], neighbour[1], neighbour[2]), neighbour[3] + AIMap.DistanceManhattan(neighbour[0], expectedEnd) * 30);
		}
		
		// Done! Don't forget to put at into the closed list
		closedList[at.tile] <- at.tile;
	}

	// Oh oh... No result found :(
	print("No path found!");
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

	// A Tile is about 612km on a side :)

	constructor(tile, parentTile, distanceFromStart, direction, type)
	{
		this.tile = tile;
		this.parentTile = parentTile;
		this.distanceFromStart = distanceFromStart;
		this.direction = direction;
		this.type = type;
	}
}
