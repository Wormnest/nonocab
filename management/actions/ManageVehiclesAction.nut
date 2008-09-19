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
function ManageVehiclesAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
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
	// Sell the vehicles.
	Log.logInfo("Sell " + vehiclesToSell.len() + " vehicles.");
	foreach (vehicleID in vehiclesToSell) {
		AIVehicle.SellVehicle(vehicleID);
	}
	
	// Buy the vehicles.
	foreach (engineInfo in vehiclesToBuy) {
		
		local engineID = engineInfo[0];
		local vehicleNumbers = engineInfo[1];
		local connection = engineInfo[2];
		local vehicleID = null;
		local vehicleGroup = null;
		
		if (connection.cargoID != AIEngine.GetCargoType(engineID)) {
			Log.logError("Mismatch " + AICargo.GetCargoLabel(connection.cargoID));
			Log.logError("vs " + AICargo.GetCargoLabel(AIEngine.GetCargoType(engineID))	);
			abc();
		}
		
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
			
			local pathfinder = RoadPathFinding();
			vehicleGroup.timeToTravelTo = pathfinder.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
			vehicleGroup.timeToTravelFrom = pathfinder.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), false);
			vehicleGroup.incomePerRun = AICargo.GetCargoIncome(connection.cargoID, 
				AIMap.DistanceManhattan(connection.pathInfo.roadList[0].tile, connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 1].tile), 
				vehicleGroup.timeToTravelTo) * AIEngine.GetCapacity(engineID);	
			vehicleGroup.engineID = engineID;
			
			
			connection.vehiclesOperating.push(vehicleGroup);
		}		
		
		for (local i = 0; i < vehicleNumbers; i++) {
			// DEBUG: What's goes wrong?
			if(connection.pathInfo.depot == null)
			{
				Log.logError("No Depot available to build engine");
			}
			else
			{
				local vehicleID = AIVehicle.BuildVehicle(connection.pathInfo.depot,	engineID);
				if (!AIVehicle.IsValidVehicle(vehicleID)) {
					Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
					continue;
				}
				vehicleGroup.vehicleIDs.push(vehicleID);
				
				// Send the vehicles on their way.
				local roadList = connection.pathInfo.roadList;
				if(connection.bilateralConnection)
				{
					AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_TRANSFER);
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_TRANSFER);
				}
				else
				{
					AIOrder.AppendOrder(vehicleID, roadList[roadList.len() - 1].tile, AIOrder.AIOF_FULL_LOAD);
					AIOrder.AppendOrder(vehicleID, roadList[0].tile, AIOrder.AIOF_UNLOAD);
				}
				AIOrder.AppendOrder(vehicleID, connection.pathInfo.depot, AIOrder.AIOF_SERVICE_IF_NEEDED);
				AIVehicle.StartStopVehicle(vehicleID);
			}
		}			
	}
	CallActionHandlers();
	return true;
}