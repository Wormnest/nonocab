
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding 
{
	// The length of various road pieces
	static straightRoadLength 	= 28.5;
	static bendedRoadLength 	= 28.5;
	static upDownHillRoadLength = 40;

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
	//function GetCostForRoad(roadList);			// Give the cost for the best road from start to end
	//function GetSlope(tile, currentDirection);
	//function GetTime(roadList, maxSpeed, forward);
	//function FindFastestRoad(start, end, checkStartPositions, checkEndPositions);
}

function RoadPathFinding::FixBuildLater()
{
	// Make sure we don't add double values (i.e. the fallback method tells us the build
	// the same route AGAIN!
	local toBuildLaterClone = clone toBuildLater;
	toBuildLater.resize(0);
	foreach (buildResult in toBuildLaterClone) {
		if (!BuildRoad(buildResult.roadList)) {
			Log.logWarning("Failed fix later action, not handled (properly) yet!");
		}
	}
}

/**
 * If an error occurs during the construction phase, this method is called
 * to replan the road and finish what has been started.
 * @param buildResult A BuildResult instance which contains the connection and 
 * error message, etc.
 * @return True if the CreateRoad method must continue with the rest of the
 * roadList (i.e. the link between buildFrom and buildTo is solved), otherwise
 * the CreateRoad method must be ceased as the pathfinder found a different 
 * road and will issue a new construction command.
 */
function RoadPathFinding::FallBackCreateRoad(buildResult)
{
	/**
	 * First determine whether the error is of temporeral nature (i.e. lack
	 * of money, a vehicle was in the way, etc) or a more serious one which
	 * requires us to replan this part of the road.
	 */
	switch (buildResult.errorMessage) {
	
		// Temporal onces:
		case AIError.ERR_NOT_ENOUGH_CASH:
		case AIError.ERR_VEHICLE_IN_THE_WAY:
		case AIRoad.ERR_ROAD_WORKS_IN_PROGRESS:
			//toBuildLater.push(buildResult);
			///return true;
			return false;
			
		// Serious onces:
		case AIError.ERR_LOCAL_AUTHORITY_REFUSES:
		case AIError.ERR_AREA_NOT_CLEAR:
		case AIError.ERR_OWNED_BY_ANOTHER_COMPANY:
		case AIError.ERR_FLAT_LAND_REQUIRED:
		case AIError.ERR_LAND_SLOPED_WRONG:
		case AIError.ERR_SITE_UNSUITABLE:
		case AIError.ERR_TOO_CLOSE_TO_EDGE:
		case AIRoad.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS:
		
			/**
			 * We handle these kind of errors elsewhere.
			 */
			return false;
			
		// Trival onces:
		case AIError.ERR_ALREADY_BUILT:
		case AIRoad.ERR_ROAD_CANNOT_BUILD_ON_TOWN_ROAD:
			return true;
			
		// Unsolvable ones:
		case AIError.ERR_PRECONDITION_FAILED:
			Log.logError("Precondition failed for the creation of a roadpiece, this cannot be solved!");
			Log.logError("/me slaps developer! ;)");
			quit();
			return false;
			
		default:
			Log.logError("Unhandled error message: " + AIError.GetLastErrorString() + "!");
			return true;
	}
}


/**
 * Create the previous calculated road stored in the connection object.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 * @param connection The connection object which contains the path the be build.
 */
function RoadPathFinding::CreateRoad(connection)
{
	local result = BuildRoad(connection.pathInfo.roadList);
	
	// If we were unsuccessful in building the road (and the fallback option failed),
	// we might need to recalculate a part or the whole path.
	
	// TODO: This part fails if we try to cuild more than 1 connection per tick.
	while (!result.success) {
		Log.logDebug("Fixing: " + AIError.GetLastErrorString() + "!");
		
		local roadList = connection.pathInfo.roadList;
		
		// Construct new start list.
		local start_list = AIList();
		start_list.AddItem(roadList[result.buildFromIndex].tile, roadList[result.buildFromIndex].tile);
		
		local end_list = AIList();
		end_list.AddItem(roadList[result.buildToIndex].tile, roadList[result.buildToIndex].tile);
		
		// Try to build it again.
		local pathInfo = FindFastestRoad(start_list, end_list, false, false);
		
		if (pathInfo == null) {
			Log.logWarning("Fallback function for a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + " failed!!!");
			return false;
		}
		
		// Merge new result with already existing roadlist.
		local newRoadList = [];
		
		newRoadList.extend(roadList.slice(0, result.buildToIndex));
		newRoadList.extend(pathInfo.roadList);
		if (result.buildFromIndex + 1 != roadList.len())
			newRoadList.extend(roadList.slice(result.buildFromIndex + 1));
		
		foreach (at in connection.pathInfo.roadList) {
			Log.buildDebugSign(at.tile, "Old");
		}
		
		foreach (at in newRoadList) {
			Log.buildDebugSign(at.tile, "New");
		}		
		
		connection.pathInfo.roadList = newRoadList;
		local tmpResult = BuildRoad(newRoadList);
		
		// Check if we don't hit the same error (if we do, quit!).
		if (!tmpResult.success && result.buildFromIndex == tmpResult.buildFromIndex) {
			Log.logWarning("Fallback function for a road from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + " failed!!!");
			return false;
		}
		
		result = tmpResult;
	}
	return true;
}

class RoadPathBuildResult {
	
	success = null;			// Is the build a success?
	errorMessage = null;	// The error message which is thrown.
	buildFromIndex = null;	// The start of the road piece which failed.
	buildToIndex = null;	// The end of the road piece which failed.
	tileType = null;		// The type of road to build.
	roadList = null;		// The roadlist to build.
	
	constructor(success, errorMessage, buildFromIndex, buildToIndex, tileType, roadList) {
		this.success = success;
		this.errorMessage = errorMessage;
		this.buildFromIndex = buildFromIndex;
		this.buildToIndex = buildToIndex;
		this.tileType = tileType;
		this.roadList = roadList;
	}
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 */
function RoadPathFinding::BuildRoad(roadList)
{
	//local roadList = connection.pathInfo.roadList;
	if(roadList == null || roadList.len() < 2)
		return false;

	local buildFromIndex = roadList.len() - 1;
	local currentDirection = roadList[roadList.len() - 2].direction;
	
	for(local a = roadList.len() - 2; -1 < a; a--)		
	{
		local buildToIndex = a;
		local direction = roadList[a].direction;
		
		if (roadList[a].type == Tile.ROAD) {

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
					
				if (!AIRoad.BuildRoad(roadList[buildFromIndex].tile, roadList[a + 1].tile)) {
					local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), buildFromIndex, a + 1, Tile.ROAD, roadList); 
					if (!FallBackCreateRoad(buildResult))
						return buildResult;
				}

				currentDirection = direction;
				buildFromIndex = a + 1;
			}
		}

		else if (roadList[a].type == Tile.TUNNEL) {
			if (!AITunnel.IsTunnelTile(roadList[a + 1].tile + roadList[a].direction) && !AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, roadList[a + 1].tile + roadList[a].direction)) {
				local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), a + 1, null, Tile.TUNNEL, roadList); 
				if (!FallBackCreateRoad(buildResult))
					return buildResult;
			}
		} 
		
		else if (roadList[a].type == Tile.BRIDGE) {
			if (!AIBridge.IsBridgeTile(roadList[a + 1].tile + roadList[a].direction)) {
					
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

				// Connect the bridge to the other end. Because the first road tile after the bridge has to
				// be straight, we have to substract a tile in the opposite direction from where the bridge is
				// going. Because we calculated the pathlist in the other direction, the direction is in the
				// opposite direction so we need to add it.
				if (!AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bestBridgeType, roadList[a + 1].tile + roadList[a].direction, roadList[a].tile)) {
					local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), a + 1, a, Tile.BRIDGE, roadList);
					if (!FallBackCreateRoad(buildResult))
						return buildResult;
				}
			}
		}
		
		// For both bridges and tunnels we need to build the piece of road prior and after
		// the bridge and tunnels.
		if (roadList[a].type != Tile.ROAD) {

			// Build road before the tunnel or bridge.
			if (!AIRoad.BuildRoad(roadList[buildFromIndex].tile, roadList[a + 1].tile)) {
				local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), buildFromIndex, a + 1, Tile.BRIDGE, roadList); 
				if (!FallBackCreateRoad(buildResult))
					return buildResult;
			}
			
			// Build the road after the tunnel or bridge.
			if (direction != roadList[a + 1].direction) {
				if (!AIRoad.BuildRoad(roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction)) {
					local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), a + 1, null, Tile.ROAD_POST_TUNNEL_OR_BRIDGE, roadList); 
					if (!FallBackCreateRoad(buildResult))
						return buildResult;
				}
			} 
				
			if (a > 0)
				buildFromIndex = a - 1;
			else
				buildFromIndex = 0;
		}
	}
	
	// Build the last part (if any).
	if (buildFromIndex > 0 && !AIRoad.BuildRoad(roadList[buildFromIndex].tile, roadList[0].tile)) {
		local buildResult = RoadPathBuildResult(false, AIError.GetLastError(), buildFromIndex, 0, Tile.ROAD, roadList); 
		if (!FallBackCreateRoad(buildResult))
			return buildResult 
	}
	return RoadPathBuildResult(true, null, null, null, null, null);
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function RoadPathFinding::GetCostForRoad(roadList)
{
	local test = AITestMode();		// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs

	this.BuildRoad(roadList);		// Fake the construction

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
 * @param checkBuildability Check the start and end points before finding a road.
 * @return A PathInfo instance which contains the found path (if any).
 */
function RoadPathFinding::FindFastestRoad(start, end, checkStartPositions, checkEndPositions)
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
	
	// No end points? 
	if (end.Count() == 0) {
		Log.logDebug("Pathfinder: No end points for this road; Abort");
		return null;
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
		if(checkStartPositions && !Tile.IsBuildable(i))
			continue;
 
 		hasStartPoint = true;
 		
		local annotatedTile = AnnotatedTile(i, null, 0, 0, Tile.ROAD);
		annotatedTile.parentTile = annotatedTile;		// Small hack ;)
		pq.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * 30);
		startList[i] <- i;
	}
	
	// Check if we have a node from which to build.
	if (!hasStartPoint) {
		Log.logDebug("Pathfinder: No start points for this road; Abort");
		return null;
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
		if(end.HasItem(at.tile) && (!checkEndPositions || AIRoad.BuildRoadStation(at.tile, at.parentTile.tile, true, false, true))) {

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
