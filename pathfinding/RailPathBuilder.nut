/**
 * Path builder who handles all aspects of building a road (including roadstations and depots).
 */
class RailPathBuilder {

	maxSpeed = null;
	pathFixer = null;
	roadList = null;
	lastBuildIndex = null;
	stationIDsConnectedTo = null;
	
	/**
	 * @param connection The connection to be realised.
	 * @param maxSpeed The max speed of the vehicles which are going to use this connection.
	 * @param pathFixer The path fixer instance to use when things go wrong.
	 */
	constructor(roadList, maxSpeed, pathFixer) {
		this.roadList = roadList;
		this.maxSpeed = maxSpeed;
		this.pathFixer = pathFixer;
		lastBuildIndex = -1;
		stationIDsConnectedTo = [];
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
}

function RailPathBuilder::CheckPath(roadList)
{
	return true;
}

function RailPathBuilder::RealiseConnection(buildRoadStations)
{
	// Check if we have enough money...
	local estimatedCost = GetCostForRoad();
	lastBuildIndex = -1;
	if (estimatedCost > Finance.GetMaxMoneyToSpend()) {
		Log.logWarning("Not enough money, aborting construction!");
		return false;
	}
	
	{
		local test = AIExecMode();
		
		return BuildPath(roadList, false);
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
	local railPathHelper = RailPathFinderHelper();
	local stationsToIgnore = [];
	
	if (!estimateCost) {
		local stationIDBegin = AIStation.GetStationID(roadList[0].tile);
		local stationIDEnd = AIStation.GetStationID(roadList[roadList.len() - 1].tile);
		
		if (AIStation.IsValidStation(stationIDBegin))
			stationsToIgnore.push(stationIDBegin);
		if (AIStation.IsValidStation(stationIDEnd))
			stationsToIgnore.push(stationIDEnd);
			
		assert (stationsToIgnore.len() != 0);
	}
	
	//for(local a = 0; a < roadList.len(); a++) {
	//	AISign.BuildSign(roadList[a].tile, "X");
	//}
	
	Log.logDebug("Build path (rail)");
	if(roadList == null || roadList.len() < 3)
		return false;

	local mapSizeX = AIMap.GetMapSizeX();
	local connectingStationIDs = [];

	for(local a = roadList.len() - 1; -1 < a; a--) {

		if (roadList[a].type == Tile.ROAD) {
			//AIRail.BuildRailTrack(roadList[a].tile, roadList[a].lastBuildRailTrack);
			local tile = roadList[a].tile;
			local railTrack = roadList[a].lastBuildRailTrack;
			if (!AIRail.BuildRailTrack(tile, railTrack) && !estimateCost) { 
				if (!AICompany.IsMine(AITile.GetOwner(tile)) || AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_INVALID || (AIRail.GetRailTracks(tile) & railTrack) == 0) {
					lastBuildIndex = a + 1;
					return false;
				} else if (a < roadList.len() - 1) {
					local abc = AITestMode();
					//Log.logWarning("Check station");
					// Connected to an existing rail, check which station this is connected to!
					//local station = railPathHelper.CheckStation(tile, railTrack, roadList[a].direction, stationsToIgnore);
					local station = railPathHelper.CheckStation(roadList[a + 1].tile, roadList[a + 1].lastBuildRailTrack, roadList[a + 1].direction, stationsToIgnore);

					local foundStationID = AIStation.GetStationID(station);
					if (AIStation.IsValidStation(foundStationID)) {
						// Make sure not to add the same twice.
						local alreadyAdded = false;
						for (local i = 0; i < stationIDsConnectedTo.len(); i++) {
							if (stationIDsConnectedTo[i] == foundStationID) {
								alreadyAdded = true;
								break;
							}
						}
						
						if (!alreadyAdded)
							stationIDsConnectedTo.push(foundStationID);
					}
				}
			}

		} else if (roadList[a].type == Tile.TUNNEL) {

			if (!AITunnel.IsTunnelTile(roadList[a + 1].tile + roadList[a].direction)) {
				if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, roadList[a + 1].tile + roadList[a].direction) && !estimateCost) {
					lastBuildIndex = a + 1;
					return false;
				}
			}
		} 

		else if (roadList[a].type == Tile.BRIDGE) {
			if (!AIBridge.IsBridgeTile(roadList[a + 1].tile + roadList[a].direction)) {
			
				local length = (roadList[a].tile - roadList[a + 1].tile) / roadList[a].direction;
				if (length < 0)
					length = -length;		
				
				local bridgeTypes = AIBridgeList_Length(length);
				local bestBridgeType = null;
				for (local bridge = bridgeTypes.Begin(); bridgeTypes.HasNext(); bridge = bridgeTypes.Next()) {
					assert (AIBridge.IsValidBridge(bridge));
					if (bestBridgeType == null || AIBridge.GetMaxSpeed(bridge) >= AIBridge.GetMaxSpeed(bestBridgeType))
						bestBridgeType = bridge;
				}
			
				// Connect the bridge to the other end. Because the first road tile after the bridge has to
				// be straight, we have to substract a tile in the opposite direction from where the bridge is
				// going. Because we calculated the pathlist in the other direction, the direction is in the
				// opposite direction so we need to add it.
				if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bestBridgeType, roadList[a + 1].tile + roadList[a].direction, roadList[a].tile) && !estimateCost) {
					lastBuildIndex = a + 1;
					return false;
				}

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
	Log.logDebug("Get cost for rail");
	
	if(roadList == null || roadList.len() < 3)
		return 0;

	local currentRailType = AIRail.GetCurrentRailType();
	local costs = 0;
	local accounting = AIAccounting();
	local test = AITestMode();

	BuildPath(roadList, true);

	costs += AIRail.GetBuildCost(currentRailType, AIRail.BT_STATION) * 2 * 3 * 2;
	costs += AIRail.GetBuildCost(currentRailType, AIRail.BT_SIGNAL) * roadList.len() / 6;
	costs += AIRail.GetBuildCost(currentRailType, AIRail.BT_DEPOT);
	costs += AIRail.GetBuildCost(currentRailType, AIRail.BT_TRACK) * 10;

	return costs + accounting.GetCosts();
}
