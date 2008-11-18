class ManageVehiclesAction extends Action {

	vehiclesToSell = null;		// List of vehicles IDs which need to be sold.
	vehiclesToBuy = null;		// List of [engine IDs, number of vehicles to buy, tile ID of a depot]
	pathfinder = null;

	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
		Action.constructor();

		local pathFinderHelper = RoadPathFinderHelper();
		pathFinderHelper.costTillEnd = pathFinderHelper.costForNewRoad;

		pathfinder = RoadPathFinding(pathFinderHelper);
	}
}

/**
 * Sell a vehicle when this action is executed.
 * @param vehicleID The vehicle ID of the vehicle which needs to be sold.
 */
function ManageVehiclesAction::SellVehicles(engineID, number, connection)
{
	vehiclesToSell.push([engineID, number, connection]);
}

/**
 * Buy a certain number of vehicles when this action is executed.
 * @param engineID The engine ID of the vehicles which need to be build.
 * @param number The number of vehicles to build.
 * @param connection The connection where the vehicles are to operate on.
 */
function ManageVehiclesAction::BuyVehicles(engineID, number, connection)
{
	vehiclesToBuy.push([engineID, number, connection]);
}

function ManageVehiclesAction::Execute()
{
	AIExecMode();
	// Sell the vehicles.
	Log.logInfo("Sell " + vehiclesToSell.len() + " vehicles.");
	foreach (engineInfo in vehiclesToSell) {
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];	
		
		// First of all we need to find suitable candidates to remove.
		local vehicleList = AIList();
		local vehicleArray = null;
		
		foreach (vehicleGroup in connection.vehiclesOperating) {
		
			if (vehicleGroup.vehicleIDs.len() > 0 && AIVehicle.GetEngineType(vehicleGroup.vehicleIDs[0]) == engineID) {
				foreach (vehicleID in vehicleGroup.vehicleIDs)
					vehicleList.AddItem(vehicleID, vehicleID);
				vehicleArray = vehicleGroup.vehicleIDs;
				break;
			}
		}
		vehicleList.Valuate(AIVehicle.GetAge);
		vehicleList.Sort(AIAbstractList.SORT_BY_VALUE, false);
		if (!connection.bilateralConnection) {
			vehicleList.Valuate(AIVehicle.GetCargoLoad, AIEngine.GetCargoType(engineID));
			vehicleList.RemoveAboveValue(0);
		}

		local vehiclesDeleted = 0;
		
		foreach (vehicleID, value in vehicleList) {
				
        	if (!AIVehicle.SendVehicleToDepot(vehicleID)) {
        		AIVehicle.ReverseVehicle(vehicleID);
				AIController.Sleep(5);
				if (AIVehicle.SendVehicleToDepot(vehicleID))
					++vehiclesDeleted;
			}
			else
				++vehiclesDeleted;
			
			foreach (id, value in vehicleArray) {
				if (value == vehicleID) {
					vehicleArray.remove(id);
					break;
				}
			} 

			if (vehiclesDeleted == vehicleNumbers && AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_AIR) {
				// Update the creation date of the connection so vehicles don't get
				// removed twice!
				connection.pathInfo.buildDate = AIDate.GetCurrentDate();
				break;
			}
		}
	}
	
	// Buy the vehicles.
	// During execution we keep track of the number of vehicles we can buy.
	foreach (engineInfo in vehiclesToBuy) {
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];

		local vehicleID = null;
		local vehicleGroup = null;
		local vehicleType = AIEngine.GetVehicleType(engineID);

		local maxBuildableVehicles =  GameSettings.GetMaxBuildableVehicles(vehicleType);
		if (vehicleNumbers > maxBuildableVehicles)
			vehicleNumbers = maxBuildableVehicles;
		
		Log.logInfo("Buy " + vehicleNumbers + " " + AIEngine.GetName(engineID) + ".");
		
		// Search if there are already have a vehicle group with this engine ID.
		foreach (vGroup in connection.vehiclesOperating) {
			if (vGroup.engineID == engineID) {
				vehicleGroup = vGroup;
				break;
			}
		}	
		
		// If there isn't a vehicles group we create one.
		if (vehicleGroup == null) {
			vehicleGroup = VehicleGroup();
			vehicleGroup.connection = connection;
			
			if (vehicleType == AIVehicle.VEHICLE_ROAD) {
				vehicleGroup.timeToTravelTo = RoadPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				vehicleGroup.timeToTravelFrom = RoadPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			} else if (vehicleType == AIVehicle.VEHICLE_AIR){ 
				local manhattanDistance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
				vehicleGroup.timeToTravelTo = (manhattanDistance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(engineID)).tointeger();
				vehicleGroup.timeToTravelFrom = vehicleGroup.timeToTravelTo;
			} else if (vehicleType == AIVehicle.VEHICLE_WATER) {
				vehicleGroup.timeToTravelTo = WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				vehicleGroup.timeToTravelFrom = WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			}
			vehicleGroup.incomePerRun = AICargo.GetCargoIncome(connection.cargoID, 
				AIMap.DistanceManhattan(connection.pathInfo.roadList[0].tile, connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile), 
				vehicleGroup.timeToTravelTo) * AIEngine.GetCapacity(engineID);	
			vehicleGroup.engineID = engineID;
			connection.vehiclesOperating.push(vehicleGroup);
		}
		
		// In case of a bilateral connection we want to spread the load by sending the trucks
		// in opposite directions.
		local directionToggle = false;
		
		// Use a 'main' vehicle to enable the sharing of orders.
		local roadList = connection.pathInfo.roadList;
		local mainVehicleID = -1;
		local mainVehicleIDReverse = -1;
		foreach (vehicle in vehicleGroup.vehicleIDs) {
			if (AIOrder.GetOrderDestination(vehicle, 0) == roadList[0].tile)
				mainVehicleIDReverse = vehicle;
			else
				mainVehicleID = vehicle;

			if (mainVehicleID != -1 && mainVehicleIDReverse != -1)
				break;
		}

		for (local i = 0; i < vehicleNumbers; i++) {
		
			if (Finance.GetMaxMoneyToSpend() - AIEngine.GetPrice(engineID) < 0) {
				Log.logDebug("Not enough money to build all prescibed vehicles!");
				break;
			}
					
			local vehicleID;

			if (directionToggle && connection.pathInfo.depotOtherEnd)
				vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depotOtherEnd, engineID);
			else
				vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depot, engineID);
			if (!AIVehicle.IsValidVehicle(vehicleID)) {
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + connection.pathInfo.depotOtherEnd + "!");
				continue;
			}

			// Refit if necessary.
			if (connection.cargoID != AIEngine.GetCargoType(engineID))
				AIVehicle.RefitVehicle(vehicleID, connection.cargoID);
			vehicleGroup.vehicleIDs.push(vehicleID);
			
			// Send the vehicles on their way.
			if (mainVehicleID != -1 && (!connection.bilateralConnection || !directionToggle)) {
				AIOrder.ShareOrders(vehicleID, mainVehicleID);
			} else if (mainVehicleIDReverse != -1 && connection.bilateralConnection && directionToggle) {
				AIOrder.ShareOrders(vehicleID, mainVehicleIDReverse);
			} else {
				if(connection.bilateralConnection) {
	
					if (directionToggle) {
						AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD_ANY);
						// If it's a ship, give it additional orders!
						if (AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_WATER) {
							roadList.reverse();
							foreach (at in roadList.slice(1, -1))
								AIOrder.AppendOrder(vehicleID, at.tile, AIOrder.AIOF_NONE);
							roadList.reverse();
						}
						AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD_ANY);
						mainVehicleIDReverse = vehicleID;
					} else {
						AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD_ANY);
						// If it's a ship, give it additional orders!
						if (AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_WATER) {
							roadList.reverse();
							foreach (at in roadList.slice(1, -1))
								AIOrder.AppendOrder(vehicleID, at.tile, AIOrder.AIOF_NONE);
							roadList.reverse();
						}
						AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD_ANY);
						mainVehicleID = vehicleID;
					}
//					directionToggle = !directionToggle;
				} else {
					AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD_ANY);
	
					// If it's a ship, give it additional orders!
					if (AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_WATER) {
						roadList.reverse();
						foreach (at in roadList.slice(1, -1))
							AIOrder.AppendOrder(vehicleID, at.tile, AIOrder.AIOF_NONE);
						roadList.reverse();
					}
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_UNLOAD);
					mainVehicleID = vehicleID;
				}
				
				if (vehicleType == AIVehicle.VEHICLE_ROAD)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
			}


			if(connection.bilateralConnection)
				directionToggle = !directionToggle;

			AIVehicle.StartStopVehicle(vehicleID);

			// Update the game setting so subsequent actions won't build more vehicles then possible!
			// (this will be overwritten anyway during the update).
			GameSettings.maxVehiclesBuildLimit[vehicleType]--;
		}			
	}
	CallActionHandlers();
	return true;
}
