/**
 * Action class for the creation of airfields.
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

	local roadList = connection.pathInfo.roadList;
	local toTile = roadList[0].tile;
	local fromTile = roadList[roadList.len() - 1].tile;

	/* Build the shipYards for real */
	if (!AIMarine.BuildDock(fromTile, true) && !AIMarine.BuildDock(fromTile, false)) {
	        AILog.Error("Although the testing told us we could build 2 shipYards, it still failed on the first shipYard at tile " + AIError.GetLastErrorString());
		AISign.BuildSign(fromTile, "Can't build!");
		connection.forceReplan = true;
	        return false;
	}

	if (!AIMarine.BuildDock(toTile, true) && !AIMarine.BuildDock(toTile, false)) {
	        AILog.Error("Although the testing told us we could build 2 shipYards, it still failed on the second shipYard at tile." + AIError.GetLastErrorString());
		AISign.BuildSign(toTile, "Can't build!");
		connection.forceReplan = true;
	        AIMarine.RemoveDock(fromTile);
	        return false;
	}

	local waterBuilder = WaterPathBuilder(connection);
	if (!waterBuilder.RealiseConnection()) {
		AILog.Error("Couldn't build the water way!");
		return false;
	}

	/* Now build some docks... */
	local docPositions = AITileList();
	local x = AIMap.GetTileX(fromTile);
	local y = AIMap.GetTileY(fromTile);
	local min_x = x - 10;
	local min_y = y - 10;
	local max_x = x + 10;
	local max_y = y + 10;
	if (min_x < 0) min_x = 1; else if (max_x >= AIMap.GetMapSizeX()) max_x = AIMap.GetMapSizeX() - 2;
	if (min_y < 0) min_y = 1; else if (max_y >= AIMap.GetMapSizeY()) max_y = AIMap.GetMapSizeY() - 2;
	docPositions.AddRectangle(AIMap.GetTileIndex(min_x, min_y), AIMap.GetTileIndex(max_x, max_y));
	docPositions.Valuate(AITile.IsWaterTile);
	docPositions.KeepValue(1);

	local depotLoc;
	foreach (pos, value in docPositions) {
		if (AIMarine.BuildWaterDepot(pos, true) || AIMarine.BuildWaterDepot(pos, false)) {
			depotLoc = pos;
			break;
		}
	}

	if (!depotLoc) {
		Log.logWarning("Depot couldn't be build!");
		return false;
	}
	
	local start = AnnotatedTile();
	start.tile = fromTile;
	local end = AnnotatedTile();
	end.tile = toTile;
	connection.pathInfo.depot = depotLoc;
//	connection.pathInfo.depotOtherEnd = AIShipYard.GetHangarOfShipYard(toTile);

	// Reconstruct road list.
	local newRoadList = [end];
	foreach (at in connection.pathInfo.roadList)
		if (AIMarine.IsBuoyTile(at.tile))
			newRoadList.push(at);
	newRoadList.push(start);
	connection.pathInfo.roadList = newRoadList;
	connection.pathInfo.build = true;
	connection.pathInfo.nrRoadStations++;
	connection.pathInfo.buildDate = AIDate.GetCurrentDate();
	connection.lastChecked = AIDate.GetCurrentDate();
	connection.vehicleTypes = AIVehicle.VEHICLE_WATER;
	connection.travelFromNodeStationID = AIStation.GetStationID(fromTile);
	connection.travelToNodeStationID = AIStation.GetStationID(toTile);
	connection.forceReplan = false;

	// In the case of a bilateral connection we want to make sure that
	// we don't hinder ourselves; Place the stations not to near each
	// other.
/*
	if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {
        	local shipYardRadius = AIShipYard.GetShipYardCoverageRadius(shipYardType);
		connection.travelFromNode.AddExcludeTiles(connection.cargoID, fromTile, shipYardRadius);
		connection.travelToNode.AddExcludeTiles(connection.cargoID, toTile, shipYardRadius);
	}

*/
	CallActionHandlers();
	return true;
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
function BuildShipYardAction::FindSuitableShipYardSpot(node, cargoID, acceptingSide, getFirst) {
        local shipYardRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local tile = node.GetLocation();
	local excludeList;
	if (getFirst && node.nodeType == ConnectionNode.TOWN_NODE) {
		excludeList = clone node.excludeList;
		node.excludeList = {};
	}

	local list = (acceptingSide ? node.GetAcceptingTiles(cargoID, shipYardRadius, 1, 1) : node.GetProducingTiles(cargoID, shipYardRadius, 1, 1));
	if (getFirst) {
		if (node.nodeType == ConnectionNode.TOWN_NODE)
			node.excludeList = excludeList;
	}
        
 //       list.Valuate(AITile.IsCoastTile);
 //       list.KeepValue(1);

        /* Couldn't find a suitable place for this town, skip to the next */
        if (list.Count() == 0) return;
	local good_tile = 0;
        /* Walk all the tiles and see if we can build the shipYard at all */
        {
                local test = AITestMode();
		local bestAcceptance = 0;

                for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
                        if (!AIMarine.BuildDock(tile, true)) continue;

			local currentAcceptance = AITile.GetCargoAcceptance(tile, cargoID, 1, 1, shipYardRadius);
			if (currentAcceptance > bestAcceptance) {
	                        good_tile = tile;
				bestAcceptance = currentAcceptance;
			}

			if (getFirst)
				break;
                }
        }
	if (good_tile == 0)
		return -1;
	AISign.BuildSign(good_tile, "A");
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

	if (BuildShipYardAction.FindSuitableShipYardSpot(node, cargoID, acceptingSide, true) < 0)
		return -1;

	if (useCache)
		BuildShipYardAction.shipYardCosts["" + shipYardType] <- [AIDate.GetCurrentDate(), accounter.GetCosts()];
	return accounter.GetCosts();
}
