/**
 * Action class for the creation of ship yards.
 */
class BuildShipYardAction extends Action {
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	static shipYardCosts = {};		// Table which holds the costs per shipYard type and the date when they were calculated.
						// Tuple: [calculation_date, cost].
	
	constructor(connection, world) {
		this.connection = connection;
		this.world = world;
		Action.constructor();
	}
}


function BuildShipYardAction::Execute() {

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
			producingTiles.KeepTop(1);
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
			acceptingTiles.KeepTop(1);
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
	
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(fromNode.GetLocation(), toNode.GetLocation()) * 3);

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

	/* Now build some docks... */
	connection.pathInfo.depot = BuildDepot(roadList);
	if (connection.pathInfo.depot == null)
		return false;

	if (connection.bilateralConnection) {
		connection.pathInfo.depotOtherEnd = BuildDepot(roadList);
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
		
	connection.UpdateAfterBuild(AIVehicle.VT_WATER, fromTile, toTile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK))

	CallActionHandlers();
	return true;
}

function BuildShipYardAction::BuildDepot(roadList) {

	local depotLoc = null;
	for (local i = roadList.len() - 3; i > 2; i--) {
		
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
 * Find a good location to build an airfield and return it.
 * @param shipYardType The type of shipYard which needs to be build.
 * @param node The connection node where the shipYard needs to be build.
 * @param cargoID The cargo that needs to be transported.
 * @param acceptingSide If true this side is considered as begin the accepting side of the connection.
 * @param getFirst If true ignores the exclude list and gets the first suitable spot to build an airfield.
 * @return The tile where the shipYard can be build.
 */
function BuildShipYardAction::FindSuitableShipYardSpot(node, cargoID, acceptingSide) {
    local shipYardRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local tile = node.GetLocation();
	local excludeList;
	if (node.nodeType == ConnectionNode.TOWN_NODE) {
		excludeList = clone node.excludeList;
		node.excludeList = {};
	}

	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID, shipYardRadius, 1, 1) : node.GetAllProducingTiles(cargoID, shipYardRadius, 1, 1));
	if (node.nodeType == ConnectionNode.TOWN_NODE)
		node.excludeList = excludeList;

    /* Couldn't find a suitable place for this town, skip to the next */
    if (list.Count() == 0) return;
	local good_tile = 0;
    /* Walk all the tiles and see if we can build the shipYard at all */
    {
        local test = AITestMode();

        for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
            if (!AIMarine.BuildDock(tile, AIStation.STATION_NEW)) continue;
	        good_tile = tile;
			break;
	    }
	}
	if (good_tile == 0)
		return -1;
	return good_tile;
}

/**
 * Return the cost to build an shipYard at the given node. Once the cost for one type
 * of shipYard is calculated it is cached for little less then a year after which it
 * is reevaluated.
 * @param node The connection node where the shipYard needs to be build.
 * @param cargoID The cargo the connection should transport.
 * @param acceptingSide If true it means that the node will be evaluated as the accepting side.
 * @param useCache If true the result will be retrieved from cache, no check is made to see
 * if the shipYard can actually be build!
 * @return The total cost of building the shipYard.
 */
function BuildShipYardAction::GetShipYardCost(node, cargoID, acceptingSide, useCache) {
	local accounter = AIAccounting();
	local shipYardType = AIStation.STATION_DOCK;

	if (useCache && BuildShipYardAction.shipYardCosts.rawin("" + shipYardType)) {
		
		local shipYardCostTuple = BuildShipYardAction.shipYardCosts.rawget("" + shipYardType);
		if (Date.GetDaysBetween(AIDate.GetCurrentDate(), shipYardCostTuple[0]) < 300)
			return shipYardCostTuple[1];
	}

	if (BuildShipYardAction.FindSuitableShipYardSpot(node, cargoID, acceptingSide) < 0)
		return -1;

	if (useCache)
		BuildShipYardAction.shipYardCosts["" + shipYardType] <- [AIDate.GetCurrentDate(), accounter.GetCosts()];
	return accounter.GetCosts();
}
