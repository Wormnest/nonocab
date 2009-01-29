/**
 * Action class for the creation of airfields.
 */
class BuildAirfieldAction extends Action {
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	static airportCosts = {};		// Table which holds the costs per airport type and the date when they were calculated.
						// Tuple: [calculation_date, cost].
	vehicleAdvisor = null;			// The advisor for our planes.
	
	constructor(connection, world, vehicleAdv) {
		this.connection = connection;
		this.world = world;
		vehicleAdvisor = vehicleAdv;
		Action.constructor();
	}
}


function BuildAirfieldAction::Execute() {

	local airportType = (AIAirport.AirportAvailable(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);

	local fromTile = this.FindSuitableAirportSpot(airportType, connection.travelFromNode, connection.cargoID, false, false);
	if (fromTile < 0) {
		Log.logWarning("No spot found for the first airfield!");
		connection.forceReplan = true;
		return false;
	}
	local toTile = this.FindSuitableAirportSpot(airportType, connection.travelToNode, connection.cargoID, true, false);
	if (toTile < 0) {
		Log.logWarning("No spot found for the second airfield!");
		connection.forceReplan = true;
		return false;
	}
	
	/* Build the airports for real */
	if (!AIAirport.BuildAirport(fromTile, airportType, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + fromTile + ".");
		connection.forceReplan = true;
	        return false;
	}
	if (!AIAirport.BuildAirport(toTile, airportType, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + toTile + ".");
		connection.forceReplan = true;
	        AIAirport.RemoveAirport(fromTile);
	        return false;
	}
	
	local start = AnnotatedTile();
	start.tile = fromTile;
	local end = AnnotatedTile();
	end.tile = toTile;
	connection.pathInfo.depot = AIAirport.GetHangarOfAirport(fromTile);
	connection.pathInfo.depotOtherEnd = AIAirport.GetHangarOfAirport(toTile);
	connection.pathInfo.roadList = [end, start];
	
	connection.UpdateAfterBuild(AIVehicle.VT_AIR, fromTile, toTile, AIAirport.GetAirportCoverageRadius(airportType));
	vehicleAdvisor.connections.push(connection);
	
	vehicleAdvisor.connections.push(connection);
	
	/*
	connection.pathInfo.build = true;
	connection.pathInfo.nrRoadStations++;
	connection.pathInfo.buildDate = AIDate.GetCurrentDate();
	connection.lastChecked = AIDate.GetCurrentDate();
	connection.vehicleTypes = AIVehicle.VT_AIR;
	connection.travelFromNodeStationID = AIStation.GetStationID(fromTile);
	connection.travelToNodeStationID = AIStation.GetStationID(toTile);
	connection.forceReplan = false;

	vehicleAdvisor.connections.push(connection);

	// In the case of a bilateral connection we want to make sure that
	// we don't hinder ourselves; Place the stations not to near each
	// other.
	if (connection.bilateralConnection && connection.connectionType == Connection.TOWN_TO_TOWN) {
        	local airportRadius = AIAirport.GetAirportCoverageRadius(airportType);
		connection.travelFromNode.AddExcludeTiles(connection.cargoID, fromTile, airportRadius);
		connection.travelToNode.AddExcludeTiles(connection.cargoID, toTile, airportRadius);
	}*/

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
        local airportX = AIAirport.GetAirportWidth(airportType);
        local airportY = AIAirport.GetAirportHeight(airportType);
        local airportRadius = AIAirport.GetAirportCoverageRadius(airportType);
	local tile = node.GetLocation();
	local excludeList;
	if (getFirst && node.nodeType == ConnectionNode.TOWN_NODE) {
		excludeList = clone node.excludeList;
		node.excludeList = {};
	}

	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID, airportRadius, airportX, airportY) : node.GetAllProducingTiles(cargoID, airportRadius, airportX, airportY));

	if (getFirst) {
		if (node.nodeType == ConnectionNode.TOWN_NODE)
			node.excludeList = excludeList;
	} else {
		list.Valuate(AITile.GetCargoAcceptance, cargoID, airportX, airportY, airportRadius);
		list.KeepAboveValue(30);
	}
        
        list.Valuate(AITile.IsBuildableRectangle, airportX, airportY);
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

			local currentAcceptance = AITile.GetCargoAcceptance(tile, cargoID, airportX, airportY, airportRadius);
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
