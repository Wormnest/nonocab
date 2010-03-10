/**
 * Handle all new road connections.
 */
class TrainConnectionAdvisor extends ConnectionAdvisor {
	
	pathFinder = null;

	constructor(world, connectionManager) {
		ConnectionAdvisor.constructor(world, AIVehicle.VT_RAIL, connectionManager);
		local pathFindingHelper = RailPathFinderHelper();
 		pathFindingHelper.costForRail = 10;
 		pathFindingHelper.costForNewRail = 10;
 		pathFindingHelper.costForTurn = 10;
 		pathFindingHelper.costForBridge = 10;
 		pathFindingHelper.costForTunnel = 10;
 		pathFindingHelper.costForSlope 	= 10;
 		pathFindingHelper.costTillEnd = 20;
//		pathFindingHelper.costTillEnd = pathFindingHelper.costForNewRail + 10;
		pathFindingHelper.updateClosedList = false;
		pathFinder = RoadPathFinding(pathFindingHelper);
	}
}

function TrainConnectionAdvisor::GetBuildAction(connection) {
	return BuildRailAction(connection, true, true, world);
}

/**
 * Calculate the path to realise a connection between the nodes in the report.
 */
function TrainConnectionAdvisor::GetPathInfo(report) {

	// Don't do towns! Takes to long for the pathfinder sometimes...	
	if (report.fromConnectionNode.nodeType == ConnectionNode.TOWN_NODE)
		return null;
	local stationType = (!AICargo.HasCargoClass(report.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	local pathInfo = pathFinder.FindFastestRoad(report.fromConnectionNode.GetAllProducingTiles(report.cargoID, stationRadius, 1, 1), report.toConnectionNode.GetAllAcceptingTiles(report.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.2 + 20, null);
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	Log.logDebug("Path found!");
	return pathInfo;
}
