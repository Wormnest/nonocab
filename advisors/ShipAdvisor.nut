/**
 * This class handles all new ship connections.
 */
class ShipAdvisor extends ConnectionAdvisor {

	pathFinder = null;

	constructor (world, worldEventManager, connectionManager) {
		ConnectionAdvisor.constructor(world, worldEventManager, AIVehicle.VT_WATER, connectionManager);
		local pathFindingHelper = WaterPathFinderHelper();
		pathFindingHelper.costTillEnd = Tile.diagonalRoadLength;
		pathFinder = RoadPathFinding(pathFindingHelper);
	}
}

function ShipAdvisor::GetBuildAction(connection) {
	return BuildShipYardAction(connection);
}

function ShipAdvisor::GetPathInfo(report) {
	local fromNode = report.connection.travelFromNode;
	local toNode = report.connection.travelToNode;
	if ((!fromNode.isNearWater && fromNode.nodeType != ConnectionNode.INDUSTRY_NODE && !AIIndustry.IsBuiltOnWater(fromNode.id)) || 
		(!toNode.isNearWater && toNode.nodeType != ConnectionNode.INDUSTRY_NODE && !AIIndustry.IsBuiltOnWater(toNode.id)))
		return null;
			
	local stationType = AIStation.STATION_DOCK;
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	local producingTiles = fromNode.GetAllProducingTiles(report.connection.cargoID, stationRadius, 1, 1);
	local acceptingTiles = toNode.GetAllAcceptingTiles(report.connection.cargoID, stationRadius, 1, 1);

	if (!(fromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(fromNode.id))) {
		producingTiles.Valuate(AITile.IsCoastTile);
		producingTiles.KeepValue(1);

		if (fromNode.nodeType == ConnectionNode.TOWN_NODE) {
			producingTiles.Valuate(AITile.GetCargoAcceptance, report.connection.cargoID, 1, 1, stationRadius);
			producingTiles.Sort(AIList.SORT_BY_VALUE, false);
			producingTiles.KeepTop(5);
		}
	} else {
		producingTiles.Valuate(AITile.IsWaterTile);
		producingTiles.KeepValue(1);
		pathFinder.pathFinderHelper.startLocationIsBuildOnWater = true;
	}

	if (!(toNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(toNode.id))) {
		acceptingTiles.Valuate(AITile.IsCoastTile);
		acceptingTiles.KeepValue(1);

		if (toNode.nodeType == ConnectionNode.TOWN_NODE) {
			acceptingTiles.Valuate(AITile.GetCargoAcceptance, report.connection.cargoID, 1, 1, stationRadius);
			acceptingTiles.Sort(AIList.SORT_BY_VALUE, false);
			acceptingTiles.KeepTop(5);
		}
	} else {
		acceptingTiles.Valuate(AITile.IsWaterTile);
		acceptingTiles.KeepValue(1);	
		pathFinder.pathFinderHelper.endLocationIsBuildOnWater = true;
	}

	if (producingTiles.Count() == 0 || acceptingTiles.Count() == 0) {
		ignoreTable[fromNode.GetUID(report.connection.cargoID) + "_" + toNode.GetUID(report.connection.cargoID)] <- null;
		return null;
	}
		
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(fromNode.GetLocation(), toNode.GetLocation()) * 1.2 + 20, null);
	
	pathFinder.pathFinderHelper.startLocationIsBuildOnWater = false;
	pathFinder.pathFinderHelper.endLocationIsBuildOnWater = false;
	if (pathInfo == null) {
		ignoreTable[fromNode.GetUID(report.connection.cargoID) + "_" + toNode.GetUID(report.connection.cargoID)] <- null;
		Log.logDebug("No path for connection: " + report.connection.ToString() + ".");
	}
	return pathInfo;
}

