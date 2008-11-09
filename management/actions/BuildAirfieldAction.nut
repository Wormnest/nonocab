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

	local airportType = (AIAirport.AirportAvailable(AIAirport.AT_SMALL) ? AIAirport.AT_SMALL : AIAirport.AT_LARGE);

	local tile_1 = this.FindSuitableAirportSpot(airportType, connection.travelFromNode, connection.cargoID, false);
	if (tile_1 < 0) return false;
	local tile_2 = this.FindSuitableAirportSpot(airportType, connection.travelToNode, connection.cargoID, true);
	if (tile_2 < 0) return false;
	
	// Check if we can pay it.
	{
		local test = AITestMode();
		local account = AIAccounting();
		if (!AIAirport.BuildAirport(tile_1, airportType, true) || !AIAirport.BuildAirport(tile_2, airportType, true))
			return false;
			
		if (Finance.GetMaxMoneyToSpend() < account.GetCosts())
			return false;
	}
	
	{
	local test = AIExecMode();
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
	}
	
	local start = AnnotatedTile();
	start.tile = tile_1;
	local end = AnnotatedTile();
	end.tile = tile_2;
	connection.pathInfo.depot = AIAirport.GetHangarOfAirport(tile_1);
	connection.pathInfo.depotOtherEnd = AIAirport.GetHangarOfAirport(tile_2);
	connection.pathInfo.roadList = [end, start];
	connection.pathInfo.build = true;
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

	AILog.Info("Done building a route");
	CallActionHandlers();
	return true;
}

/**
 * Find a good location to build an airfield and return it.
 * @param airportType The type of airport which needs to be build.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo that needs to be transported.
 * @acceptingSide If true this side is considered as begin the accepting side of the connection.
 * @return The tile where the airport can be build.
 */
function BuildAirfieldAction::FindSuitableAirportSpot(airportType, node, cargoID, acceptingSide)
{
        local airport_x, airport_y, airport_rad;
	local tile = node.GetLocation();
	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID) : node.GetAllProducingTiles(cargoID));

        airport_x = AIAirport.GetAirportWidth(airportType);
        airport_y = AIAirport.GetAirportHeight(airportType);
        airport_rad = AIAirport.GetAirportCoverageRadius(airportType);
        
        list.Valuate(AITile.IsBuildableRectangle, airport_x, airport_y);
        list.KeepValue(1);
        
        /* Sort on acceptance, remove places that don't have acceptance */
        list.Valuate(AITile.GetCargoAcceptance, connection.cargoID, airport_x, airport_y, airport_rad);
        list.RemoveBelowValue(10);

        /* Couldn't find a suitable place for this town, skip to the next */
        if (list.Count() == 0) return;
        /* Walk all the tiles and see if we can build the airport at all */
        {
                local test = AITestMode();
                local good_tile = 0;

                for (tile = list.Begin(); list.HasNext(); tile = list.Next()) {
                        if (!AIAirport.BuildAirport(tile, airportType, true)) continue;
                        good_tile = tile;
                        break;
                }

		if (good_tile == 0)
			return -1;
        }

        return tile;
}

/**
 * Return the cost to build an airport at the given node. Once the cost for one type
 * of airport is calculated it is cached for little less then a year after which it
 * is reevaluated.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo the connection should transport.
 * @param acceptingSide If true it means that the node will be evaluated as the accepting side.
 * @return The total cost of building the airport.
 */
function BuildAirfieldAction::GetAirportCost(node, cargoID, acceptingSide) {

	local accounter = AIAccounting();
	local airportType = (AIAirport.AirportAvailable(AIAirport.AT_SMALL) ? AIAirport.AT_SMALL : AIAirport.AT_LARGE);

	if (BuildAirfieldAction.airportCosts.rawin("" + airportType)) {
		
		local airportCostTuple = BuildAirfieldAction.airportCosts.rawget("" + airportType);
		if (Date.GetDaysBetween(AIDate.GetCurrentDate(), airportCostTuple[0]) < 300)
			return airportCostTuple[1];
	}

	if (BuildAirfieldAction.FindSuitableAirportSpot(airportType, node, cargoID, acceptingSide) < 0)
		return -1;

	BuildAirfieldAction.airportCosts["" + airportType] <- [AIDate.GetCurrentDate(), accounter.GetCosts()];
	return accounter.GetCosts();
}
