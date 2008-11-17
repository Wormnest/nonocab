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
	return loopCounter + 2;
}

function ShipAdvisor::GetBuildAction(connection) {
	return BuildShipYardAction(connection, world);
}

function ShipAdvisor::GetPathInfo(report) {
	local fromNode = report.fromConnectionNode;
	local toNode = report.toConnectionNode;
	if ((!fromNode.isNearWater && fromNode.nodeType != ConnectionNode.INDUSTRY_NODE && !AIIndustry.IsBuiltOnWater(fromNode.id)) || 
		(!toNode.isNearWater && toNode.nodeType != ConnectionNode.INDUSTRY_NODE && !AIIndustry.IsBuiltOnWater(toNode.id)))
		return null;
			
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local stationType = AIStation.STATION_DOCK;
	local producingTiles = report.fromConnectionNode.GetAllProducingTiles(report.cargoID, stationRadius, 1, 1);
	local acceptingTiles = report.toConnectionNode.GetAllAcceptingTiles(report.cargoID, stationRadius, 1, 1);

	if (!(fromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(fromNode.id))) {
		producingTiles.Valuate(AITile.IsCoastTile);
		producingTiles.KeepValue(1);
	} else {
		producingTiles.Valuate(AITile.IsWaterTile);
		producingTiles.KeepValue(1);	
		pathFinder.pathFinderHelper.startLocationIsBuildOnWater = true;
	}

	if (!(toNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(toNode.id))) {
		acceptingTiles.Valuate(AITile.IsCoastTile);
		acceptingTiles.KeepValue(1);
	} else {
		acceptingTiles.Valuate(AITile.IsWaterTile);
		acceptingTiles.KeepValue(1);	
		pathFinder.pathFinderHelper.endLocationIsBuildOnWater = true;
	}

	if (producingTiles.Count() == 0 || acceptingTiles.Count() == 0) {
		ignoreTable[fromNode.GetUID(report.cargoID) + "_" + toNode.GetUID(report.cargoID)] <- null;
		return null;
	}
		
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.5);
	
	pathFinder.pathFinderHelper.startLocationIsBuildOnWater = false;
	pathFinder.pathFinderHelper.endLocationIsBuildOnWater = false;
	if (pathInfo == null)
		Log.logDebug("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
	return pathInfo;
}

