/**
 * Action class for the creation of ship yards.
 */
class BuildShipYardAction extends Action {
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	
	constructor(connection, world) {
		this.connection = connection;
		this.world = world;
		Action.constructor();
	}
}


function BuildShipYardAction::Execute() {	

	local accounter = AIAccounting();
	local pathFindingHelper = WaterPathFinderHelper();
	local pathFinder = RoadPathFinding(pathFindingHelper);

	local stationType = AIStation.STATION_DOCK;
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	local fromNode = connection.travelFromNode;
	local toNode = connection.travelToNode;
	local producingTiles = fromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1);
	local acceptingTiles = toNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1);


	if (!(fromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(fromNode.id))) {
		producingTiles.Valuate(AITile.IsCoastTile);
		producingTiles.KeepValue(1);

		if (fromNode.nodeType == ConnectionNode.TOWN_NODE) {
			producingTiles.Valuate(AITile.GetCargoAcceptance, connection.cargoID, 1, 1, stationRadius);
			producingTiles.Sort(AIAbstractList.SORT_BY_VALUE, false);
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
			acceptingTiles.Valuate(AITile.GetCargoAcceptance, connection.cargoID, 1, 1, stationRadius);
			acceptingTiles.Sort(AIAbstractList.SORT_BY_VALUE, false);
			acceptingTiles.KeepTop(5);
		}
	} else {
		acceptingTiles.Valuate(AITile.IsWaterTile);
		acceptingTiles.KeepValue(1);	
		pathFinder.pathFinderHelper.endLocationIsBuildOnWater = true;
	}

	if (producingTiles.Count() == 0 || acceptingTiles.Count() == 0) {
		connection.forceReplan = true;
		return false;
	}
	
	// Check if we have enough permission to build here.
	if (AITown.GetRating(AITile.GetClosestTown(producingTiles.Begin()), AICompany.COMPANY_SELF) < -200)
		return false;
		
	// Check if we have enough permission to build here.
	if (AITown.GetRating(AITile.GetClosestTown(acceptingTiles.Begin()), AICompany.COMPANY_SELF) < -200)
		return false;	
	
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(fromNode.GetLocation(), toNode.GetLocation()) * 3, null);

	if (pathInfo == null) {
		connection.forceReplan = true;
		return false;
	}
	connection.pathInfo = pathInfo;
	local roadList = connection.pathInfo.roadList;
	local toTile = roadList[0].tile;
	local fromTile = roadList[roadList.len() - 1].tile;

	/* Build the shipYards for real */
	if (!(connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelFromNode.id)) && !AIMarine.BuildDock(fromTile, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 shipYards, it still failed on the first shipYard at tile " + AIError.GetLastErrorString());
		connection.forceReplan = true;
		return false;
	}

	if (!(connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelToNode.id)) && !AIMarine.BuildDock(toTile, AIStation.STATION_NEW)) {
		AILog.Error("Although the testing told us we could build 2 shipYards, it still failed on the second shipYard at tile." + AIError.GetLastErrorString());
		connection.forceReplan = true;
		AIMarine.RemoveDock(fromTile);
		return false;
	}

	local waterBuilder = WaterPathBuilder(connection.pathInfo.roadList);
	if (!waterBuilder.RealiseConnection()) {
		AILog.Error("Couldn't build the water way!");
		return false;
	}
		
	local start = AnnotatedTile();
	start.tile = fromTile;
	local end = AnnotatedTile();
	end.tile = toTile;

	/* Now build some depots... */
	connection.pathInfo.depot = BuildDepot(roadList, true);
	if (connection.pathInfo.depot == null)
		return false;

	if (connection.bilateralConnection) {
		connection.pathInfo.depotOtherEnd = BuildDepot(roadList, false);
		if (connection.pathInfo.depotOtherEnd == null)
			return false;
	}


	// Reconstruct road list.
	local newRoadList = [end];
	if (connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelToNode.id))
		end.tile = connection.travelToNode.GetLocation();
	
	foreach (at in connection.pathInfo.roadList)
		if (AIMarine.IsBuoyTile(at.tile))
			newRoadList.push(at);
	newRoadList.push(start);
	if (connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelFromNode.id))
		start.tile = connection.travelFromNode.GetLocation();
	connection.pathInfo.roadList = newRoadList;
	connection.UpdateAfterBuild(AIVehicle.VT_WATER, start.tile, end.tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK))

	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	return true;
}

function BuildShipYardAction::BuildDepot(roadList, fromTile) {

	local depotLoc = null;
	for (local i = (fromTile ? roadList.len() - 3 : 3); i > 2; i += (fromTile ? -1 : 1)) {
		
		local pos = roadList[i].tile;
		foreach (tile in Tile.GetTilesAround(pos, false)) {
			if (AIMarine.BuildWaterDepot(pos, tile)) {
				depotLoc = pos;
				break;
			}
		}
		
		if (depotLoc)
			break;
	}

	if (!depotLoc) {
		Log.logWarning("Depot couldn't be build!");
		return null;
	}
	return depotLoc;
}

/**
 * Get the costs of building a ship connection
 */
function BuildShipYardAction::GetCosts() {
	return 2 * AIMarine.GetBuildCost(AIMarine.BT_DOCK) + AIMarine.GetBuildCost(AIMarine.BT_DEPOT) + 10 * AIMarine.GetBuildCost(AIMarine.BT_BUOY);
}
