/**
 * Handle all new road connections.
 */
class TrainConnectionAdvisor extends ConnectionAdvisor {
	
//	pathFinder = null;
	allowTownToTownConnections = null;

	constructor(world, connectionManager, allowTownToTown) {
		ConnectionAdvisor.constructor(world, AIVehicle.VT_RAIL, connectionManager);
		allowTownToTownConnections = allowTownToTown;
/*		local pathFindingHelper = RailPathFinderHelper();
		pathFindingHelper.updateClosedList = false;
		pathFinder = RoadPathFinding(pathFindingHelper);
*/
	}
}

function TrainConnectionAdvisor::GetBuildAction(connection) {
	return BuildRailAction(connection, true, true, world);
}

/**
 * Calculate the path to realise a connection between the nodes in the report.
 */
function TrainConnectionAdvisor::GetPathInfo(report) {

	if (AICargo.HasCargoClass(report.cargoID, AICargo.CC_MAIL))
		return null;
	// Don't do towns! Takes to long for the pathfinder sometimes...	
	if (report.fromConnectionNode.nodeType == ConnectionNode.TOWN_NODE && !allowTownToTownConnections)
		return null;
	local stationType = AIStation.STATION_TRAIN; 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	

	// Check which rail type is best for this connection.
	local bestRailType = TrainConnectionAdvisor.GetBestRailType(report.transportEngineID);
	local pathFindingHelper = RailPathFinderHelper(bestRailType);
	pathFindingHelper.updateClosedList = false;
	local pathFinder = RoadPathFinding(pathFindingHelper);

	local pathInfo = pathFinder.FindFastestRoad(report.fromConnectionNode.GetAllProducingTiles(report.cargoID, stationRadius, 1, 1), report.toConnectionNode.GetAllAcceptingTiles(report.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.2 + 20, null);
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	Log.logDebug("Path found!");
	return pathInfo;
}

/**
 * Given an engineID, give the best rails to build for it.
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
//	if (bestRailType == AIRail.RAILTYPE_INVALID)
//		Log.logWarning("No rail type for engine: " + AIEngine.GetName(engineID));
	return bestRailType;
}
