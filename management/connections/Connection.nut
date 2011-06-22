/**
 * A connection is a link between two nodes (industries or towns) and holds all information that is
 * relevant to maintain / build such a connection. Connection are build up from ConnectionNodes. 
 * Because multiple advisors can reason over connection and create reports for them, we store the
 * best report produced by an advisor in the bestReport variable which can only be overwritten if
 * it becomes invalidated (i.e. it can't be build) or an advisor comes with a better report.
 */
class Connection {

	// Type of connection.
	static INDUSTRY_TO_INDUSTRY = 1;
	static INDUSTRY_TO_TOWN = 2;
	static TOWN_TO_TOWN = 3;
	static TOWN_TO_SELF = 4;
	
	// Vehicle types in this connection.
	vehicleTypes = null;
	
	lastChecked = null;             // The latest date this connection was inspected.
	connectionType = null;          // The type of connection (one of above).
	cargoID = null;	                // The type of cargo carried from one node to another.
	travelFromNode = null;          // The node the cargo is carried from.
	travelToNode = null;            // The node the cargo is carried to.
	vehicleGroupID = null;          // The AIGroup of all vehicles serving this connection.
	pathInfo = null;                // PathInfo class which contains all information about the path.
	bilateralConnection = null;     // If this is true, cargo is carried in both directions.
	connectionManager = null;       // Updates are send to all listeners when connection is realised, demolished or updated.

	forceReplan = null;		// Force this connection to be replanned.
	
	bestTransportEngine = null;
	bestHoldingEngine = null;
	
	constructor(cargo_id, travel_from_node, travel_to_node, path_info, connection_manager) {
		cargoID = cargo_id;
		travelFromNode = travel_from_node;
		travelToNode = travel_to_node;
		pathInfo = path_info;
		connectionManager = connection_manager;
		forceReplan = false;
		bilateralConnection = travel_from_node.GetProduction(cargo_id) > 0 && travel_to_node.GetProduction(cargo_id) > 0;
		
		if (travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
			if (travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
				connectionType = INDUSTRY_TO_INDUSTRY;
			} else {
				connectionType = INDUSTRY_TO_TOWN;
			}
		}
		else {
			if(travelFromNode == travelToNode) {
				connectionType = TOWN_TO_SELF;	
			}
			else{
				connectionType = TOWN_TO_TOWN;
			}
		}
		vehicleGroupID = -1;
	}
	
	function LoadData(data) {
		pathInfo = PathInfo(null, null, null, null);
		vehicleTypes = data["vehicleTypes"];
		pathInfo.LoadData(data["pathInfo"]);
		vehicleGroupID = data["vehicleGroupID"];
		
		UpdateAfterBuild(vehicleTypes, pathInfo.roadList[pathInfo.roadList.len() - 1].tile, pathInfo.roadList[0].tile, AIStation.GetCoverageRadius(AIStation.GetStationID(pathInfo.roadList[0].tile)));
	}
	
	function SaveData() {
		local saveData = {};
		saveData["cargoID"] <- cargoID;
		saveData["travelFromNode"] <- travelFromNode.GetUID(cargoID);
		saveData["travelToNode"] <- travelToNode.GetUID(cargoID);
		saveData["vehicleTypes"] <- vehicleTypes;
		saveData["pathInfo"] <- pathInfo.SaveData();
		saveData["vehicleGroupID"] <- vehicleGroupID;
		return saveData;
	}
	
	function NewEngineAvailable(engineID) {
		local bestEngines = GetBestTransportingEngine(vehicleTypes);
		if (bestEngines != null) {
			AIGroup.SetAutoReplace(vehicleGroupID, bestTransportEngine, bestEngines[0]);
			AIGroup.SetAutoReplace(vehicleGroupID, bestHoldingEngine, bestEngines[1]);
			
			AISign.BuildSign(travelFromNode.GetLocation(), "Replace " + AIEngine.GetName(bestTransportEngine) + " with " + AIEngine.GetName(bestEngines[0]));
			
			bestTransportEngine = bestEngines[0];
			bestHoldingEngine = bestEngines[1];
		}
	}
	
	/**
	 * Generate a report which details how many vehicles must be build of what time and how much the connection
	 * (if not already built) is going to cost. If the connection has already been built, it will take into account
	 * the amount of cargo already transported when generating a report detailing how many more vehicles should be built.
	 * @param world The world.
	 * @vehicleType The type of vehicle to use for this connection.
	 * @return A Report instance.
	 */
	function CompileReport(world, vehicleType) {
		
		local bestEngines = GetBestTransportingEngine(vehicleType);
		
		if (bestEngines == null) {
			//Log.logWarning("No suitable engines found!");
			return null;
		}
		
		local transportingEngineID = bestEngines[0];
		local holdingEngineID = bestEngines[1];

		// First we check how much we already transport.
		// Check if we already have vehicles who transport this cargo and deduce it from 
		// the number of vehicles we need to build.
		local cargoAlreadyTransported = 0;
		foreach (connection in travelFromNode.connections) {
			if (connection.cargoID == cargoID) {
				
				if (AIGroup.IsValidGroup(vehicleGroupID)) {
					local vehicles = AIVehicleList_Group(vehicleGroupID);
					foreach (vehicle, value in vehicles) {
						local engineID = AIVehicle.GetEngineType(vehicle);
						if (!AIEngine.IsBuildable(engineID))
							continue;
						local travelTime = pathInfo.GetTravelTime(engineID, true) +  pathInfo.GetTravelTime(engineID, false);
						cargoAlreadyTransported += (World.DAYS_PER_MONTH / travelTime) * AIVehicle.GetCapacity(vehicle, cargoID);
					}
				}
			}
		}	
		
		return Report(world, travelFromNode, travelToNode, cargoID, transportingEngineID, holdingEngineID, cargoAlreadyTransported);
	}
	
	function GetEstimatedTravelTime(transportEngineID, forward) {
		// If the road list is known we will simulate the engine and get a better estimate.
		if (pathInfo != null && pathInfo.roadList != null) {
			return pathInfo.GetTravelTime(transportEngineID, forward);
		} else {
			
			local maxSpeed = AIEngine.GetMaxSpeed(transportEngineID);
			
			// If this is not the case we estimate the distance the engine needs to travel.
			if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_ROAD) {
				local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
				return distance * Tile.straightRoadLength / maxSpeed;
			} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR) {
	
				// For air connections the distance travelled is different (shorter in general)
				// than road vehicles. A part of the tiles are traversed diagonal, we want to
				// capture this so we can make more precise predictions on the income per vehicle.
				local fromLoc = travelFromNode.GetLocation();
				local toLoc = travelToNode.GetLocation();
				local distanceX = AIMap.GetTileX(fromLoc) - AIMap.GetTileX(toLoc);
				local distanceY = AIMap.GetTileY(fromLoc) - AIMap.GetTileY(toLoc);
	
				if (distanceX < 0) distanceX = -distanceX;
				if (distanceY < 0) distanceY = -distanceY;
	
				local diagonalTiles;
				local straightTiles;
	
				if (distanceX < distanceY) {
					diagonalTiles = distanceX;
					straightTiles = distanceY - diagonalTiles;
				} else {
					diagonalTiles = distanceY;
					straightTiles = distanceX - diagonalTiles;
				}
	
				// Take the landing sequence in consideration.
				local realDistance = diagonalTiles * Tile.diagonalRoadLength + (straightTiles + 40) * Tile.straightRoadLength;
	
				return realDistance / maxSpeed;
			} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_WATER) {
				local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
				return distance * Tile.straightRoadLength / maxSpeed;
			} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
				local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
				return distance * Tile.straightRoadLength / maxSpeed;
			} else {
				Log.logError("Unknown vehicle type: " + AIEngine.GetVehicleType(transportEngineID));
				quit();
				isInvalid = true;
				world.InitCargoTransportEngineIds();
			}
		}
	}
	
	function GetBestTransportingEngine(vehicleType) {
		assert (vehicleType != AIVehicle.VT_INVALID);
		
		// If the connection is built and the vehicle type inquired is the same as the vehicle type in use by this connection.
		if (vehicleType == this.vehicleTypes && bestTransportEngine != null && bestHoldingEngine != null)
			return [bestTransportEngine, bestHoldingEngine];
		
		local bestTransportEngine = null;
		local bestHoldingEngine = null;
		local bestIncomePerMonth = 0;
		local engineList = AIEngineList(vehicleType);
		
		foreach (engineID, value in engineList) {
			local transportEngineID = engineID;
			
			if (AIEngine.IsWagon(transportEngineID) || !AIEngine.IsValidEngine(transportEngineID) || !AIEngine.IsBuildable(transportEngineID))
				continue;

//			Log.logWarning("Process the engine: " + AIEngine.GetName(transportEngineID));
			
			// If the engine is a train we need to check for the best wagon it can pull.
			local holdingEngineID = null;
			if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
				
				// TODO: Check if there is a restriction on the rail types we can use.
				local bestRailType = TrainConnectionAdvisor.GetBestRailType(engineID);
				
				if (!AIEngine.CanPullCargo(transportEngineID, cargoID))
					continue;
				
				local wagonEngineList = AIEngineList(vehicleType);
				foreach (wagonEngineID, value in wagonEngineList) {
					if (!AIEngine.IsWagon(wagonEngineID) || !AIEngine.IsValidEngine(wagonEngineID) || !AIEngine.IsBuildable(wagonEngineID))
						continue;
					
					if (AIEngine.GetCargoType(wagonEngineID) != cargoID && !AIEngine.CanRefitCargo(wagonEngineID, cargoID))
						continue;
					
					if (!AIEngine.CanRunOnRail(wagonEngineID, bestRailType))
						continue;
					
					// Select the wagon with the biggest capacity.
					if (holdingEngineID == null)
						holdingEngineID = wagonEngineID;
					else if (AIEngine.GetCapacity(wagonEngineID) > AIEngine.GetCapacity(holdingEngineID))
						holdingEngineID = wagonEngineID;
				}
			} else {
				holdingEngineID = engineID;
				
				if (AIEngine.GetCargoType(holdingEngineID) != cargoID && !AIEngine.CanRefitCargo(holdingEngineID, cargoID))
					continue;
			}
			
			if (holdingEngineID == null)
				continue;
			
			local travelTimeTo = GetEstimatedTravelTime(transportEngineID, true);
			local travelTimeFrom = GetEstimatedTravelTime(transportEngineID, false);
			
			if (travelTimeTo == null || travelTimeFrom == null)
				continue;
				
//			Log.logWarning("Travel times: " + travelTimeTo + ", " + travelTimeFrom);
			
			local travelTime = travelTimeTo + travelTimeFrom;
			
			// Calculate netto income per vehicle.
			local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH.tofloat() / travelTime) * AIEngine.GetCapacity(holdingEngineID);
			
			// In case of trains, we have 5 wagons.
			if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
				transportedCargoPerVehiclePerMonth *= 5;
			
			
			// If we refit from passengers to mail, we devide the capacity by 2, to any other cargo type by 4.
			if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR && AICargo.HasCargoClass(AIEngine.GetCargoType(holdingEngineID), AICargo.CC_PASSENGERS) && 
			    !AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) && !AICargo.HasCargoClass(cargoID, AICargo.CC_MAIL)) {
				if (AICargo.GetTownEffect(cargoID) == AICargo.TE_GOODS)
					transportedCargoPerVehiclePerMonth *= 0.6;
				else
					transportedCargoPerVehiclePerMonth *= 0.3;
			}
//			Log.logWarning("Cargo transported per vehicle: " + transportedCargoPerVehiclePerMonth);
			
			local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
			local nrVehicles = travelFromNode.GetProduction(cargoID).tofloat() / transportedCargoPerVehiclePerMonth;
			local brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoID, distance, travelTimeTo.tointeger()) * transportedCargoPerVehiclePerMonth;
	
			// In case of a bilateral connection we take a persimistic take on the amount of 
			// vehicles supported by this connection, but we do increase the income by adding
			// the expected income of the other connection to the total.
			if (bilateralConnection) {
				// Also calculate the route in the other direction.
				nrVehicles += (travelToNode.GetProduction(cargoID) / transportedCargoPerVehiclePerMonth).tointeger();
				brutoIncomePerMonthPerVehicle += AICargo.GetCargoIncome(cargoID, distance, travelTimeFrom.tointeger()) * transportedCargoPerVehiclePerMonth;
			}
	
			local brutoCostPerMonthPerVehicle = AIEngine.GetRunningCost(transportEngineID) / World.MONTHS_PER_YEAR;
			local initialCostPerVehicle = AIEngine.GetPrice(transportEngineID);
			local replacementTimeInMonths = AIEngine.GetMaxAge(transportEngineID) * 12;
			
			local initialCostPerVehiclePerMonth = initialCostPerVehicle / replacementTimeInMonths;
			
//			Log.logWarning("Income / costs (init costs): " + brutoIncomePerMonthPerVehicle + " / " + brutoCostPerMonthPerVehicle + "(" + initialCostPerVehiclePerMonth + "): " + nrVehicles);
			
			local nettoIncomePerMonth = (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle - initialCostPerVehiclePerMonth) * nrVehicles;
			if (nettoIncomePerMonth > bestIncomePerMonth) {
//				if (bestTransportEngine != null)
//					Log.logWarning("+ Replace + " + AIEngine.GetName(bestTransportEngine) + "(" + bestIncomePerMonth + ") with " + AIEngine.GetName(transportEngineID) + "(" + nettoIncomePerMonth + ") for the connection: " + ToString() + ".");
//				else
//					Log.logWarning("+ New engine " + AIEngine.GetName(transportEngineID) + "(" + nettoIncomePerMonth + ") for the connection: " + ToString() + ".");
				bestIncomePerMonth = nettoIncomePerMonth;
				bestTransportEngine = transportEngineID;
				bestHoldingEngine = holdingEngineID;
			}// else {
			//	Log.logWarning("- The old engine + " + AIEngine.GetName(bestTransportEngine) + "(" + bestIncomePerMonth + ") is better than " + AIEngine.GetName(transportEngineID) + "(" + nettoIncomePerMonth + ") for the connection: " + ToString() + ".");
			//}
		}
		
//		if (bestTransportEngine != null)
//			Log.logWarning("* The best engine for the connection: " + ToString() + " is " + AIEngine.GetName(bestTransportEngine) + " holding cargo by: " + AIEngine.GetName(bestHoldingEngine));
//		else
//			Log.logWarning("* No engine found suitable!");

		if (bestTransportEngine == null)
			return null;
		return [bestTransportEngine, bestHoldingEngine];
	}
	
	/**
	 * If the connection is build this function is called to update its
	 * internal state.
	 */
	function UpdateAfterBuild(vehicleType, fromTile, toTile, stationCoverageRadius) {
		
		if (!AIGroup.IsValidGroup(vehicleGroupID)) {
			vehicleGroupID = AIGroup.CreateGroup(vehicleType);
			AIGroup.SetName(vehicleGroupID, travelFromNode.GetName() + " to " + travelToNode.GetName());
		}
		
		pathInfo.UpdateAfterBuild(vehicleType, fromTile, toTile, stationCoverageRadius);
		lastChecked = AIDate.GetCurrentDate();
		vehicleTypes = vehicleType;
		forceReplan = false;
		
		// Cache the best vehicle we can build for this connection.
		local bestEngines = GetBestTransportingEngine(vehicleTypes);
		if (bestEngines != null) {
			bestTransportEngine = bestEngines[0];
			bestHoldingEngine = bestEngines[1];
		}

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not too near each
		// other.
		if (bilateralConnection && connectionType == TOWN_TO_TOWN) {
			travelFromNode.AddExcludeTiles(cargoID, fromTile, stationCoverageRadius);
			travelToNode.AddExcludeTiles(cargoID, toTile, stationCoverageRadius);
		}
		
		travelFromNode.activeConnections.push(this);
		travelToNode.reverseActiveConnections.push(this);
		
		connectionManager.ConnectionRealised(this);
	}
	
	/**
	 * Get the number of vehicles operating.
	 */
	function GetNumberOfVehicles() {

		if (!AIGroup.IsValidGroup(vehicleGroupID))
			return 0;
		return AIVehicleList_Group(vehicleGroupID).Count();
	}
	
	/**
	 * Destroy this connection.
	 */
	function Demolish(destroyFrom, destroyTo, destroyDepots) {
		if (!pathInfo.build)
			return;
			//assert(false);
			
		Log.logWarning("Demolishing connection from " + travelFromNode.GetName() + " to " + travelToNode.GetName());
		
		// Sell all vehicles.
		if (AIGroup.IsValidGroup(vehicleGroupID)) {
			
			local vehicleNotHeadingToDepot = true;
		
			// Send and wait till all vehicles are in their respective depots.
			while (vehicleNotHeadingToDepot) {
				vehicleNotHeadingToDepot = false;
			
				foreach (vehicleId, value in AIVehicleList_Group(vehicleGroupID)) {
					if (!AIVehicle.IsStoppedInDepot(vehicleId)) {
						
						if (vehicleTypes != AIVehicle.VT_ROAD && vehicleTypes != AIVehicle.VT_WATER)
							vehicleNotHeadingToDepot = true;
						// Check if the vehicles is actually going to the depot!
						if ((AIOrder.GetOrderFlags(vehicleId, AIOrder.ORDER_CURRENT) & AIOrder.AIOF_STOP_IN_DEPOT) == 0) {
							if (!AIVehicle.SendVehicleToDepot(vehicleId) && vehicleTypes == AIVehicle.VT_ROAD) {
								AIVehicle.ReverseVehicle(vehicleId);
								AIController.Sleep(5);
								AIVehicle.SendVehicleToDepot(vehicleId);
							}
							vehicleNotHeadingToDepot = true;
						}
					}
				}
			}
		}
		
		if (destroyFrom) {
			if (vehicleTypes == AIVehicle.VT_ROAD) {
				local startTileList = AITileList();
				local startStation = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
				
				startTileList.AddTile(startStation);
				DemolishStations(startTileList, AIStation.GetName(AIStation.GetStationID(startStation)), AITileList());
			}
			AITile.DemolishTile(pathInfo.roadList[pathInfo.roadList.len() - 1].tile);
		}
		
		if (destroyTo) {
			if (vehicleTypes == AIVehicle.VT_ROAD) {
				local endTileList = AITileList();
				local endStation = pathInfo.roadList[0].tile;
				
				endTileList.AddTile(endStation);
				DemolishStations(endTileList, AIStation.GetName(AIStation.GetStationID(endStation)), AITileList());
			}
			AITile.DemolishTile(pathInfo.roadList[0].tile);
		}
		
/*		if (destroyDepots) {
			AITile.DemolishTile(pathInfo.depot);
			if (pathInfo.depotOtherEnd)
				AITile.DemolishTile(pathInfo.depotOtherEnd);
		}
*/
		
		for (local i = 0; i < travelFromNode.activeConnections.len(); i++) {
			if (travelFromNode.activeConnections[i] == this) {
				travelFromNode.activeConnections.remove(i);
				break;
			}
		}
		
		for (local i = 0; i < travelToNode.reverseActiveConnections.len(); i++) {
			if (travelToNode.reverseActiveConnections[i] == this) {
				travelToNode.reverseActiveConnections.remove(i);
				break;
			}
		}

		connectionManager.ConnectionDemolished(this);
		
		pathInfo.build = false;
	}
	
	/**
	 * Utility function to destroy all road stations which are related.
	 * @param tileList A list of tiles which must be removed.
	 * @param stationName The name of stations to be removed.
	 * @param excludeList A list of stations already explored.
	 */
	function DemolishStations(tileList, stationName, excludeList) {
		if (tileList.Count() == 0)
			return;
 
 		local newTileList = AITileList();
		foreach (tile, value in tileList) {

			if (excludeList.HasItem(tile))
				continue;
 			local currentStationID = AIStation.GetStationID(tile);
			foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
				if (excludeList.HasItem(surroundingTile)) continue;
				excludeList.AddTile(surroundingTile);
	
				local stationID = AIStation.GetStationID(surroundingTile);
	
				if (AIStation.IsValidStation(stationID)) {

					// Only explore this possibility if the station has the same name!
					if (AIStation.GetName(stationID) != stationName)
						continue;
					
					while (AITile.IsStationTile(surroundingTile))
						AITile.DemolishTile(surroundingTile);
					
					if (!newTileList.HasItem(surroundingTile))
						newTileList.AddTile(surroundingTile);
				}			
			}
			
			DemolishStations(newTileList, stationName, excludeList);
 		}
	}
	
	
	// Everything below this line is just a toy implementation designed to test :)
	function GetLocationsForNewStation(atStart) {
		if (!pathInfo.build)
			return AIList();
	
		local tileList = AITileList();	
		local excludeList = AITileList();	
		local tile = null;
		if (atStart) {
			tile = pathInfo.roadList[0].tile;
		} else {
			tile = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
		}
		excludeList.AddTile(tile);
		GetSurroundingTiles(tile, tileList, excludeList);
		
		return tileList;
	}
	
	function GetSurroundingTiles(tile, tileList, excludeList) {

		local currentStationID = AIStation.GetStationID(tile);
		foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
			if (excludeList.HasItem(surroundingTile)) continue;

			local stationID = AIStation.GetStationID(surroundingTile);

			if (AIStation.IsValidStation(stationID)) {
				excludeList.AddTile(surroundingTile);

				// Only explore this possibility if the station has the same name!
				if (AIStation.GetName(stationID) != AIStation.GetName(currentStationID))
					continue;

				GetSurroundingTiles(surroundingTile, tileList, excludeList);
				continue;
			}

			if (!tileList.HasItem(surroundingTile))
				tileList.AddTile(surroundingTile);
		}
	}
	
	function GetUID() {
		return travelFromNode.GetUID(cargoID);
	}
	
	function ToString() {
		return "From: " + travelFromNode.GetName() + " to " + travelToNode.GetName() + " carrying: " + AICargo.GetCargoLabel(cargoID);
	}
}
