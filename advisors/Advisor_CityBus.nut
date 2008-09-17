class CityBusAdvisor extends Advisor {}

/**
 * Get citybus reports.
 *
 * for each interesting city:
 * - build two stations
 * - build an depot
 * - build n busses (2,3,4)
 * - add route to busses 
 *
 */
function CityBusAdvisor::getReports()
{
	local MAXIMUM_BUS_COUNT = 4;
	// AICargo.CC_PASSENGERS = 1 but should be AICargo.CC_COVERED
	local AICargo_CC_PASSENGERS = AICargo.CC_COVERED;
	local CARGO_ID_PASS = 0;
	
	// First is bus.
	local engine_id = innerWorld.cargoTransportEngineIds[0];
	local CityBusCapacity = AIEngine.GetCapacity(engine_id);
	
	local reports = [];
	local options = 0;
	
	// Stations
	local stationE = null;
	local stationW = null;
	local stationN = null;
	local stationS = null;
	
	// Reports
	local reportEW = null;
	local reportNS = null;
	
	// report helpers
	local path_info = null;
	local connection = null;
	local town_node = null;
	local build_action = null;
	local drive_action = null;
	
	foreach(town_node in innerWorld.townConnectionNodes)
	{
		connection = town_node.GetConnection(town_node, CARGO_ID_PASS);
		if(connection == null)
		{
			if(town_node.GetProduction(AICargo_CC_PASSENGERS) >= CityBusCapacity * 2)
			{
				// Search for spots.
				stationE = FindStationTile(town_node.id, 0);
		 		stationW = FindStationTile(town_node.id, 2);
				//stationN = FindStationTile(town_node.id, 1);
				//stationS = FindStationTile(town_node.id, 3);
				
				// Research East-West.
			if(AIMap.IsValidTile(stationE) && AIMap.IsValidTile(stationW))
			{
				path_info = GetPathInfo(TileAsAIList(stationE),TileAsAIList(stationW));
				
				if(path_info != null)
				{
					connection = Connection(CARGO_ID_PASS, town_node, town_node, path_info, true);
					town_node.AddConnection(town_node, connection);
					build_action = BuildRoadAction(connection, true, true);
					drive_action = ManageVehiclesAction();
					drive_action.BuyVehicles(engine_id, 4, connection);
					reportEW = Report("CityBus", -10, 10000, [build_action, drive_action]);
					reports.push(reportEW);
				}
			}
		}
		// Update connection.
		else
		{
			
		}
	}
	/*
	foreach(town_id, value in innerWorld.town_list)
	{
		Log.logDebug(AITown.GetName(town_id) + " (" + AITown.GetPopulation(town_id) + "), MaxPass: " + AITown.GetMaxProduction(town_id,AICargo_CC_PASSENGERS));
		
		// At least two busses should ride.
		if(AITown.GetMaxProduction(town_id, AICargo_CC_PASSENGERS) >= CityBusCapacity * 2)
		{
			stationE = FindStationTile(town_id, 0);
	 		stationW = FindStationTile(town_id, 2);
			stationN = FindStationTile(town_id, 1);
			stationS = FindStationTile(town_id, 3);
			
			// Research East-West.
			if(AIMap.IsValidTile(stationE) && AIMap.IsValidTile(stationW))
			{
				path_info = GetPathInfo(TileAsAIList(stationE),TileAsAIList(stationW));
				
				if(path_info != null)
				{
					town_node = TownConnectionNode(town_id);
					connection = Connection(0, town_node, town_node, path_info, true);
					Log.logDebug(connection.connectionType);
					local build_action = BuildRoadAction(connection, true, true);
					local drive_action = ManageVehiclesAction();
					drive_action.BuyVehicles(engine_id, 4, connection);
					reports.push(Report("CityBus", -10, 10000, [build_action, drive_action]));
				}
			}
			if(options == 2)
			{
				if(AIMap.DistanceSquare(stationN, stationS) > AIMap.DistanceSquare(stationE, stationW))
				{
					Log.logDebug("N-S is preferable");
				}
				else
				{
					Log.logDebug("E-W is preferable");
				}
			}
		}*/
	}
	return reports;
}
/**
 * Take the city tile and go to the given direction.
 * While you've got city influence and you're not able to build go further.
 *      (1)
 *       N
 * (2) W + E (0)
 *       S
 *      (3)
 */
function CityBusAdvisor::FindStationTile(/*in32*/town_id, /*int32*/ direction)
{
	local towntile = AITown.GetLocation(town_id);
	local tile = towntile;
	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);

	while(AITile.IsWithinTownInfluence(tile, town_id))
	{
		switch(direction)
		{
			case 0: x = x - 1; break;
			case 1: y = y - 1; break;
			case 2: x = x + 1; break;
			case 3: y = y + 1; break;
			default: Log.logError("Invalid direction: " + direction); return null;
		}
		tile = AIMap.GetTileIndex(x, y);
		
		if(IsValidStationTile(tile))
		{
			return tile; 
		} 
	}
	// INVALID_TILE
	return -1;
}
function CityBusAdvisor::GetPathInfo(/* AIList */ station0, /* AIList */ station1)
{
	local rpf = RoadPathFinding();
	return rpf.FindFastestRoad(station0, station1, true, true);
}
/**
 *
 */
function CityBusAdvisor::IsValidStationTile(tile)
{
	// Should be buildable
	if(!AITile.IsBuildable(tile) ||
		// No Water 
		AITile.IsWaterTile(tile) ||
		// No road 
		AIRoad.IsRoadTile(tile) ||
		// No station
		AIRoad.IsRoadStationTile(tile) ||
		// No road
		AIRoad.IsRoadDepotTile(tile) ||
		// No onwer or NoCAB is owner
		(AITile.GetOwner(tile) != AICompany.INVALID_COMPANY && AITile.GetOwner(tile) != AICompany.MY_COMPANY)
		){ return false; }
	return true;
}
function CityBusAdvisor::TileAsAIList(/* tile */ tile)
{
	local list = AIList();
	list.AddItem(tile, tile);
	return list;
}