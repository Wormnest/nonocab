/**
 * Handle all new road connections.
 */
class RoadConnectionAdvisor extends ConnectionAdvisor {
	
	pathFinder = null;

	constructor(world) {
		ConnectionAdvisor.constructor(world, AIVehicle.VEHICLE_ROAD);
		local pathFindingHelper = RoadPathFinderHelper();
		pathFindingHelper.costTillEnd = pathFindingHelper.costForNewRoad;
		pathFinder = RoadPathFinding(pathFindingHelper);
	}
}

function RoadConnectionAdvisor::GetMinNrReports(loopCounter) {
	return 5 + loopCounter;
}

function RoadConnectionAdvisor::GetBuildAction(report) {
	return BuildRoadAction(report.connection, true, true, world, AIEngine.GetRoadType(report.engineID));
}

/**
 * Calculate the path to realise a connection between the nodes in the report.
 */
function RoadConnectionAdvisor::GetPathInfo(report) {

	local stationType = (!AICargo.HasCargoClass(report.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	local pathInfo = pathFinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(report.cargoID, stationRadius, 1, 1), report.toConnectionNode.GetAcceptingTiles(report.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.5);
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	return pathInfo;
}
