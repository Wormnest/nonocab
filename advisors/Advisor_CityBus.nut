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
	// First is bus.
	local engine_id = innerWorld.cargoTransportEngineIds[0];
	Log.logDebug("Bus: "+AIEngine.GetName(engine_id));
	local CityBusCapacity = AIEngine.GetCapacity(engine_id);
	Log.logDebug("CityBus Capacity: " + CityBusCapacity);
	
	local reports = [];
	
	foreach(town_id, value in innerWorld.town_list)
	{
		// At least two busses should ride.
		if(AITown.GetMaxProduction(town_id, AICargo_CC_PASSENGERS) >= CityBusCapacity * 2)
		{
			Log.logDebug(AITown.GetName(town_id) + " (" + AITown.GetPopulation(town_id) + "), MaxPass: " + AITown.GetMaxProduction(town_id,AICargo_CC_PASSENGERS));

			local options = 0;
	 		local stationE = FindStationTile(town_id, 0);
	 		local stationW = FindStationTile(town_id, 2);
	 		local reportEW = null;
	 		local reportNS = null;
	 		
	 		// Maximum 4 busses.
	 		local busCount = AITown.GetMaxProduction(town_id, AICargo_CC_PASSENGERS) / CityBusCapacity;
	 		if( busCount > MAXIMUM_BUS_COUNT) {busCount = MAXIMUM_BUS_COUNT; }
			
			if(AIMap.IsValidTile(stationE) && AIMap.IsValidTile(stationW))
			{
				if(GetPathInfo(stationE, stationW) == null)
				{
					Log.logDebug("E-W inpossible");
				}
				else
				{
					reportEW = Report("Build E-W Busline.", 0, 500, []);
					Log.logDebug("E-W possible");
					options++;
				}
			} 
			
			local stationN = FindStationTile(town_id, 1);
			local stationS = FindStationTile(town_id, 3);
			
			if(AIMap.IsValidTile(stationN) && AIMap.IsValidTile(stationS))
			{
				if(GetPathInfo(stationN, stationS) == null)
				{
					Log.logDebug("N-S inpossible");
				}
				else
				{
					reportEW = Report("Build N-S Busline.", 0, 500, []);
					Log.logDebug("N-S possible");
					options++;
				}
			}
			if(options == 2)
			{
				if(AIMap.DistanceSquare(stationN, stationS) > AIMap.DistanceSquare(stationE, stationW))
				{
					Log.logDebug("N-S is preferable");
					//Log.buildDebugSign(stationN, "station N");
					//Log.buildDebugSign(stationS, "station S");
					reportEW = null;
				}
				else
				{
					Log.logDebug("E-W is preferable");
					//Log.buildDebugSign(stationE, "station E");
					//Log.buildDebugSign(stationW, "station W");
					reportNS = null;
				}
			}
			// Add reports if not null.
			if(reportNS != null){ reports.push(reportNS); }
			if(reportEW != null){ reports.push(reportEW); }
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
function CityBusAdvisor::GetPathInfo(/* tile */ station0, /* tile */ station1)
{
	local rpf = RoadPathFinding();
	local startlist = AIList();
	startlist.AddItem(station0, station0);
	local endlist = AIList();
	endlist.AddItem(station1, station1);
	return rpf.FindFastestRoad(startlist, endlist, true, true);
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