/**
 * Path builder who handles all aspects of building a road (including roadstations and depots).
 */
class RailPathBuilder {

	maxSpeed = null;
	pathFixer = null;
	roadList = null;
	
	/**
	 * @param connection The connection to be realised.
	 * @param maxSpeed The max speed of the vehicles which are going to use this connection.
	 * @param pathFixer The path fixer instance to use when things go wrong.
	 */
	constructor(roadList, maxSpeed, pathFixer) {
		this.roadList = roadList;
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
	 * @param estimateCost If true, any errors which might occur during construction are ignored.
	 * @return True if the construction was succesful, false otherwise.
	 */
	function BuildPath(roadList, estimateCost);

	/**
	 * Check if the complete road is build.
	 * @param roadList The road list which contains all tiles to construct.
	 * @return True if the construction was succesful, false otherwise.
	 */
	function CheckPath(roadList);
	
	/**
	 * Build a road / tunnel / bridge piece.
	 * @param fromTile The tile to build from.
	 * @param toTile The tile to build to.
	 * @param tileType The type of road to build (road, tunnel, bridge).
	 * @param length The length of the piece (only for tunnels).
	 * @param estimateCost If true all errors are ignored.
	 * @return True if the construction succeded, false otherwise.
	 */
	function BuildRoadPiece(fromTile, toTile, tileType, length, estimateCost);
	
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
	
	function SaveData(saveData) {
		saveData["buildPiecesToFix"] <- buildPiecesToFix;
	}
	
	function LoadData(data) {
		buildPiecesToFix = data["buildPiecesToFix"];
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
				if (RailPathBuilder.BuildRoadPiece(piece[0], piece[1], piece[2], piece[3], true) && AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY) {
					toRemoveIndexes.push(index);
					break;
				}
				
				for (local j = 0; j < 100; j++);
			}
		}
		
		// Reverse the list so we don't remove the wrong items!
		toRemoveIndexes.reverse();
		foreach (index in toRemoveIndexes)
			buildPiecesToFix.remove(index);
	}
}


function RailPathBuilder::BuildRoadPiece(prevTile, fromTile, toTile, tileType, length, estimateCost) {

	local buildSucceded = false;
/*
	local l = AIRailTypeList();
	foreach (rt in l) {
		if (AIRail.IsRailTypeAvailable(rt)) {
			AIRail.SetCurrentRailType(rt);
			Log.logDebug("Set Rail type!!!");
			break;
		}
	}
	*/
	switch (tileType) {
		
		case Tile.ROAD:

			local direction = 0;
			local distanceX = AIMap.GetTileX(toTile) - AIMap.GetTileX(fromTile);
			local distanceY = AIMap.GetTileY(toTile) - AIMap.GetTileY(fromTile);
			if (distanceY > AIMap.GetMapSizeX())
				direction = AIMap.GetMapSizeX();
			else if (distanceY < -AIMap.GetMapSizeX())
				direction = -AIMap.GetMapSizeX();

			if (distanceX < 0)
				direction -= 1;
			else if (distanceX > 0)
				direction += 1;
					
//			Log.logWarning("BUILD@!!! " + direction);
			//AISign.BuildSign(prevTile, "---Prev---");
			//AISign.BuildSign(fromTile, "---Tile---");
			//AISign.BuildSign(toTile, "---To---");
			//buildSucceded = AIRail.BuildRail(fromTile - direction, fromTile, toTile);
			buildSucceded = AIRail.BuildRail(prevTile, fromTile, toTile);
//			Log.logWarning("Succceed? : " + buildSucceded);
		/*	
			// If we couldn't build a road in one try, try to break it down.
			if (estimateCost && !buildSucceded) {
				local direction = toTile - fromTile;
				// Check which direction we're going.
				if ((direction < 0 ? -direction : direction) < AIMap.GetMapSizeX())
					length = direction;
				else {
					length = direction / AIMap.GetMapSizeX();
				}
				
				if (length < 0)
					length = -length;
				
				// Now build all road pieces bit by bit.
				local tmpTile = fromTile;
				local direction = direction / length;
				
				while (tmpTile != toTile) {
					AIRail.BuildRail(tmpTile - direction, tmpTile, tmpTile + direction);
					tmpTile += direction;
				}
			}
*/
			
			break;
			
		case Tile.TUNNEL:
			if (!AITile.IsBuildable(fromTile))
				AITile.DemolishTile(fromTile);
			buildSucceded = AITunnel.BuildTunnel(AIVehicle.VT_RAIL, fromTile);
			break;
			
		case Tile.BRIDGE:
			// Find the cheapest and fastest bridge.
			local bridgeTypes = AIBridgeList_Length(length);
			local bestBridgeType = null;
			for (bridgeTypes.Begin(); bridgeTypes.HasNext(); ) {
				local bridge = bridgeTypes.Next();
				if (bestBridgeType == null || (/*AIBridge.GetPrice(bestBridgeType, length) > AIBridge.GetPrice(bridge, length) && */ AIBridge.GetMaxSpeed(bridge) >= AIBridge.GetMaxSpeed(bestBridgeType)))
					bestBridgeType = bridge;
			}		
		
			// Connect the bridge to the other end. Because the first road tile after the bridge has to
			// be straight, we have to substract a tile in the opposite direction from where the bridge is
			// going. Because we calculated the pathlist in the other direction, the direction is in the
			// opposite direction so we need to add it.
			buildSucceded = AIBridge.BuildBridge(AIVehicle.VT_RAIL, bestBridgeType, fromTile, toTile);
			break;
			
		default:
			assert(false);
	}
	
	// Next check if the build was succesful, and if not store all relevant information.
	if (!buildSucceded) {
		
		//AISign.BuildSign(prevTile, "From *");
		//AISign.BuildSign(fromTile, "Tile *");
		//AISign.BuildSign(toTile, "To *");
//		quit();
		// If the error is such we are unable to solve, stop.
		if (!estimateCost && !CheckError([prevTile, fromTile, toTile, tileType, length]))
			return false;
	}
	
	return true;
}

function RailPathBuilder::CheckPath(roadList)
{
/*	local test = AIExecMode();
	local tile = roadList[0].tile;
	for (local i = 1; i < roadList.len() - 1; i++) {
		local nextTile = roadList[i].tile;
		local nextTileType = roadList[i].type
		if (nextTileType == Tile.ROAD) {
			if (!AIRail.AreTilesConnected(tile, nextTile) && !BuildRoadPiece(nextTile, tile, Tile.ROAD, 1, false))
					return false;

			tile = nextTile;
		} else if (nextTileType == Tile.BRIDGE) {
			if (!AIBridge.IsBridgeTile(nextTile))
				return false;

			tile = AIBridge.GetOtherBridgeEnd(nextTile);/// - roadList[i].direction;
		} else if (nextTileType == Tile.TUNNEL) {
			if (!AITunnel.IsTunnelTile(nextTile))
				return false;

			tile = AITunnel.GetOtherTunnelEnd(nextTile);/// - roadList[i].direction;
		}
	}
*/
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
function RailPathBuilder::CheckError(buildResult)
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

			// Retry the same action 5 times...
			for (local i = 0; i < 50; i++) {
				if (BuildRoadPiece(buildResult[0], buildResult[1], buildResult[2], buildResult[3], buildResult[4], true) && AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
					return true;
				AIController.Sleep(1);
			}
				
			// We make a special exception for the very first and last piece of the road,
			// these are critical because without these we will be unable to build road
			// stations!
			if (buildResult[0] == roadList[0].tile || buildResult[0] == roadList[roadList.len() - 1].tile ||
			buildResult[1] == roadList[0].tile || buildResult[1] == roadList[roadList.len() - 1].tile)
				return false;
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
		case AIError.ERR_NOT_ENOUGH_CASH:		
		case AIRail.ERR_CROSSING_ON_ONEWAY_ROAD:		
		case AIRail.ERR_UNSUITABLE_TRACK:		

			AISign.BuildSign(buildResult[0], "Prev");
			//if (buildResult[1])
			AISign.BuildSign(buildResult[1], "From");
			AISign.BuildSign(buildResult[2], "To");
			//assert(false);
			/**
			 * We handle these kind of errors elsewhere.
			 */
			return false;
			
		// Trival onces:
		case AIError.ERR_ALREADY_BUILT:
			return true;
			
		// Unsolvable ones:
		case AIError.ERR_PRECONDITION_FAILED:
			Log.logError("Build from " + AIMap.GetTileX(buildResult[0]) + ", " + AIMap.GetTileY(buildResult[0]) + " to " + AIMap.GetTileX(buildResult[1]) + ", " + AIMap.GetTileY(buildResult[1]) + " tileType: " + buildResult[2]);
			Log.logError("Precondition failed for the creation of a roadpiece, this cannot be solved!");
			Log.logError("/me slaps developer! ;)");
			AISign.BuildSign(buildResult[0], "Prev *");
			//if (buildResult[1])
			AISign.BuildSign(buildResult[1], "From *");
			AISign.BuildSign(buildResult[2], "To *");
			
			assert(false);
			
		default:
			Log.logError("Unhandled error message: " + AIError.GetLastErrorString() + "!");
			return false;
	}
}

function RailPathBuilder::RealiseConnection(buildRoadStations)
{
	// Check if we have enough money...
	local estimatedCost = GetCostForRoad();
	if (estimatedCost > Finance.GetMaxMoneyToSpend()) {
		Log.logWarning("Not enough money, aborting construction!");
		return false;
	}
	
	{
//		local account = AIAccounting();
		local test = AIExecMode();
		
		local result = BuildPath(roadList, false);
//		local costs = account.GetCosts();
//		Log.logDebug("Estimated costs: " + estimatedCost + " actual costs: " + costs);
		if (result && !CheckPath(roadList)) {
			Log.logWarning("Path build but with errors!!!");
			return false;
		}

		return result;
	}
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 * @param roadList An array with annotated tiles to build.
 * @estimateCost If this is true we will not invoke the path fixer and try
 * to get as close an estimate of the true cost of building this path as
 * possible.
 */
function RailPathBuilder::BuildPath(roadList, estimateCost)
{
	//for(local a = 0; a < roadList.len(); a++) {
	//	AISign.BuildSign(roadList[a].tile, "X");
	//}
	
	Log.logDebug("Build path (rail)");
	if(roadList == null || roadList.len() < 3)
		return false;

	local mapSizeX = AIMap.GetMapSizeX();

	for(local a = roadList.len() - 1; -1 < a; a--) {

		local buildToIndex = a;
		local direction = roadList[a].direction;

		if (roadList[a].type == Tile.ROAD)
			AIRail.BuildRailTrack(roadList[a].tile, roadList[a].lastBuildRailTrack);

		else if (roadList[a].type == Tile.TUNNEL) {

			if (!AITunnel.IsTunnelTile(roadList[a + 1].tile + roadList[a].direction)) {
				if (!BuildRoadPiece(null, roadList[a + 1].tile + roadList[a].direction, roadList[a].tile, Tile.TUNNEL, null, estimateCost))
					return false;
			}
		} 

		else if (roadList[a].type == Tile.BRIDGE) {
			if (!AIBridge.IsBridgeTile(roadList[a + 1].tile + roadList[a].direction)) {
			
				local length = (roadList[a].tile - roadList[a + 1].tile) / roadList[a].direction;
				if (length < 0)
					length = -length;		
				
				if (!BuildRoadPiece(null, roadList[a + 1].tile + roadList[a].direction, roadList[a].tile, Tile.BRIDGE, length, estimateCost))
					return false;

			}
		}
	}

	return true;
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function RailPathBuilder::GetCostForRoad()
{
	Log.logDebug("Get cost for road");
	local test = AITestMode();			// Switch to test mode...
	local additionalCosts = 0;
	local accounting = AIAccounting();	// Start counting costs
	BuildPath(roadList, true);
//	AIRail.BuildRoadStation(roadList[0].tile, roadList[1].tile, AIRail.ROADVEHTYPE_TRUCK, AIStation.STATION_JOIN_ADJACENT);
//	AIRail.BuildRoadStation(roadList[roadList.len() - 1].tile, roadList[roadList.len() - 2].tile, AIRail.ROADVEHTYPE_TRUCK, AIStation.STATION_JOIN_ADJACENT);
	
	return accounting.GetCosts();
}
