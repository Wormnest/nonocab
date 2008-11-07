class ManageVehiclesAction extends Action {

	vehiclesToSell = null;		// List of vehicles IDs which need to be sold.
	vehiclesToBuy = null;		// List of [engine IDs, number of vehicles to buy, tile ID of a depot]
	
	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
		Action.constructor();
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
				foreach (vehicleID in vehicleGroup.vehicleIDs) {
					// Check if the vehicle is going to the delivery tile.
					vehicleList.AddItem(vehicleID, vehicleID);
				}
				vehicleArray = vehicleGroup.vehicleIDs;
				break;
			}
		}
		vehicleList.Valuate(AIVehicle.GetAge);
		vehicleList.Sort(AIAbstractList.SORT_BY_VALUE, false);
		vehicleList.Valuate(AIVehicle.GetCargoLoad, AIEngine.GetCargoType(engineID));
		vehicleList.RemoveAboveValue(0);

		local vehiclesDeleted = 0;
		
		foreach (vehicleID, value in vehicleList) {
				
			// First remove all order of this vehicle.
			//while (AIOrder.RemoveOrder(vehicleID, 0));
			//if (!AIRoad.IsRoadDepotTile(AIOrder.GetOrderDestination(vehicleID, AIOrder.CURRENT_ORDER))) {
        	if (!AIVehicle.SendVehicleToDepot(vehicleID)) {
        		AIVehicle.ReverseVehicle(vehicleID);
				AIController.Sleep(50);
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

			if (vehiclesDeleted == vehicleNumbers)
				break;
		}
	}
	
	// Buy the vehicles.
	foreach (engineInfo in vehiclesToBuy) {
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];

		local vehicleID = null;
		local vehicleGroup = null;
		
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
			
			if (AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_ROAD) {
				local pathfinder = RoadPathFinding(PathFinderHelper());
				vehicleGroup.timeToTravelTo = pathfinder.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				vehicleGroup.timeToTravelFrom = pathfinder.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			} else if (AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_AIR){ 
				local manhattanDistance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
				vehicleGroup.timeToTravelTo = (manhattanDistance * RoadPathFinding.straightRoadLength / AIEngine.GetMaxSpeed(engineID)).tointeger();
				vehicleGroup.timeToTravelFrom = vehicleGroup.timeToTravelTo;
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
		for (local i = 0; i < vehicleNumbers; i++) {
		
			if (Finance.GetMaxMoneyToSpend() - AIEngine.GetPrice(engineID) < 0) {
				Log.logDebug("Not enough money to build all prescibed vehicles!");
				break;
			}
					
			local vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depot,	engineID);
			if (!AIVehicle.IsValidVehicle(vehicleID)) {
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
				continue;
			}
			vehicleGroup.vehicleIDs.push(vehicleID);
			
			// Send the vehicles on their way.
			local roadList = connection.pathInfo.roadList;
			if(connection.bilateralConnection) {

				if (directionToggle) {
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD);
					AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD);
				} else {
					AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD);
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_FULL_LOAD);
				}
				directionToggle = !directionToggle;
			} else {
				AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD);
				AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_UNLOAD);
			}
			
			if (!AIEngine.GetVehicleType(engineID) == AIVehicle.VEHICLE_AIR)
				AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
			AIVehicle.StartStopVehicle(vehicleID);
		}			
	}
	CallActionHandlers();
	return true;
}
