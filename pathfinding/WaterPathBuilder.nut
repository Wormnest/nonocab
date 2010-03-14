
/**
 * Path builder who handles all aspects of building a road (including roadstations and depots).
 */
class WaterPathBuilder {

	roadList = null;
	
	/**
	 * @param connection The connection to be realised.
	 * @param pathFixer The path fixer instance to use when things go wrong.
	 */
	constructor(roadList) {
		this.roadList = roadList;
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
			//AISign.BuildSign(buildLocation, "BOUY!");
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
	return BuildPath(roadList);
	}
}

/**
 * We create a path through the water for our boats. Because applying A*
 * to the ingame pathfinding is quite hard, the pathfinding capabilities
 * of ships are quite bad. Therefor we need to build buoys to lead our
 * ships in the good direction. We don't want to build to many and not to
 * close together!
 */
function WaterPathBuilder::BuildPath(roadList) {

	if(roadList == null || roadList.len() < 2)
		return false;

	local buildFromIndex = roadList.len() - 1;
	local currentDirection = roadList[roadList.len() - 2].direction;
	local buoyBuildTimeout = 5;

	for(local a = roadList.len() - 2; 5 < a; a--) {

		// If we recently saw / build a buoy we add an additional timeout
		// constraint.
		if (--buoyBuildTimeout > 0)
			continue;
		else if(buoyBuildTimeout == 0)
			currentDirection = roadList[a].direction;
				
		local direction = roadList[a].direction;
		local currentTile = roadList[a + 1].tile;
		
		/**
		 * Every time the path changed direction we build an aditional buoy to guide the ships. The pathfinding
		 * is truely idiotic so there is no need to be smart here. We also impose a buoy every 25 tiles, I am
		 * not sure what the maximal distance is a ship can travel without guidance, but even if the connection
		 * is a straight line over 100 tiles, it will fail.
		 */
		if (direction != currentDirection || buoyBuildTimeout == -25) {
	
			// Check if there is no buoy close to this tile.
			local list = Tile.GetRectangle(currentTile, 5, 5);
			list.Valuate(AIMarine.IsBuoyTile);
			list.KeepValue(1);
			
			// If there is a buoy we check if we can reach it by the fastest way
			// possible, if not we might add a buoy ourselves!
			if(list.Count() > 0) {

				local localBuoy = null;
				local foundLocalBuoy = false;
			
				// Check if we can reach at least one of them in a straight line!
				foreach (buoyTile, value in list) {
				
					local buoyX = AIMap.GetTileX(buoyTile);
					local buoyY = AIMap.GetTileY(buoyTile);
					local tmpX = AIMap.GetTileX(currentTile);
					local tmpY = AIMap.GetTileY(currentTile);
					
					// Get the shortest path and see if we can go here :).
					local deltaX = tmpX - buoyX;
					local deltaY = tmpY - buoyY;
					local directionX = (deltaX > 0 ? -1 : 1);
					local directionY = (deltaY > 0 ? -1 : 1);
					local mapSizeX = AIMap.GetMapSizeX();

					foundLocalBuoy = true;
					
					while (tmpX != buoyX && tmpY != buoyY) {
						if (tmpX != buoyX)
							tmpX += directionX;
						if (tmpY != buoyY)
							tmpY += directionY;
							
						local tmpTile = tmpX + mapSizeX * tmpY;
						if (AIMarine.IsBuoyTile(tmpTile)) {
							buoyTile = tmpTile;
							break;
						}
							 
						if (!AITile.IsWaterTile(tmpTile)) {
							foundLocalBuoy = false;
							break;
						}
					}
					
					// If we can find one of the buoys we call it a day =).
					if (foundLocalBuoy) {
						localBuoy = buoyTile;
						roadList[a + 1].tile = localBuoy;
						break;
					}
				}
				
				// Buoy is found, so add a timeout.
				if (localBuoy != null) {
					buoyBuildTimeout = 5;
					continue;
				}
			}
			
			// Check if we need to build an additional buoy.
			if (!AIMarine.IsBuoyTile(currentTile) && !AIMarine.BuildBuoy(currentTile) && !WaterPathBuilder.CheckError(currentTile)) {
				//AISign.BuildSign(currentTile, "ERROR");
				return false;
			} else
				buoyBuildTimeout = 5;

			currentDirection = direction;
		}
	}
	
	return true;
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function WaterPathBuilder::GetCostForRoad()
{
	local test = AITestMode();			// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs
	
	WaterPathBuilder.BuildPath(roadList);

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
}
