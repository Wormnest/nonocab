class ManageVehiclesAction extends Action {

	vehiclesToSell = null;		// List of vehicles IDs which need to be sold.
	vehiclesToBuy = null;		// List of [engine IDs, number of vehicles to buy, tile ID of a depot]
	pathfinder = null;

	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
		Action.constructor();

		local pathFinderHelper = RoadPathFinderHelper(false);
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
function ManageVehiclesAction::BuyVehicles(engineID, number, wagonEngineID, numberWagons, connection)
{
	vehiclesToBuy.push([engineID, number, wagonEngineID, numberWagons, connection]);
}

function ManageVehiclesAction::Execute()
{
	AIExecMode();
	// Sell the vehicles.
	//Log.logInfo("Sell " + vehiclesToSell.len() + " vehicles.");
	foreach (engineInfo in vehiclesToSell) {
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];
		local vehicleType = AIEngine.GetVehicleType(engineID);
		
		pathfinder.pathFinderHelper.SetStationBuilder(AIEngine.IsArticulated(engineID));
		
		// First of all we need to find suitable candidates to remove.
		local vehicleList = AIList();
		local vehicleArray = null;

		if (connection.vehicleGroupID == null || !AIGroup.IsValidGroup(connection.vehicleGroupID)) {
			connection.connectionManager.PrintConnections();
			Log.logError("Sell Vehicle: Invalid vehicle group for connection " + connection.ToString());
			continue;
		}
		local vehicleList = AIVehicleList_Group(connection.vehicleGroupID);
		vehicleList.Valuate(AIVehicle.GetAge);
		vehicleList.Sort(AIList.SORT_BY_VALUE, true);
		if (!connection.bilateralConnection) {
			// Don't use AIEngine.GetCargoType(engineID) below since that may be wrong for train wagons or when we need to refit first.
			vehicleList.Valuate(AIVehicle.GetCargoLoad, connection.cargoID);
			vehicleList.RemoveAboveValue(0);
		}

		local vehiclesDeleted = 0;
		
		foreach (vehicleID, value in vehicleList) {
			Log.logDebug("Vehicle: " + AIVehicle.GetName(vehicleID) + " is being sent to depot to be sold.");
			
			// Take a different approach with ships, as they might get lost.
			if (vehicleType == AIVehicle.VT_WATER) {
				// First make sure orders are not shared.
				ManageVehiclesAction.UnshareVehicleOrders(vehicleID);
				// Make sure it's not going to try loading cargo.
				ManageVehiclesAction.RemoveFullLoadOrders(vehicleID);
				// Set age at which to go to depot to 0 so it will stop as soon as it reaches the first order in the list.
				AIOrder.SetOrderCompareValue(vehicleID, 0, 0);
				++vehiclesDeleted;
			} else if (!AIVehicle.SendVehicleToDepot(vehicleID)) {
        		AIVehicle.ReverseVehicle(vehicleID);
				AIController.Sleep(5);
				if (AIVehicle.SendVehicleToDepot(vehicleID))
					++vehiclesDeleted;
			}
			else
				++vehiclesDeleted;

			if (vehiclesDeleted == vehicleNumbers/* && AIEngine.GetVehicleType(engineID) == AIVehicle.VT_AIR*/) {
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
		local wagonEngineID = engineInfo[2];
		local numberWagons = engineInfo[3];
		local connection = engineInfo[4];

		local vehicleID = null;
		local vehicleGroup = null;
		local vehicleType = AIEngine.GetVehicleType(engineID);
		
		if (vehicleType == AIVehicle.VT_RAIL) {
			// Extra check to make sure we can build engine in current depot even though incompatibility should not happen here.
			local railTypeOfConnection = AIRail.GetRailType(connection.pathInfo.depot);
			if (!AIEngine.CanRunOnRail(engineID, railTypeOfConnection) ||
				!AIEngine.HasPowerOnRail(engineID, railTypeOfConnection) ||
				(AIRail.GetMaxSpeed(railTypeOfConnection) < AIRail.GetMaxSpeed(TrainConnectionAdvisor.GetBestRailType(engineID)))) {
				// This shouldn't happen anymore.
				Log.logError("Unexpectedly we can't use the chosen rail engine on the current track!");
				Log.logWarning("Railtype: " + AIRail.GetName(railTypeOfConnection) + ", but engine: " + AIEngine.GetName(engineID) +
					" needs: " + AIRail.GetName(TrainConnectionAdvisor.GetBestRailType(engineID)));
				continue;
			}
		}

		local maxBuildableVehicles =  GameSettings.GetMaxBuildableVehicles(vehicleType);
		if (vehicleNumbers > maxBuildableVehicles)
			vehicleNumbers = maxBuildableVehicles;
		else if (maxBuildableVehicles <= 20 && vehicleNumbers > 2)
			// When there are only a limited number of available vehicles left don't buy more than 2 per connection
			vehicleNumbers = 2;
		
		if (vehicleNumbers == 0) {
			Log.logInfo("Can't buy more vehicles, we have reached the maximum!");
			continue; /// @todo Maybe we should even use a break here since we can't get more vehicles.
		}
		Log.logInfo("Buy " + vehicleNumbers + " " + AIEngine.GetName(engineID) + " " + AIEngine.GetName(wagonEngineID) + ".");

		if (connection.vehicleGroupID == null || !AIGroup.IsValidGroup(connection.vehicleGroupID)) {
			connection.connectionManager.PrintConnections();
			Log.logError("Invalid vehicle group for connection " + connection.ToString());
			continue;
		}
		assert (AIGroup.IsValidGroup(connection.vehicleGroupID));
		
		// In case of a bilateral connection we want to spread the load by sending the trucks
		// in opposite directions.
		local directionToggle = AIStation.GetCargoWaiting(connection.pathInfo.travelFromNodeStationID, connection.cargoID) 
			> AIStation.GetCargoWaiting(connection.pathInfo.travelToNodeStationID, connection.cargoID);
		
		// If we want to build aircrafts or ships, we only want to build 1 per station!
		if (vehicleType == AIVehicle.VT_WATER || vehicleType == AIVehicle.VT_AIR) {
			if (connection.bilateralConnection && vehicleNumbers > 4)
				vehicleNumbers = 4;
			else if (vehicleNumbers > 2)
				vehicleNumbers = 2;
		} else if (vehicleType == AIVehicle.VT_ROAD) {
			if (connection.bilateralConnection && vehicleNumbers > 30)
				vehicleNumbers = 30;
			else if (vehicleNumbers > 15)
				vehicleNumbers = 15;
		}
			
		local vehiclePrice = AIEngine.GetPrice(engineID);
		if (vehicleType == AIVehicle.VT_RAIL)
			vehiclePrice += numberWagons * AIEngine.GetPrice(wagonEngineID);
		totalCosts = vehiclePrice;

		local vehicleCloneID = -1;
		local vehicleCloneIDReverse = -1;
		local group_vehicles = AIVehicleList_Group(connection.vehicleGroupID);
		local wrongEngine = false;
		if (group_vehicles.Count() > 0) {
			foreach (veh, dummy in group_vehicles) {
				// Second order (order nr 1) is the first order that can be a go to depot order. However there can be buoys in between!
				local depot_order = 1;
				local order_cnt = AIOrder.GetOrderCount(veh);
				local depot_loc = -1;
				while (depot_order < order_cnt) {
					if (AIOrder.IsGotoDepotOrder(veh, depot_order)) {
						depot_loc = AIOrder.GetOrderDestination(veh, depot_order);
						break;
					}
					depot_order++;
				}
				if (depot_loc == -1)
					Log.logError("No depot order found for vehicle " + AIVehicle.GetName(veh) + "! Group: " + AIGroup.GetName(connection.vehicleGroupID));
				if (vehicleCloneID == -1 && depot_loc == connection.pathInfo.depot) {
					// Check whether it has the same engine that we want to use
					if (AIVehicle.GetEngineType(veh) == engineID) {
						vehicleCloneID = veh;
						wrongEngine = false;
					}
					else
						wrongEngine = true;
				}
				else if (connection.bilateralConnection && vehicleCloneIDReverse == -1 && depot_loc == connection.pathInfo.depotOtherEnd) {
					if (AIVehicle.GetEngineType(veh) == engineID) {
						vehicleCloneIDReverse = veh;
					}
				}
				if (vehicleCloneID != -1 && (!connection.bilateralConnection || vehicleCloneIDReverse != -1))
					break;
			}
			if (vehicleCloneID == -1 && !wrongEngine)
				// Note that this can happen if we had more vehicles in the past and sold some leaving only some for depotOtherEnd.
				Log.logWarning("No vehicle that we can clone found! Group: " + AIGroup.GetName(connection.vehicleGroupID));
		}

		for (local i = 0; i < vehicleNumbers; i++) {
		
			// Make sure we have enough money (if possible)
			Finance.GetMoney(vehiclePrice);

			if (Finance.GetMaxMoneyToSpend() - vehiclePrice < 0) {
				Log.logDebug("Not enough money to build all vehicles!");
				break;
			}
					
			local vehicleID;

			if (!directionToggle && connection.bilateralConnection) {
				if (vehicleCloneIDReverse != -1) {
					vehicleID = AIVehicle.CloneVehicle(connection.pathInfo.depotOtherEnd, vehicleCloneIDReverse, true);
					directionToggle = !directionToggle;
					AIGroup.MoveVehicle(connection.vehicleGroupID, vehicleID);
					AIVehicle.StartStopVehicle(vehicleID);
					continue;
				}
				if (vehicleType == AIVehicle.VT_RAIL)
					vehicleID = BuildTrain(connection.pathInfo.depotOtherEnd, engineID, connection.cargoID, wagonEngineID, numberWagons);
				else
					vehicleID = BuildVehicle(connection.pathInfo.depotOtherEnd, engineID, connection.cargoID, true);
				if (vehicleID == null)
					break;
				vehicleCloneIDReverse = vehicleID;
			} else {
				if (vehicleCloneID != -1) {
					vehicleID = AIVehicle.CloneVehicle(connection.pathInfo.depot, vehicleCloneID, true);
					directionToggle = !directionToggle;
					AIGroup.MoveVehicle(connection.vehicleGroupID, vehicleID);
					AIVehicle.StartStopVehicle(vehicleID);
					continue;
				}
				if (vehicleType == AIVehicle.VT_RAIL)
					vehicleID = BuildTrain(connection.pathInfo.depot, engineID, connection.cargoID, wagonEngineID, numberWagons);
				else
					vehicleID = BuildVehicle(connection.pathInfo.depot, engineID, connection.cargoID, true);
				if (vehicleID == null)
					break; // No need trying to build more of the same vehicle if building this one failed.
				vehicleCloneID = vehicleID;
			}
			
			if (vehicleID == null) {
				Log.logError("Failed to build vehicle. Error: " + AIError.GetLastErrorString());
				// And don't try to get more.
				break;
			}
			
			// Add vehicle to the correct group for this connection.
			AIGroup.MoveVehicle(connection.vehicleGroupID, vehicleID);
			
			// Give the vehicle orders and start it.
			SetOrders(vehicleID, vehicleType, connection, directionToggle);
			// Make sure it has orders!
			if (AIOrder.GetOrderCount(vehicleID) == 0) {
				Log.logError("Failed to add orders to vehicle " + AIVehicle.GetName(vehicleID) + ". Error: " + AIError.GetLastErrorString());
				// Vehicle without orders is worthless so sell it again!
				AIVehicle.SellVehicle(vehicleID);
				// And don't try to get more.
				break;
			}

			AIVehicle.StartStopVehicle(vehicleID);

			// Update the game setting so subsequent actions won't build more vehicles then possible!
			// (this will be overwritten anyway during the update).
			GameSettings.maxVehiclesBuildLimit[vehicleType]--;

			directionToggle = !directionToggle;
		}			
	}
	CallActionHandlers();
	return true;
}

/**
 * Build a vehicle at the specified depot and refit to the specified cargoID if necessary.
 * @param depot The depot where the vehicle should be built.
 * @param engineID The ID of the engine to build.
 * @param cargoID The cargoID of the cargo that should be transported.
 * @param failOnRefitError Whether failure to refit should sell the vehicle or not.
 * @pre Valid engineID, depot should be valid and be able to handle the chosen engine, engineID should be able to be refitted to cargoID.
 */
function ManageVehiclesAction::BuildVehicle(depot, engineID, cargoID, failOnRefitError)
{
	local vehicleID = AIVehicle.BuildVehicle(depot, engineID);
	if (!AIVehicle.IsValidVehicle(vehicleID)) {
		Log.logError("Error building vehicle with engine: "  + AIEngine.GetName(engineID) + ", " + AIError.GetLastErrorString() + " depot: " + depot + "!");
		if (!AIEngine.IsBuildable(engineID))
			Log.logError("Engine is not buildable!");
		return null;
	}

	// Refit if necessary.
	if (cargoID != AIEngine.GetCargoType(engineID)) {
		local refitresult = AIVehicle.RefitVehicle(vehicleID, cargoID);
		if (!refitresult) {
			if (failOnRefitError) {
				Log.logError("Refitting vehicle " + AIVehicle.GetName(vehicleID) + " to " +
				AICargo.GetCargoLabel(cargoID) + " failed! " + AIError.GetLastErrorString());

				// Since it's no use having a vehicle that can't transport the cargo we want sell it again!
				AIVehicle.SellVehicle(vehicleID);
				return null;
			}
			else {
				Log.logDebug("Refit failed for " + AIVehicle.GetName(vehicleID) + " to " + AICargo.GetCargoLabel(cargoID));
			}
		}
	}
	
	return vehicleID;
}

/**
 * Build a train.
 * @param depot The depot where the vehicle should be built.
 * @param engineID The ID of the train engine to build.
 * @param cargoID The cargoID of the cargo that should be transported.
 * @param wagonEngineID The ID of the wagon to build.
 * @param numberWagons The amount of wagons to build.
 * @pre Valid engineID, wagonEngineID, depot should be valid and be able to handle the chosen engine, wagonEngineID should be able to be refitted to cargoID.
 */
function ManageVehiclesAction::BuildTrain(depot, engineID, cargoID, wagonEngineID, numberWagons)
{
	// First build the train engine
	//Log.logDebug("Build train with engine " + AIEngine.GetName(engineID));
	local vehicleID = ManageVehiclesAction.BuildVehicle(depot, engineID, cargoID, false);
	if (vehicleID != null) {
		//Log.logDebug("Build wagons with engine " + AIEngine.GetName(wagonEngineID));
		/// @todo This is expecting wagons to alwats have a length of 0.5 tile? This needs to be changed! Maybe also in a few other places!
		local nrWagons = numberWagons - (AIVehicle.GetLength(vehicleID) / 8) + 1;
		local wagonsBuilt = 0;
		// Now build the train wagons
		for (local j = 0; j < nrWagons; j++) {
			local wagonVehicleID = AIVehicle.BuildVehicle(depot, wagonEngineID);
		
			if (!AIVehicle.IsValidVehicle(wagonVehicleID)) {
				Log.logError("Error building train wagon with engine: "  + AIEngine.GetName(wagonEngineID) + ", " + AIError.GetLastErrorString() + " depot: " + depot + "!");
				break;
			}

			if (cargoID != AIEngine.GetCargoType(wagonEngineID))
				if (!AIVehicle.RefitVehicle(wagonVehicleID, cargoID)) {
					Log.logError("Refitting wagon " + AIVehicle.GetName(wagonVehicleID) + " to " +
					AICargo.GetCargoLabel(cargoID) + " failed! " + AIError.GetLastErrorString());
					// Since it's no use having a vehicle that can't transport the cargo we want sell it again!
					AIVehicle.SellVehicle(wagonVehicleID);
					break;
				}
		
			AIVehicle.MoveWagon(wagonVehicleID, 0, vehicleID, 0);
			wagonsBuilt++;
		}
		if (wagonsBuilt == 0 && AIVehicle.GetCapacity(vehicleID, cargoID) == 0) {
			Log.logError("We couldn't add any wagons to this train and the train itself doesn't have any capacity for cargo " + AICargo.GetCargoLabel(cargoID));
			// Since it's no use having a vehicle that can't transport the cargo we want sell it again!
			AIVehicle.SellVehicle(vehicleID);
			return null;
		}
		return vehicleID;
	}
	else
		return null;
}

/**
 * Set orders for vehicle.
 * @param vehicleID The ID of the vehicle to assign orders to.
 * @param vehicleType The type of vehicle.
 * @param connection The connection this vehicle belongs to.
 * @param directionToggle Whether or not to reverse the to and from stations in orders.
 * @pre Valid vehicle, connection, connection.pathInfo, connection.pathInfo.roadList.
 */
function ManageVehiclesAction::SetOrders(vehicleID, vehicleType, connection, directionToggle)
{
	local extraOrderFlags = (vehicleType == AIVehicle.VT_RAIL || vehicleType == AIVehicle.VT_ROAD ? AIOrder.OF_NON_STOP_INTERMEDIATE : 0);
	local roadList = connection.pathInfo.roadList;
	local breakdowns = AIGameSettings.GetValue("difficulty.vehicle_breakdowns") > 0;
	
	// Send the vehicles on their way.
	if (connection.bilateralConnection && !directionToggle) {
		if (vehicleType == AIVehicle.VT_RAIL && breakdowns)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.OF_NONE | extraOrderFlags);
		AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.OF_FULL_LOAD_ANY | extraOrderFlags);
		if (breakdowns && vehicleType != AIVehicle.VT_RAIL && vehicleType != AIVehicle.VT_WATER)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.OF_NONE | extraOrderFlags);

		// If it's a ship, give it additional orders!
		// We now always add one depot order even with breakdowns on. This way if we use autoreplacement to upgrade a ship it can be replaced when it visits the depot.
		if (vehicleType == AIVehicle.VT_WATER) {
			local once = false;
			for (local i = 1; i < roadList.len() - 1; i++) {
				if (AIMarine.IsBuoyTile(roadList[i].tile))
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
				else if (!once && AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					// No check for breakdowns since we need at least one depot order for autoreplacement.
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					once = true;
				}
			}
		}

		if (vehicleType == AIVehicle.VT_RAIL && breakdowns)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.OF_NONE | extraOrderFlags);
		AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.OF_FULL_LOAD_ANY | extraOrderFlags);

		if (breakdowns && vehicleType != AIVehicle.VT_RAIL && vehicleType != AIVehicle.VT_WATER)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.OF_NONE | extraOrderFlags);

		if (vehicleType == AIVehicle.VT_WATER) {
			local once = false;
			for (local i = roadList.len() - 2; i > 0; i--) {
				if (AIMarine.IsBuoyTile(roadList[i].tile))
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
				else if (breakdowns && !once && AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					once = true;
				}
			}
		}
	} else {
		if (vehicleType == AIVehicle.VT_RAIL && breakdowns)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.OF_NONE | extraOrderFlags);
		AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.OF_FULL_LOAD_ANY | extraOrderFlags);
		if (breakdowns && vehicleType != AIVehicle.VT_RAIL && vehicleType != AIVehicle.VT_WATER)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.OF_NONE | extraOrderFlags);

		// If it's a ship, give it additional orders! (and also to depot order if breakdowns are on)
		// The go to depot order needs to be done together with the buoy orders because sometimes the depot comes after several buoys.
		// We now always add one depot order even with breakdowns on. This way if we use autoreplacement to upgrade a ship it can be replaced when it visits the depot.
		if (vehicleType == AIVehicle.VT_WATER) {
			local once = false;
			for (local i = roadList.len() - 2; i > 0; i--) {
				if (AIMarine.IsBuoyTile(roadList[i].tile))
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
				else if (!once && AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					// No check for breakdowns since we need at least one depot order for autoreplacement.
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					once = true;
				}
			}
		}

		if (vehicleType == AIVehicle.VT_RAIL && breakdowns)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.OF_NONE | extraOrderFlags);

		if (connection.bilateralConnection)
			AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.OF_FULL_LOAD_ANY | extraOrderFlags);
		else
			AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.OF_UNLOAD | AIOrder.OF_NO_LOAD);

		if (breakdowns && connection.bilateralConnection && vehicleType != AIVehicle.VT_RAIL && vehicleType != AIVehicle.VT_WATER)
			AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.OF_NONE | extraOrderFlags);
			
		if (vehicleType == AIVehicle.VT_WATER) {
			// If it's not a bilateral connection we have only a depot at the start so on the way back we should not use a depot.
			local once = (connection.bilateralConnection ? false : true);
			for (local i = 1; i < roadList.len() - 1; i++) {
				if (AIMarine.IsBuoyTile(roadList[i].tile))
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
				else if (breakdowns && !once && AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					once = true;
				}
			}
		}
	}

	
	// As a first order, let the vehicle do it's normal actions when not old enough.
	AIOrder.InsertConditionalOrder(vehicleID, 0, 0);
	
	// Set orders to stop the vehicle in a depot once it reached its max age.
	AIOrder.SetOrderCondition(vehicleID, 0, AIOrder.OC_AGE);
	AIOrder.SetOrderCompareFunction(vehicleID, 0, AIOrder.CF_LESS_THAN);
	AIOrder.SetOrderCompareValue(vehicleID, 0, AIVehicle.GetMaxAge(vehicleID) / 366);

	// Insert the stopping order, which will be skipped by the previous conditional order if the vehicle hasn't reached its maximum age.
	// Water vehicles need extra handling because there can't be too much distance between depot and dock or we get ERR_ORDER_TOO_FAR_AWAY_FROM_PREVIOUS_DESTINATION
	// and we also may have buoys between dock and depot which if not handled  would lead to an inefficient route order.
	local result = false;
	if (vehicleType != AIVehicle.VT_WATER) {
		if (connection.bilateralConnection && directionToggle)
			result = AIOrder.InsertOrder(vehicleID, 1, connection.pathInfo.depotOtherEnd, AIOrder.OF_STOP_IN_DEPOT);
		else
			result = AIOrder.InsertOrder(vehicleID, 1, connection.pathInfo.depot, AIOrder.OF_STOP_IN_DEPOT);
	}
	else {
		local order = 1;
		// First buoy needs to be ignored since that's the buoy our orders end with.
		// However since it's possible we encounter the depot before the buoy we can't just skip that index.
		local ignorebuoy = true;
		if (!connection.bilateralConnection || directionToggle) {
			// A non bilateral connection always needs to go here since there's only one depot.
			for (local i = roadList.len() - 2; i > 0; i--) {
				if (!ignorebuoy && AIMarine.IsBuoyTile(roadList[i].tile)) {
					AIOrder.InsertOrder(vehicleID, order, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					order++;
				}
				else if (AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					result = AIOrder.InsertOrder(vehicleID, order, roadList[i].tile, AIOrder.OF_STOP_IN_DEPOT);
					break;
				}
				ignorebuoy = false;
			}
		}
		else
			for (local i = 1; i < roadList.len() - 1; i++) {
				if (!ignorebuoy && AIMarine.IsBuoyTile(roadList[i].tile)) {
					AIOrder.InsertOrder(vehicleID, order, roadList[i].tile, AIOrder.OF_NONE | extraOrderFlags);
					order++;
				}
				else if (AIMarine.IsWaterDepotTile(roadList[i].tile)) {
					result = AIOrder.InsertOrder(vehicleID, order, roadList[i].tile, AIOrder.OF_STOP_IN_DEPOT);
					break;
				}
				ignorebuoy = false;
			}
	}
	if (!result) {
		Log.logError("Could not add stop in depot order! " + connection.bilateralConnection + ", " + directionToggle + ", " + AIError.GetLastErrorString());
	}
	if (AIOrder.GetOrderCount(vehicleID) == 0)
		Log.logError("Failed to add orders to this vehicle! " + AIError.GetLastErrorString());
}

/**
 * Autoreplace all vehicles in this group. Checks all vehicles and sets all different engines to be auto replaced.
 * @param groupID The vehicle group ID.
 * @param vehicleType the type of vehicles this group has.
 * @param newEngine The replacement engine.
 * @param newHoldingEngine The replacement holding engine.
 */
function ManageVehiclesAction::AutoReplaceVehicles(groupID, vehicleType, newEngine, newHoldingEngine)
{
	local vehicles = AIVehicleList_Group(groupID);
	local replaceEngines = {};
	foreach (veh, dummy in vehicles) {
		local oldEngine = AIVehicle.GetEngineType(veh);
		if (oldEngine == newEngine)
			continue;
		if (!AIEngine.IsValidEngine(oldEngine)) {
			Log.logWarning("Autoreplace: vehicle engine is invalid! Vehicle: " + AIVehicle.GetName(veh));
			continue;
		}
		if (!replaceEngines.rawin(oldEngine)) {
			replaceEngines.rawset(oldEngine, null);
			local wagon = null;
			if (vehicleType == AIVehicle.VT_RAIL && AIVehicle.GetNumWagons(veh) > 0) {
				wagon = AIVehicle.GetWagonEngineType(veh,0);
				if (wagon == newHoldingEngine)
					wagon = null;
			}
			Log.logInfo("Autoreplace " + AIEngine.GetName(oldEngine) + " with " + AIEngine.GetName(newEngine));
			if (!AIGroup.SetAutoReplace(groupID, oldEngine, newEngine))
				Log.logError("Setting autoreplace failed!");
			if (wagon != null)
				AIGroup.SetAutoReplace(groupID, wagon, newHoldingEngine);
		}
	}
}

/**
 * Send all vehicles in this group for maintenance. This should only be necessary if breakdowns are turned off.
 * @param groupID The vehicle group ID.
 * @param vehicleType the type of vehicles this group has.
 */
function ManageVehiclesAction::SendVehiclesForMaintenance(groupID, vehicleType)
{
	local vehicles = AIVehicleList_Group(groupID);
	foreach (veh, dummy in vehicles) {
		if (!AIVehicle.SendVehicleToDepotForServicing(veh) && vehicleType == AIVehicle.VT_ROAD) {
       		AIVehicle.ReverseVehicle(veh);
			AIController.Sleep(5);
			AIVehicle.SendVehicleToDepotForServicing(veh);
		}
	}
}

/**
 * Get the first vehicle that shares orders with the specified vehicleID.
 * @param vehicleID The vehicle ID to find a shared vehicle of.
 * @return The first found vehicle that shares orders with vehicleID or null if not found.
 */
function ManageVehiclesAction::GetSharedVehicle(vehicleID)
{
	local shared_vehicles = AIVehicleList_SharedOrders(vehicleID);
	local share_veh = null;
	if (shared_vehicles.Count() > 1) {
		foreach (veh, dummy in shared_vehicles)
			if (veh != vehicleID) {
				share_veh = veh;
				break;
			}
	}
	return share_veh;
}

/**
 * If a vehicles has shared orders then unshare them by copying the orders from another vehicle with the same orders.
 * @param vehicleID The vehicle ID to unshare.
 * @return The first found vehicle that shares orders with vehicleID or null if not found.
 */
function ManageVehiclesAction::UnshareVehicleOrders(vehicleID)
{
	// Check to see whether it shares orders.
	if (AIVehicle.HasSharedOrders(vehicleID)) {
		// Since AIOrder.UUnshareOrders seems to remove all orders we are going to use CopyOrders and copy from another vehicle.
		local share_veh = ManageVehiclesAction.GetSharedVehicle(vehicleID)
		if (share_veh == null)
			Log.logError("Could not find shared vehicle! ");
		else if (!AIOrder.CopyOrders(vehicleID, share_veh))
			Log.logError("Could not copy orders! " + AIError.GetLastErrorString());
	}
}

/**
 * Remove full load (any) orders and change them to no loading.
 * @param vehicleID The vehicle ID which needs its orders changed.
 */
function ManageVehiclesAction::RemoveFullLoadOrders(vehicleID)
{
	local orderCount = AIOrder.GetOrderCount(vehicleID);
	for (local order = 0; order < orderCount; order++) {
		local orderFlags = AIOrder.GetOrderFlags(vehicleID, order);
		if ((orderFlags & (AIOrder.OF_FULL_LOAD+AIOrder.OF_FULL_LOAD_ANY)) != 0)
			AIOrder.SetOrderFlags(vehicleID, order, AIOrder.OF_NO_LOAD);
	}
}
