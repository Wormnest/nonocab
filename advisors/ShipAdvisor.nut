/**
 * This class handles all new aircraft connections. For the moment we only focus on 
 * town <-> town connections, see UpdateIndustryConnections for more details.
 */
class ShipAdvisor extends ConnectionAdvisor {

	pathFinder = null;

	constructor (world) {
		ConnectionAdvisor.constructor(world, AIVehicle.VEHICLE_WATER);
		local pathFindingHelper = WaterPathFinderHelper();
		pathFinder = RoadPathFinding(pathFindingHelper);
	}
}

function ShipAdvisor::GetMinNrReports(loopCounter) {
	return loopCounter;
}

function ShipAdvisor::GetBuildAction(connection) {
	return BuildShipYardAction(connection, world);
}

function ShipAdvisor::AcceptConnectionNode(connectionNode) {
	return true;
	if (connectionNode.isNearWater)
		return true;
	return false;
}

function ShipAdvisor::GetPathInfo(report) {
//	if (!report.fromConnectionNode.isNearWater || !report.toConnectionNode.isNearWater)
//		return null;
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local stationType = AIStation.STATION_DOCK;
	local producingTiles = report.fromConnectionNode.GetProducingTiles(report.cargoID, stationRadius, 1, 1);
	local acceptingTiles = report.toConnectionNode.GetAcceptingTiles(report.cargoID, stationRadius, 1, 1);

	producingTiles.Valuate(AITile.IsCoastTile);
	producingTiles.KeepValue(1);

	acceptingTiles.Valuate(AITile.IsCoastTile);
	acceptingTiles.KeepValue(1);

	if (producingTiles.Count() == 0 || acceptingTiles.Count() == 0) {
		ignoreTable[report.fromConnectionNode.GetUID(report.cargoID) + "_" + report.toConnectionNode.GetUID(report.cargoID)] <- null;
		return null;
	}
		
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.5);
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	return pathInfo;
}

