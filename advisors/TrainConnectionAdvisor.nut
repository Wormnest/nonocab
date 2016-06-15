/**
 * Handle all new road connections.
 */
class TrainConnectionAdvisor extends ConnectionAdvisor {
	
//	pathFinder = null;
	allowTownToTownConnections = null;

	constructor(world, worldEventManager, connectionManager, allowTownToTown) {
		ConnectionAdvisor.constructor(world, worldEventManager, AIVehicle.VT_RAIL, connectionManager);
		allowTownToTownConnections = allowTownToTown;
	}
}

function TrainConnectionAdvisor::GetBuildAction(connection) {
	return BuildRailAction(connection, true, true);
}

/**
 * Calculate the path to realise a connection between the nodes in the report.
 */
function TrainConnectionAdvisor::GetPathInfo(report) {

	// Don't do towns! Takes to long for the pathfinder sometimes...	
	if (report.connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE && !allowTownToTownConnections)
		return null;
	local stationType = AIStation.STATION_TRAIN; 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	// Check which rail type is best for this connection.
	local bestRailType = TrainConnectionAdvisor.GetBestRailType(report.transportEngineID);
	local pathFindingHelper = RailPathFinderHelper(bestRailType);
	pathFindingHelper.updateClosedList = false;
	local pathFinder = RoadPathFinding(pathFindingHelper);

	local pathInfo = pathFinder.FindFastestRoad(report.connection.travelFromNode.GetAllProducingTiles(report.connection.cargoID, stationRadius, 1, 1), report.connection.travelToNode.GetAllAcceptingTiles(report.connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.connection.travelFromNode.GetLocation(), report.connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	if (pathInfo == null)
		Log.logDebug("No path for connection: " + report.connection.ToString() + ".");
	return pathInfo;
}

/**
 * Given an engineID, give the best rails to build for it.
 * @todo Since this is called so often we should think of caching best railtype per engineID.
 * However since railtypes can become unavailable and new types introduced it needs to be rechecked regularly.
 * Do we get a notice when there is a change in available railtypes?
 */
function TrainConnectionAdvisor::GetBestRailType(engineID) {
	if (!AIEngine.IsValidEngine(engineID))
		return AIRail.RAILTYPE_INVALID;

	local l = AIRailTypeList();
	local bestRailType = AIRail.RAILTYPE_INVALID;
	foreach (rt, index in l) {
		if (AIRail.IsRailTypeAvailable(rt) && 
		    AIEngine.CanRunOnRail(engineID, rt) &&
		    AIEngine.HasPowerOnRail(engineID, rt) &&
		    AIRail.GetMaxSpeed(rt) > AIRail.GetMaxSpeed(bestRailType)) {
			bestRailType = rt;
		}
	}
	//Log.logWarning("Best rail type: " + AIRail.GetName(bestRailType) + " for engine " + AIEngine.GetName(engineID));
	return bestRailType;
}
