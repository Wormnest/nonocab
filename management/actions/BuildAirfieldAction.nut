/**
 * Action class for the creation of roads.
 */
class BuildAirfieldAction extends Action
{
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	
	/**
	 * @param pathList A PathInfo object, the road to be build.
	 * @buildDepot Should a depot be build?
	 * @param buildRoadStaions Should road stations be build?
	 */
	constructor(connection, world) {
		this.connection = connection;
		this.world = world;
		Action.constructor();
	}
}


function BuildAirfieldAction::Execute()
{

	local airport_type = (AIAirport.AirportAvailable(AIAirport.AT_SMALL) ? AIAirport.AT_SMALL : AIAirport.AT_LARGE);

	local tile_1 = this.FindSuitableAirportSpot(airport_type, connection.travelFromNode.GetLocation());
	if (tile_1 < 0) return -1;
	local tile_2 = this.FindSuitableAirportSpot(airport_type, connection.travelToNode.GetLocation());
	if (tile_2 < 0) {
	        this.towns_used.RemoveValue(tile_1);
	        return -2;
	}
	
	// Check if we can pay it.
	{
		local test = AITestMode();
		local account = AIAccounting();
		if (!AIAirport.BuildAirport(tile_1, airport_type, true) || !AIAirport.BuildAirport(tile_2, airport_type, true))
			return;
			
		if (Finance.GetMaxMoneyToSpend() < account.GetCosts())
			return;
	}
	
	{
	local test = AIExecMode();
	/* Build the airports for real */
	if (!AIAirport.BuildAirport(tile_1, airport_type, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + tile_1 + ".");
	        return -3;
	}
	if (!AIAirport.BuildAirport(tile_2, airport_type, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + tile_2 + ".");
	        AIAirport.RemoveAirport(tile_1);
	        return -4;
	}
	}
	
	local start = AnnotatedTile();
	start.tile = tile_1;
	local end = AnnotatedTile();
	end.tile = tile_2;
	connection.pathInfo.depot = AIAirport.GetHangarOfAirport(tile_1);
	connection.pathInfo.roadList = [end, start];
	connection.pathInfo.build = true;
	connection.lastChecked = AIDate.GetCurrentDate();
	connection.vehicleTypes = AIVehicle.VEHICLE_AIR;
	connection.travelFromNodeStationID = AIStation.GetStationID(tile_1);
	connection.travelToNodeStationID = AIStation.GetStationID(tile_2);
	
	AILog.Info("Done building a route");
	CallActionHandlers();
	return true;
}

function BuildAirfieldAction::FindSuitableAirportSpot(airport_type, tile)
{
        local airport_x, airport_y, airport_rad;

        airport_x = AIAirport.GetAirportWidth(airport_type);
        airport_y = AIAirport.GetAirportHeight(airport_type);
        airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);
        
        /* Create a 30x30 grid around the core of the town and see if we can find a spot for a small airport */
        local list = AITileList();
        /* XXX -- We assume we are more than 15 tiles away from the border! */
        list.AddRectangle(tile - AIMap.GetTileIndex(15, 15), tile + AIMap.GetTileIndex(15, 15));
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
                        if (!AIAirport.BuildAirport(tile, airport_type, true)) continue;
                        good_tile = tile;
                        break;
                }
        }

        AILog.Info("Found a good spot for an airport in town " + connection.travelFromNode.GetName() + " at tile " + tile);
        return tile;
}
