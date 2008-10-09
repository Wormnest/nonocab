/**
 * Path builder who handles all aspects of building a road (including roadstations and depots).
 */
class PathBuilder {

	connection = null;
	maxSpeed = null;
	pathFixer = null;
	
	/**
	 * @param connection The connection to be realised.
	 * @param maxSpeed The max speed of the vehicles which are going to use this connection.
	 * @param pathFixer The path fixer instance to use when things go wrong.
	 */
	constructor(connection, maxSpeed, pathFixer) {
		this.connection = connection;
		this.maxSpeed = maxSpeed;
		this.pathFixer = pathFixer;
	}

	/**
	 * Realise the construction of a connection.
	 * @buildRoadStations If this is true, we will also build roadstations.
	 * @return True if the connection could be fully realised, false otherwise.
	 */
	function RealiseConnection(buildRoadStations);
	
	/**
	 * Build the actual road.
	 * @param roadList The road list to construct.
	 * @param ignoreError If true, any errors which might occur during construction are ignored.
	 * @return True if the construction was succesful, false otherwise.
	 */
	function BuildPath(roadList, ignoreError);
	
	/**
	 * Build a road / tunnel / bridge piece.
	 * @param fromTile The tile to build from.
	 * @param toTile The tile to build to.
	 * @param tileType The type of road to build (road, tunnel, bridge).
	 * @param length The length of the piece (only for tunnels).
	 * @param ignoreError If true all errors are ignored.
	 * @return True if the construction succeded, false otherwise.
	 */
	function BuildRoadPiece(fromTile, toTile, tileType, length, ignoreError);
	
	/**
	 * This function checks the last error and determines whether this 
	 * error can be fixed or if we need to replan the whole path.
	 */
	function CheckError(buildResult);
}

/**
 * Singleton class which tries to repair paths which couldn't be completed in a
 * previous point in time due to a temporal problem.
 */
class PathFixer extends Thread {

	buildPiecesToFix = null;
	
	constructor() {
		buildPiecesToFix = [];
	}
	
	/**
	 * Add an additional piece of road which couldn't be build due to 
	 * temporal issues.
	 * @param toFix An array containing all information for a new road piece.
	 */
	function AddBuildPieceToFix(toFix) {
		buildPiecesToFix.push(toFix);
	}

	function Update(loopCounter) {
		
		// Keep track which indexes we want to remove.
		local toRemoveIndexes = [];
		
		foreach (index, piece in buildPiecesToFix) {
			local test = AIExecMode();
			
			for (local i = 0; i < 5; i++) {
				if (PathBuilder.BuildRoadPiece(piece[0], piece[1], piece[2], piece[3], true) && AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY) {
					toRemoveIndexes.push(index);
					break;
				}
				
				for (local j = 0; j < 100; j++);
			}
		}
		
		// Reverse the list so we don't remove the wrong items!
		toRemoveIndexes.reverse();
		foreach (index in toRemoveIndexes) {
			buildPiecesToFix.remove(index);
		}
	}
}


function PathBuilder::BuildRoadPiece(fromTile, toTile, tileType, length, ignoreError) {

	local buildSucceded = false;
	
	switch (tileType) {
		
		case Tile.ROAD:
			buildSucceded = AIRoad.BuildRoad(fromTile, toTile);
			break;
			
		case Tile.TUNNEL:
			buildSucceded = AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, fromTile);
			break;
			
		case Tile.BRIDGE:
			// Find the cheapest and fastest bridge.
			local bridgeTypes = AIBridgeList_Length(length);
			local bestBridgeType = null;
			for (bridgeTypes.Begin(); bridgeTypes.HasNext(); ) {
				local bridge = bridgeTypes.Next();
				if (bestBridgeType == null || (AIBridge.GetPrice(bestBridgeType, length) > AIBridge.GetPrice(bridge, length) && AIBridge.GetMaxSpeed(bridge) >= maxSpeed)) {
					bestBridgeType = bridge;
				}
			}		
		
			// Connect the bridge to the other end. Because the first road tile after the bridge has to
			// be straight, we have to substract a tile in the opposite direction from where the bridge is
			// going. Because we calculated the pathlist in the other direction, the direction is in the
			// opposite direction so we need to add it.
			buildSucceded = AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bestBridgeType, fromTile, toTile);
			break;
			
		default:
			assert(false);
	}
	
	// Next check if the build was succesful, and if not store all relevant information.
	if (!buildSucceded) {
		
		// If the error is such we are unable to solve, stop.
		if (!ignoreError && !CheckError([fromTile, toTile, tileType, length]))
			return false;
		
		return true;
	}
	
	return true;
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
function PathBuilder::CheckError(buildResult)
{
	/**
	 * First determine whether the error is of temporeral nature (i.e. lack
	 * of money, a vehicle was in the way, etc) or a more serious one which
	 * requires us to replan this part of the road.
	 */
	switch (AIError.GetLastError()) {
	
		// Temporal onces:
		case AIError.ERR_VEHICLE_IN_THE_WAY:
		case AIRoad.ERR_ROAD_WORKS_IN_PROGRESS:
		
			// We make a special exception for the very first and last piece of the road,
			// these are critical because without these we will be unable to build road
			// stations!
			if (buildResult[0] == connection.pathInfo.roadList[0].tile || buildResult[0] == connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile ||
			buildResult[1] == connection.pathInfo.roadList[0].tile || buildResult[1] == connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile) {
				return false;
			}
			pathFixer.AddBuildPieceToFix(buildResult);
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
		case AIError.ERR_NOT_ENOUGH_CASH:		
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
			Log.logError("Build from " + buildResult[0] + " to " + buildResult[1] + " tileType: " + buildResult[2]);
			Log.logError("Precondition failed for the creation of a roadpiece, this cannot be solved!");
			Log.logError("/me slaps developer! ;)");
			assert(false);
			
		default:
			Log.logError("Unhandled error message: " + AIError.GetLastErrorString() + "!");
			return false;
	}
}

function PathBuilder::RealiseConnection(buildRoadStations)
{
	
	local test = AIExecMode();
	return BuildPath(connection.pathInfo.roadList, false);
		
	// If we were unsuccessful in building the road (and the fallback option failed),
	// we might need to recalculate a part or the whole path.
	
	// TODO
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 */
function PathBuilder::BuildPath(roadList, ignoreError)
{
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
					
				if (!BuildRoadPiece(roadList[buildFromIndex].tile, roadList[a + 1].tile, Tile.ROAD, null, ignoreError))
					return false;

				currentDirection = direction;
				buildFromIndex = a + 1;
			}
		}

		else if (roadList[a].type == Tile.TUNNEL) {

			if (!AITunnel.IsTunnelTile(roadList[a + 1].tile + roadList[a].direction)) {
				if (!BuildRoadPiece(roadList[a + 1].tile + roadList[a].direction, null, Tile.TUNNEL, null, ignoreError))
					return false;
			} else {
				// If the tunnel is already build, make sure the road before the bridge is connected to the
				// already build tunnel. (the part after the tunnel is handled in the next part).
				if (!BuildRoadPiece(roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction, Tile.ROAD, null, ignoreError))
					return false;
			}
		} 
		
		else if (roadList[a].type == Tile.BRIDGE) {
			if (!AIBridge.IsBridgeTile(roadList[a + 1].tile + roadList[a].direction)) {
			
				local length = (roadList[a].tile - roadList[a + 1].tile) / roadList[a].direction;
				if (length < 0)
					length = -length;		
				
				if (!BuildRoadPiece(roadList[a + 1].tile + roadList[a].direction, roadList[a].tile, Tile.BRIDGE, length, ignoreError))
					return false;

			} else {

				// If the bridge is already build, make sure the road before the bridge is connected to the
				// already build bridge. (the part after the bridge is handled in the next part).			
				if (!BuildRoadPiece(roadList[a + 1].tile, roadList[a + 1].tile + roadList[a].direction, Tile.ROAD, null, ignoreError))
					return false;
			}
		}
		
		// For both bridges and tunnels we need to build the piece of road prior and after
		// the bridge and tunnels.
		if (roadList[a].type != Tile.ROAD) {

			// Build road before the tunnel or bridge.
			if (buildFromIndex != a + 1) {
				if (!BuildRoadPiece(roadList[buildFromIndex].tile, roadList[a + 1].tile, Tile.ROAD, null, ignoreError))
					return false;
			}
			
			// Build the road after the tunnel or bridge, but only if the next tile is a road tile.
			// if the tile is not a road we obstruct the next bridge the pathfinder wants to build.
			if (a > 0 && roadList[a - 1].type == Tile.ROAD) {
				if (!BuildRoadPiece(roadList[a].tile, roadList[a - 1].tile, Tile.ROAD, null, ignoreError))
					return false;
			}

			// Update the status before moving on.
			buildFromIndex = a;
			currentDirection = roadList[a].direction;
		}
	}
	
	// Build the last part (if any).
	if (buildFromIndex >0) {
		if (!BuildRoadPiece(roadList[buildFromIndex].tile, roadList[0].tile, Tile.ROAD, null, ignoreError))
			return false;
	}

	return true;
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function PathBuilder::GetCostForRoad(roadList)
{
	local test = AITestMode();			// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs
	
	local pathBuilder = PathBuilder(null, null, null);

	pathBuilder.BuildPath(roadList, true);			// Fake the construction

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
}
