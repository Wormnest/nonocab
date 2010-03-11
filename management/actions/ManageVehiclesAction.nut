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
	Log.logInfo("Sell " + vehiclesToSell.len() + " vehicles.");
	foreach (engineInfo in vehiclesToSell) {
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];
		local vehicleType = AIEngine.GetVehicleType(engineID);
		
		pathfinder.pathFinderHelper.SetStationBuilder(AIEngine.IsArticulated(engineID));
		
		// First of all we need to find suitable candidates to remove.
		local vehicleList = AIList();
		local vehicleArray = null;

		local vehicleList = AIVehicleList_Group(connection.vehicleGroupID);
		vehicleList.Valuate(AIVehicle.GetAge);
		vehicleList.Sort(AIAbstractList.SORT_BY_VALUE, true);
		vehicleList.Valuate(AIVehicle.GetEngineType);
		vehicleList.KeepValue(engineID);
		if (!connection.bilateralConnection) {
			vehicleList.Valuate(AIVehicle.GetCargoLoad, AIEngine.GetCargoType(engineID));
			vehicleList.RemoveAboveValue(0);
		}

		local vehiclesDeleted = 0;
		
		foreach (vehicleID, value in vehicleList) {
			
			// Take a different approach with ships, as they might get lost.
			if (vehicleType == AIVehicle.VT_WATER) {
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

		local maxBuildableVehicles =  GameSettings.GetMaxBuildableVehicles(vehicleType);
		if (vehicleNumbers > maxBuildableVehicles)
			vehicleNumbers = maxBuildableVehicles;
		
		Log.logInfo("Buy " + vehicleNumbers + " " + AIEngine.GetName(engineID) + AIEngine.GetName(wagonEngineID) + ".");

		// Search if there are already have a vehicle group for this connection.
		if (!AIGroup.IsValidGroup(connection.vehicleGroupID)) {
			connection.vehicleGroupID = AIGroup.CreateGroup(AIEngine.GetVehicleType(engineID));
			AIGroup.SetName(connection.vehicleGroupID, connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName());
		}
		
		// Check if the travel times are already know for this engine type, if not: update them!
		if (!connection.timeToTravelTo.rawin(engineID)) {			
			if (vehicleType == AIVehicle.VT_ROAD) {
				connection.timeToTravelTo[engineID] <- RoadPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				connection.timeToTravelFrom[engineID] <- RoadPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			} else if (vehicleType == AIVehicle.VT_AIR){ 
				local manhattanDistance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
				connection.timeToTravelTo[engineID] <- (manhattanDistance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(engineID)).tointeger();
				connection.timeToTravelFrom[engineID] <- (manhattanDistance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(engineID)).tointeger();
			} else if (vehicleType == AIVehicle.VT_WATER) {
				connection.timeToTravelTo[engineID] <- WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				connection.timeToTravelFrom[engineID] <- WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			} else if (vehicleType == AIVehicle.VT_RAIL) {
				connection.timeToTravelTo[engineID] <- RailPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				connection.timeToTravelFrom[engineID] <- RailPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			} else
				assert (false);
		}
		
		// In case of a bilateral connection we want to spread the load by sending the trucks
		// in opposite directions.
		local directionToggle = AIStation.GetCargoWaiting(connection.travelFromNodeStationID, connection.cargoID) 
		> AIStation.GetCargoWaiting(connection.travelToNodeStationID, connection.cargoID);
		
		// Use a 'main' vehicle to enable the sharing of orders.
		local roadList = connection.pathInfo.roadList;

		// If we want to build aircrafts or ships, we only want to build 1 per station!
		if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER || AIEngine.GetVehicleType(engineID) == AIVehicle.VT_AIR) {
			if (connection.bilateralConnection && vehicleNumbers > 4)
				vehicleNumbers = 4;
			else if (vehicleNumbers > 2)
				vehicleNumbers = 2;
		} else if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_ROAD) {
			if (connection.bilateralConnection && vehicleNumbers > 30)
				vehicleNumbers = 30;
			else if (vehicleNumbers > 15)
				vehicleNumbers = 15;
		}
			
		local vehiclePrice = AIEngine.GetPrice(engineID);
		if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_RAIL)
			vehiclePrice += numberWagons * AIEngine.GetPrice(wagonEngineID);
		totalCosts = vehiclePrice;

		local vehicleCloneID = -1;
		local vehicleCloneIDReverse = -1;
		for (local i = 0; i < vehicleNumbers; i++) {
		
			if (Finance.GetMaxMoneyToSpend() - vehiclePrice < 0) {
				Log.logDebug("Not enough money to build all prescibed vehicles!");
				break;
			}
					
			local vehicleID;

			if (!directionToggle && connection.pathInfo.depotOtherEnd) {
				if (vehicleCloneIDReverse != -1) {
					vehicleID = AIVehicle.CloneVehicle(connection.pathInfo.depotOtherEnd, vehicleCloneIDReverse, false);
					directionToggle = !directionToggle;
					vehicleGroup.vehicleIDs.push(vehicleID);
					continue;
				}
				vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depotOtherEnd, engineID);
			} else {
				if (vehicleCloneID != -1) {
					vehicleID = AIVehicle.CloneVehicle(connection.pathInfo.depot, vehicleCloneID, false);
					directionToggle = !directionToggle;
					vehicleGroup.vehicleIDs.push(vehicleID);
					continue;
				}
				vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depot, engineID);
			}
			if (!AIVehicle.IsValidVehicle(vehicleID)) {
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + connection.pathInfo.depotOtherEnd + "!");
				continue;
			}

			// Refit if necessary.
			if (connection.cargoID != AIEngine.GetCargoType(engineID))
				AIVehicle.RefitVehicle(vehicleID, connection.cargoID);
			//vehicleGroup.vehicleIDs.push(vehicleID);
			AIGroup.MoveVehicle(connection.vehicleGroupID, vehicleID);

			// In the case of a train, also build the wagons (as a start we'll build 3 by default ;)).
			// TODO: Make sure to make this also works for cloned vehicles.
			if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_RAIL) {
				for (local j = 0; j < numberWagons; j++) {
					local wagonVehicleID = AIVehicle.BuildVehicle((!directionToggle && connection.pathInfo.depotOtherEnd ? connection.pathInfo.depotOtherEnd : connection.pathInfo.depot), wagonEngineID);
				
					if (!AIVehicle.IsValidVehicle(wagonVehicleID)) {
						Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + " " + connection.pathInfo.depot + "!");
						continue;
					}
				
					AIVehicle.MoveWagon(wagonVehicleID, 0, vehicleID, 0);
				}
			}
			
			// Send the vehicles on their way.
			if (connection.bilateralConnection && !directionToggle) {
				if (vehicleType == AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.AIOF_NONE);
				AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD_ANY);
				if (vehicleType != AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.AIOF_NONE);

				// If it's a ship, give it additional orders!
				if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER)
					for (local i = 1; i < roadList.len() - 1; i++)
						AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.AIOF_NONE);

				if (vehicleType == AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_NONE);
				AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD_ANY);

				if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER) 
					for (local i = roadList.len() - 2; i > 0; i--)
					AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.AIOF_NONE);

				if (vehicleType != AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_NONE);
			} else {
				if (vehicleType == AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_NONE);
				AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD_ANY);
				if (vehicleType != AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_NONE);

				// If it's a ship, give it additional orders!
				if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER)
					for (local i = roadList.len() - 2; i > 0; i--)
						AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.AIOF_NONE);

				if (vehicleType == AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.AIOF_NONE);

				if (connection.bilateralConnection)
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD_ANY);
				else
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_UNLOAD);
					
				if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER)
					for (local i = 1; i < roadList.len() - 1; i++)
						AIOrder.AppendOrder(vehicleID, roadList[i].tile, AIOrder.AIOF_NONE);

				if (connection.bilateralConnection && vehicleType != AIVehicle.VT_RAIL)
					AIOrder.AppendOrder(vehicleID, connection.pathInfo.depotOtherEnd, AIOrder.AIOF_NONE);
			}

			// As a first order, let the vehicle do it's normal actions when not old enough.
			AIOrder.InsertConditionalOrder(vehicleID, 0, 0);
			
			// Set orders to stop the vehicle in a depot once it reached its max age.
			AIOrder.SetOrderCondition(vehicleID, 0, AIOrder.OC_AGE);
			AIOrder.SetOrderCompareFunction(vehicleID, 0, AIOrder.CF_LESS_THAN);
			AIOrder.SetOrderCompareValue(vehicleID, 0, AIEngine.GetMaxAge(engineID) / 366);
			
			// Insert the stopping order, which will be skipped by the previous conditional order
			// if the vehicle hasn't reached its maximum age.
			if (connection.bilateralConnection && directionToggle)
				AIOrder.InsertOrder(vehicleID, 1, connection.pathInfo.depotOtherEnd, AIOrder.AIOF_STOP_IN_DEPOT);
			else
				AIOrder.InsertOrder(vehicleID, 1, connection.pathInfo.depot, AIOrder.AIOF_STOP_IN_DEPOT);

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
