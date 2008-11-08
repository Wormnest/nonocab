/**
 * Action class for the creation of roads.
 */
class BuildAirfieldAction extends Action
{
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.
	
	constructor(connection, world) {
		this.connection = connection;
		this.world = world;
		Action.constructor();
	}
}


function BuildAirfieldAction::Execute()
{

	local airport_type = (AIAirport.AirportAvailable(AIAirport.AT_SMALL) ? AIAirport.AT_SMALL : AIAirport.AT_LARGE);

	local tile_1 = this.FindSuitableAirportSpot(airport_type, connection.travelFromNode, connection.cargoID, false);
	if (tile_1 < 0) return false;
	local tile_2 = this.FindSuitableAirportSpot(airport_type, connection.travelToNode, connection.cargoID, true);
	if (tile_2 < 0) return false;
	
	// Check if we can pay it.
	{
		local test = AITestMode();
		local account = AIAccounting();
		if (!AIAirport.BuildAirport(tile_1, airport_type, true) || !AIAirport.BuildAirport(tile_2, airport_type, true))
			return false;
			
		if (Finance.GetMaxMoneyToSpend() < account.GetCosts())
			return false;
	}
	
	{
	local test = AIExecMode();
	/* Build the airports for real */
	if (!AIAirport.BuildAirport(tile_1, airport_type, true)) {
	        AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + tile_1 + ".");
	        return false;
	}
	if (!AIAirport.BuildAirport(tile_2, airport_type, true)) {
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

        	local airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);
		connection.travelFromNode.AddExcludeTiles(connection.cargoID, tile_1, airport_rad);
		connection.travelToNode.AddExcludeTiles(connection.cargoID, tile_2, airport_rad);
	}

	AILog.Info("Done building a route");
	CallActionHandlers();
	return true;
}

function BuildAirfieldAction::FindSuitableAirportSpot(airport_type, node, cargoID, acceptingSide)
{
        local airport_x, airport_y, airport_rad;
	local tile = node.GetLocation();
	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID) : node.GetAllProducingTiles(cargoID));

        airport_x = AIAirport.GetAirportWidth(airport_type);
        airport_y = AIAirport.GetAirportHeight(airport_type);
        airport_rad = AIAirport.GetAirportCoverageRadius(airport_type);
        
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
