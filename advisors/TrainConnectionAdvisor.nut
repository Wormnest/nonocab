/**
 * Handle all new road connections.
 */
class TrainConnectionAdvisor extends ConnectionAdvisor {
	
	pathFinder = null;

	constructor(world, connectionManager) {
		ConnectionAdvisor.constructor(world, AIVehicle.VT_RAIL, connectionManager);
		local pathFindingHelper = RailPathFinderHelper();
		pathFindingHelper.costTillEnd = pathFindingHelper.costForNewRail + 10;
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
//	if (report.fromConnectionNode.nodeType == ConnectionNode.TOWN_NODE)
//		return null;
	local stationType = (!AICargo.HasCargoClass(report.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	local pathInfo = pathFinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(report.cargoID, stationRadius, 1, 1), report.toConnectionNode.GetAcceptingTiles(report.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.2 + 20);
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	Log.logDebug("Path found!");
	return pathInfo;
}
