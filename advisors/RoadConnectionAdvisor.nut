/**
 * Handle all new road connections.
 */
class RoadConnectionAdvisor extends ConnectionAdvisor {
	
	pathFinder = null;

	constructor(world, worldEventManager, connectionManager) {
		ConnectionAdvisor.constructor(world, worldEventManager, AIVehicle.VT_ROAD, connectionManager);
		local pathFindingHelper = RoadPathFinderHelper(false);
		//pathFindingHelper.costTillEnd = pathFindingHelper.costForNewRoad + 10;
		pathFinder = RoadPathFinding(pathFindingHelper);
	}
}

function RoadConnectionAdvisor::GetBuildAction(connection) {
	return BuildRoadAction(connection, true, true);
}

/**
 * Calculate the path to realise a connection between the nodes in the report.
 */
function RoadConnectionAdvisor::GetPathInfo(report) {

	local stationType = (!AICargo.HasCargoClass(report.connection.cargoID, AICargo.CC_PASSENGERS) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP); 
	local stationRadius = AIStation.GetCoverageRadius(stationType);

	pathFinder.pathFinderHelper.SetStationBuilder(AIEngine.IsArticulated(report.transportEngineID));

	local pathInfo = pathFinder.FindFastestRoad(report.connection.travelFromNode.GetProducingTiles(report.connection.cargoID, stationRadius, 1, 1), report.connection.travelToNode.GetAcceptingTiles(report.connection.cargoID, stationRadius, 1, 1), true, true, stationType, AIMap.DistanceManhattan(report.connection.travelFromNode.GetLocation(), report.connection.travelToNode.GetLocation()) * 1.2 + 20, null);
	if (pathInfo == null)
		Log.logDebug("No path for connection: " + report.connection.ToString() + ".");
	return pathInfo;
}
