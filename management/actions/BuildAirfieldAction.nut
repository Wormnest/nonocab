/**
 * Action class for the creation of airfields.
	if (getFirst)
		node.excludeList = excludeList;
 */
class BuildAirfieldAction extends Action {
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	static airportCosts = {};		// Table which holds the costs per airport type and the date when they were calculated.
						// Tuple: [calculation_date, cost].
	
	constructor(connection, world) {
		this.connection = connection;
		this.world = world;
		Action.constructor();
	}
}


function BuildAirfieldAction::Execute() {

	local airportType = (AIAirport.AirportAvailable(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);

	local tile_1 = this.FindSuitableAirportSpot(airportType, connection.travelFromNode, connection.cargoID, false, false);
	if (tile_1 < 0) {
		Log.logWarning("No spot found for the first airfield!");
		connection.pathInfo.forceReplan = true;
		return false;
	}
	local tile_2 = this.FindSuitableAirportSpot(airportType, connection.travelToNode, connection.cargoID, true, false);
	if (tile_2 < 0) {
		Log.logWarning("No spot found for the second airfield!");
		connection.pathInfo.forceReplan = true;
		return false;
	}
	
	/* Build the airports for real */
	if (!AIAirport.BuildAirport(tile_1, airportType, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + tile_1 + ".");
	        return false;
	}
	if (!AIAirport.BuildAirport(tile_2, airportType, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + tile_2 + ".");
	        AIAirport.RemoveAirport(tile_1);
	        return false;
	}
	
	local start = AnnotatedTile();
	start.tile = tile_1;
	local end = AnnotatedTile();
	end.tile = tile_2;
	connection.pathInfo.depot = AIAirport.GetHangarOfAirport(tile_1);
	connection.pathInfo.depotOtherEnd = AIAirport.GetHangarOfAirport(tile_2);
	connection.pathInfo.roadList = [end, start];
	connection.pathInfo.build = true;
	connection.pathInfo.nrRoadStations++;
	connection.pathInfo.buildDate = AIDate.GetCurrentDate();
	connection.lastChecked = AIDate.GetCurrentDate();
	connection.vehicleTypes = AIVehicle.VEHICLE_AIR;
	connection.travelFromNodeStationID = AIStation.GetStationID(tile_1);
	connection.travelToNodeStationID = AIStation.GetStationID(tile_2);

	
	// In the case of a bilateral connection we want to make sure that
	// we don't hinder ourselves; Place the stations not to near each
	// other.
	if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {
        	local airport_rad = AIAirport.GetAirportCoverageRadius(airportType);
		connection.travelFromNode.AddExcludeTiles(connection.cargoID, tile_1, airport_rad);
		connection.travelToNode.AddExcludeTiles(connection.cargoID, tile_2, airport_rad);
	}

	CallActionHandlers();
	return true;
}

/**
 * Find a good location to build an airfield and return it.
 * @param airportType The type of airport which needs to be build.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo that needs to be transported.
 * @param acceptingSide If true this side is considered as begin the accepting side of the connection.
 * @param getFirst If true ignores the exclude list and gets the first suitable spot to build an airfield.
 * @return The tile where the airport can be build.
 */
function BuildAirfieldAction::FindSuitableAirportSpot(airportType, node, cargoID, acceptingSide, getFirst) {
        local airport_x = AIAirport.GetAirportWidth(airportType);
        local airport_y = AIAirport.GetAirportHeight(airportType);
        local airport_rad = AIAirport.GetAirportCoverageRadius(airportType);
	local tile = node.GetLocation();
	local excludeList;
	if (getFirst) {
		excludeList = clone node.excludeList;
		node.excludeList = {};
	}
	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID, airport_rad, airport_x, airport_y) : node.GetAllProducingTiles(cargoID, airport_rad, airport_x, airport_y));
	if (getFirst)
		node.excludeList = excludeList;
	else {
		list.Valuate(AITile.GetCargoAcceptance, cargoID, airport_x, airport_y, airport_rad);
		list.KeepAboveValue(30);
	}
        
        list.Valuate(AITile.IsBuildableRectangle, airport_x, airport_y);
        list.KeepValue(1);

        /* Couldn't find a suitable place for this town, skip to the next */
        if (list.Count() == 0) return;
	local good_tile = 0;
        /* Walk all the tiles and see if we can build the airport at all */
        {
                local test = AITestMode();
		local bestAcceptance = 0;

                for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
                        if (!AIAirport.BuildAirport(tile, airportType, true)) continue;

			local currentAcceptance = AITile.GetCargoAcceptance(tile, connection.cargoID, airport_x, airport_y, airport_rad);
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
	return good_tile;
}

/**
 * Return the cost to build an airport at the given node. Once the cost for one type
 * of airport is calculated it is cached for little less then a year after which it
 * is reevaluated.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo the connection should transport.
 * @param acceptingSide If true it means that the node will be evaluated as the accepting side.
 * @param useCache If true the result will be retrieved from cache, no check is made to see
 * if the airport can actually be build!
 * @return The total cost of building the airport.
 */
function BuildAirfieldAction::GetAirportCost(node, cargoID, acceptingSide, useCache) {

	local accounter = AIAccounting();
	local airportType = (AIAirport.AirportAvailable(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);

	if (useCache && BuildAirfieldAction.airportCosts.rawin("" + airportType)) {
		
		local airportCostTuple = BuildAirfieldAction.airportCosts.rawget("" + airportType);
		if (Date.GetDaysBetween(AIDate.GetCurrentDate(), airportCostTuple[0]) < 300)
			return airportCostTuple[1];
	}

	if (BuildAirfieldAction.FindSuitableAirportSpot(airportType, node, cargoID, acceptingSide, true) < 0)
		return -1;

	if (useCache)
		BuildAirfieldAction.airportCosts["" + airportType] <- [AIDate.GetCurrentDate(), accounter.GetCosts()];
	return accounter.GetCosts();
}
