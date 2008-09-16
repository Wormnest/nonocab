class CityBusAdvisor extends Advisor {}

/**
 * Get citybus reports.
 *
 * for each interesting city:
 * - build two stations
 * - build an depot
 * - build n busses (n E {1, })
 * - add route to busses 
 *
 */
function CityBusAdvisor::getReports()
{
	local MAXIMUM_REPORTS = 7;
	// AICargo.CC_PASSENGERS = 0 but should be AICargo.CC_COVERED
	local AICargo_CC_PASSENGERS = AICargo.CC_COVERED;
	// TODO: make not static.
	local CityBusCapacity = 31;//AIEngine.GetCapacity(innerWorld.cargoTransportEngineIds[cargoTransportEngineIds.len() -1]);
	Log.logDebug("	CityBusCapacity: " + CityBusCapacity);
	
	local reports = [];
	
	foreach(town_id, value in innerWorld.town_list)
	{
		if(AITown.GetMaxProduction(town_id, AICargo_CC_PASSENGERS) > CityBusCapacity)
		{
			Log.logDebug(AITown.GetName(town_id) + " (" + AITown.GetPopulation(town_id) + "), MaxPass: " + AITown.GetMaxProduction(town_id,AICargo_CC_PASSENGERS));

	 		local stationE = FindStationTile(town_id, 0);
	 		local stationW = FindStationTile(town_id, 2);
	 		local options = 0;
			
			if(AIMap.IsValidTile(stationE) && AIMap.IsValidTile(stationW))
			{
				Log.logDebug("E-W possible");
				options++;
			} 
			
			local stationN = FindStationTile(town_id, 1);
			local stationS = FindStationTile(town_id, 3);
			
			if(AIMap.IsValidTile(stationN) && AIMap.IsValidTile(stationS))
			{
				Log.logDebug("N-S possible");
				options++;
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
		}
		if(reports.len() > MAXIMUM_REPORTS)
		{
			break;
		}
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
function CityBusAdvisor::FindDepot()
{
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
	
	//if()
	//{
	//}
	return true;
}