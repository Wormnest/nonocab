
/**
 * Path builder who handles all aspects of building a road (including roadstations and depots).
 */
class WaterPathBuilder {

	connection = null;
	
	/**
	 * @param connection The connection to be realised.
	 * @param pathFixer The path fixer instance to use when things go wrong.
	 */
	constructor(connection) {
		this.connection = connection;
	}

	/**
	 * Realise the construction of a connection.
	 * @buildRoadStations If this is true, we will also build roadstations.
	 * @return True if the connection could be fully realised, false otherwise.
	 */
	function RealiseConnection();
	
	/**
	 * Build the actual road.
	 * @param roadList The road list to construct.
	 * @param ignoreError If true, any errors which might occur during construction are ignored.
	 * @return True if the construction was succesful, false otherwise.
	 */
	function BuildPath(roadList);
	
	/**
	 * This function checks the last error and determines whether this 
	 * error can be fixed or if we need to replan the whole path.
	 */
	function CheckError(buildResult);
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
function WaterPathBuilder::CheckError(buildLocation)
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
				if (AIMarine.BuildBuoy(buildLocation) && AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY && AIError.GetLastError() != AIRoad.ERR_ROAD_WORKS_IN_PROGRESS)
					return true;
				AIController.Sleep(1);
			}
				
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
			AISign.BuildSign(buildLocation, "BOUY!");
			Log.logDebug("Couldn't build a bouy: " + AIError.GetLastErrorString());
			return true;
			
		// Trival onces:
		case AIError.ERR_ALREADY_BUILT:
		case AIRoad.ERR_ROAD_CANNOT_BUILD_ON_TOWN_ROAD:
			return true;
			
		// Unsolvable ones:
		case AIError.ERR_PRECONDITION_FAILED:
			Log.logError("Build from " + AIMap.GetTileX(buildResult[0]) + ", " + AIMap.GetTileY(buildResult[0]) + " to " + AIMap.GetTileX(buildResult[1]) + ", " + AIMap.GetTileY(buildResult[1]) + " tileType: " + buildResult[2]);
			Log.logError("Precondition failed for the creation of a roadpiece, this cannot be solved!");
			Log.logError("/me slaps developer! ;)");
			assert(false);
			
		default:
			Log.logError("Unhandled error message: " + AIError.GetLastErrorString() + "!");
			return false;
	}
}

function WaterPathBuilder::RealiseConnection()
{
	{
	local test = AIExecMode();
	return BuildPath(connection.pathInfo.roadList);
	}
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 * If something goes wrong during the building process the fallBackMethod
 * is called to handle things for us.
 */
function WaterPathBuilder::BuildPath(roadList)
{
	if(roadList == null || roadList.len() < 2)
		return false;

	local newRoadList = [];
	newRoadList.push(roadList[0]);
	local buildFromIndex = roadList.len() - 1;
	local currentDirection = roadList[roadList.len() - 2].direction;
	local buoyBuildTimeout = 10;

	for(local a = roadList.len() - 2; -1 < a; a--) {

		if (buoyBuildTimeout != 0 && --buoyBuildTimeout != 0)
			continue;
		local direction = roadList[a].direction;
		
		/**
		 * Every time we make a call to the OpenTTD engine (i.e. build something) we hand over the
		 * control to the next AI, therefor we try to envoke as less calls as posible by building
		 * large segments of roads at the time instead of single tiles.
		 */
		if (direction != currentDirection) {

			// Check if we don't encounter a buoy 10 steps from now
			local min = a - 10;
			local hasFutureBuoy = false;
			for (local b = a - 1; -1 < b && min < b; b--)  {
				if (AIMarine.IsBuoyTile(roadList[b].tile)) {
					hasFutureBuoy = true;
					break;
				}
			}

			if (hasFutureBuoy)
				continue;
	
			// Check if there is no buoy directly next to this one.
			local hasBuoyCloseby = false;
			foreach (tile in Tile.GetTilesAround(roadList[a + 1].tile, true)) {
				if (AIMarine.IsBuoyTile(tile)) {
					local newAT = clone roadList[a + 1];
					newAT.tile = tile;	
					newRoadList.push(newAT);
					hasBuoyCloseby = true;
					break;
				}
			}

			if (hasBuoyCloseby)
				continue;
				
			if (!AIMarine.IsBuoyTile(roadList[a + 1].tile) && !AIMarine.BuildBuoy(roadList[a + 1].tile) && !WaterPathBuilder.CheckError(roadList[a + 1].tile)) {
				AISign.BuildSign(roadList[a + 1].tile, "ERROR");
				return false;
			} else
				buoyBuildTimeout = 20;

			newRoadList.push(roadList[a + 1]);

			currentDirection = direction;
		}

	}
	
	newRoadList.push(roadList[roadList.len() - 1]);
	roadList = newRoadList;
	return true;
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function WaterPathBuilder::GetCostForRoad(roadList)
{
	local test = AITestMode();			// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs
	
	WaterPathBuilder.BuildPath(roadList);

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
}
