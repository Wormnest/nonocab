class CityBusAdvisor extends Advisor
{
	static MINIMUM_CITY_POPULATION = 2048;
	static MINIMUM_DISTANCE = 10;
	static MINIMUM_BUS_AGE = 2;
	static MINIMUM_BUS_PROFIT = 128.0;
	static MINIMUM_BUS_COUNT = 2;
	static MAXIMUM_BUS_COUNT = 4;
	static RENDAMENT_OF_CITY = 0.17;
	// AICargo.CC_PASSENGERS = 1 but should be AICargo.CC_COVERED
	static AICargo_CC_PASSENGERS = AICargo.CC_COVERED;
	static CARGO_ID_PASS = 0;
	
	engineId = null;
	cityBusCapacity = null;
}

/**
 * Get citybus reports.
 *
 * for each interesting city:
 * - build two stations
 * - build an depot
 * - build n busses (2,3,4)
 * - add route to busses 
 *
 * Remarks: builds a East-West connection.
 */
function CityBusAdvisor::getReports()
{
	Log.logInfo("CityBusAdvisor::getReports()");
	// Update busses.
	engineId = innerWorld.cargoTransportEngineIds[0];
	cityBusCapacity = AIEngine.GetCapacity(engineId);
	local reports = [];
	local report = null;
	
	// Stations
	local stationE = null;
	local stationW = null;
	
	// report helpers
	local connection = null;
	local town_node = null;
	local city_capicity = 0;
	local path_info = null;
	
	foreach(town_node in innerWorld.townConnectionNodes)
	{
		//Log.logDebug(town_node.ToString());
		connection = town_node.GetConnection(town_node, CARGO_ID_PASS);
		if(connection == null)
		{
			// Only try something if the city is big enough.
			if(town_node.GetPopulation() >= MINIMUM_CITY_POPULATION)
			{
				// Validate if the city 'produces' enough.
				city_capicity = town_node.GetProduction(AICargo_CC_PASSENGERS) * RENDAMENT_OF_CITY;
				if(city_capicity >= cityBusCapacity * MINIMUM_BUS_COUNT)
				{
					// Search for spots.
					stationE = FindStationTile(town_node, 0);
			 		stationW = FindStationTile(town_node, 2);
				
					// If two proper spots are found and the are not to close together.
					if(AIMap.IsValidTile(stationE) && AIMap.IsValidTile(stationW) &&
						AIMap.DistanceManhattan(stationE, stationW) >= MINIMUM_DISTANCE)
					{
						path_info = GetPathInfo(TileAsAITileList(stationE),TileAsAITileList(stationW));
						
						// If a path_info can be made.
						if(path_info != null)
						{
							// create a connection and save it.
							connection = Connection(CARGO_ID_PASS, town_node, town_node, path_info, true);
							town_node.AddConnection(town_node, connection);
							report = GetReportForNewConnection(connection, city_capicity);
							if(report.Utility() > 0)
							{
								reports.push(report);
							}
						}
					}
				}
			}
		}
		// Update connection.
		else
		{
			// If no verhicles connected to connection.
			if(connection.vehiclesOperating.len() == 0 || connection.vehiclesOperating[0].vehicleIDs.len() == 0)
			{
				// update path.
				local rpf = RoadPathFinding();
				path_info = GetPathInfo(
					TileAsAITileList(connection.pathInfo.roadList[0].tile),
					TileAsAITileList(connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile));
				// If new pathInfo is found try to add it.
				if(path_info != null)
				{
					connection.pathInfo = path_info;
					city_capicity = town_node.GetProduction(AICargo_CC_PASSENGERS) * RENDAMENT_OF_CITY;
					report = GetReportForNewConnection(connection, city_capicity);
					if(report.Utility() > 0)
					{
						reports.push(report);
					}
				}
			}
			// should we build or sell busses?
			else
			{
				local manage_action = ManageVehiclesAction();
				local costs = 0;
				
				foreach(group in connection.vehiclesOperating){
					foreach(bus_id in group.vehicleIDs)
					{
						// If old enough and not profitable sell it.
						//Log.logDebug("Age: " + AIVehicle.GetAge(bus_id) / World.DAYS_PER_YEAR + ", profit: " + AIVehicle.GetProfitLastYear(bus_id));
						if(AIVehicle.GetAge(bus_id) / World.DAYS_PER_YEAR >= MINIMUM_BUS_AGE &&
							AIVehicle.GetProfitLastYear(bus_id) < MINIMUM_BUS_PROFIT)
						{
						 	manage_action.SellVehicle(bus_id);
						 	costs -= AIVehicle.GetCurrentValue(bus_id);
						}
					}
				}
				// TODO: All verhicles are inprofitable, probely somehting wrong.
				if(manage_action.vehiclesToSell.len() == connection.vehiclesOperating.len())
				{
					Log.logError("All verhicles are inprofitable, probely somehting wrong.");
				}
				// we sell some.
				else if(manage_action.vehiclesToSell.len() > 0)
				{
					local desc = "Sell " + manage_action.vehiclesToSell.len() + " EW citybus(ses) in " + town_node.GetName() + ".";
					local report = Report(desc, costs, -MINIMUM_BUS_PROFIT, [manage_action]);
				}
				// we don't sell and are on our max.
				else if(connection.vehiclesOperating.len() == MAXIMUM_BUS_COUNT)
				{
						Log.logDebug("EW citybus(ses) in " + town_node.GetName() + " or fully operational.");
				}
				else
				{
					//TODO: do we want to buy new verhicles?
				}
			}
		}
	}
	return reports;
}
function CityBusAdvisor::GetReportForNewConnection(/*Connection*/ connection, /*float*/ city_capicity)
{
	// Who many busses should we build?
	local busses = city_capicity / cityBusCapacity;
	if(busses > MAXIMUM_BUS_COUNT){ busses = MAXIMUM_BUS_COUNT; }
	
	local build_action = BuildRoadAction(connection, true, true);
	local drive_action = ManageVehiclesAction();
	drive_action.BuyVehicles(engineId, busses, connection);
	
	local distance = AIMap.DistanceManhattan(
		connection.pathInfo.roadList[0].tile,
		connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile);
	local rpf = RoadPathFinding();
	local cost = busses * AIEngine.GetPrice(engineId) + rpf.GetCostForRoad(connection.pathInfo.roadList);
	local time = rpf.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineId), true) + Advisor.LOAD_UNLOAD_PENALTY_IN_DAYS;
	local income = cityBusCapacity * AICargo.GetCargoIncome(CARGO_ID_PASS, distance, time) * (World.DAYS_PER_MONTH / time);
	local runnincosts = (AIEngine.GetRunningCost(engineId) / World.MONTHS_PER_YEAR)
	//Log.logDebug("income: " + income + ", running: " + runnincosts); 
	local profit = busses * (income - runnincosts);
	local desc = "Build an EW citybus in " + connection.travelFromNode.GetName() + ".";
	local report = Report(desc, cost, profit, [build_action, drive_action]);
	//Log.logDebug("Cost: " + cost + ", time: " + time + ", dist: " + distance + ", income: " + income + ", util: " + report.Utility());
	return report;
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
function CityBusAdvisor::FindStationTile(/*TownConnectionNode*/ town_node, /*int32*/ direction)
{
	local tile = town_node.GetLocation();
	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);
	local min = MINIMUM_DISTANCE / 2 - 2;

	while(AITile.IsWithinTownInfluence(tile, town_node.id)) {
		switch(direction) {
			case 0: x = x - 1; break;
			case 1: y = y - 1; break;
			case 2: x = x + 1; break;
			case 3: y = y + 1; break;
			default: Log.logError("Invalid direction: " + direction); return null;
		}
		tile = AIMap.GetTileIndex(x, y);
	
		// Not to close to the center.
		if(IsValidStationTile(tile) && min <= 0)
		{
			//Log.buildDebugSign(tile, "Station");
			return tile; 
		}
		min--;
		//Log.buildDebugSign(tile, "?");
	}
	Log.logWarning("No station found for " + town_node.GetName() + ", direction: " + direction);
	// INVALID_TILE
	return -1;
}
function CityBusAdvisor::GetPathInfo(/* AITileList */ station0, /* AITileList */ station1)
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
		AITile.IsWaterTile(tile)
		// ||
		// No road 
		//AIRoad.IsRoadTile(tile) ||
		// No station
		//AIRoad.IsRoadStationTile(tile) ||
		// No road
		//AIRoad.IsRoadDepotTile(tile)
		){ return false; }
	return true;
}
function CityBusAdvisor::TileAsAITileList(/* tile */ tile)
{
	local list = AITileList();
	list.AddTile(tile);
	//local x = AIMap.GetTileX(tile);
	//local y = AIMap.GetTileX(tile);
	//list.AddRectangle(AIMap.GetTileIndex(x-1, y-1),AIMap.GetTileIndex(x+1, y+1));
	return list;
}