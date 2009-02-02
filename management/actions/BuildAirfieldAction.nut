/**
 * Action class for the creation of airfields.
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
	local test = AIExecMode();
	local airportX = AIAirport.GetAirportWidth(airportType);
    local airportY = AIAirport.GetAirportHeight(airportType);	
	if (!AIAirport.BuildAirport(fromTile, airportType, true) && 
	!(Terraform.Terraform(fromTile, airportX, airportY) && AIAirport.BuildAirport(fromTile, airportType, true))) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + fromTile + ".");
	    AILog.Error(AIError.GetLastErrorString());
		connection.forceReplan = true;
	    return false;
	}
	if (!AIAirport.BuildAirport(toTile, airportType, true) && 
	!(Terraform.Terraform(toTile, airportX, airportY) && AIAirport.BuildAirport(toTile, airportType, true))) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + toTile + ".");
	    AILog.Error(AIError.GetLastErrorString());
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

	CallActionHandlers();
	return true;
}

/**
 * Find a good location to build an airfield and return it.
 * @param airportType The type of airport which needs to be build.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo that needs to be transported.
 * @param acceptingSide If true this side is considered as begin the accepting side of the connection.
 * @param getFirst If true ignores the exclude list and gets the first suitable spot to build an airfield
 * ignoring terraforming (it's only used to determine the cost of building an airport).
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
    if (list.Count() == 0) return -1;
    list.Sort(AIAbstractList.SORT_BY_VALUE, false);
    
	local good_tile = -1;
    /* Walk all the tiles and see if we can build the airport at all */
    {
    	local test = AITestMode();
		//local bestAcceptance = 0;

        for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
            if (!AIAirport.BuildAirport(tile, airportType, true)) continue;
			good_tile = tile;
			break;
    	}
    }
    
    // If we cannot find a suitable location, pick the best one and
    // resort to terraforming. However since the getfirst is only used
    // to get
	if (good_tile == -1) {
		if (getFirst)
			return -1;
		local test = AITestMode();
		for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
			if (Terraform.Terraform(tile, airportX, airportY)) {
				good_tile = tile;
				break;
			}
		}
	}
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
