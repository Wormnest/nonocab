class ManageVehiclesAction extends Action {

	vehiclesToSell = null;		// List of vehicles IDs which need to be sold.
	vehiclesToBuy = null;		// List of [engine IDs, number of vehicles to buy, tile ID of a depot]
	
	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
		Action.constructor(null);
	}
	
	/**
	 * Sell a vehicle when this action is executed.
	 * @param vehicleID The vehicle ID of the vehicle which needs to be sold.
	 */
	function SellVehicle(vehicleID);
	
	/**
	 * Buy a certain number of vehicles when this action is executed.
	 * @param engineID The engine ID of the vehicles which need to be build.
	 * @param number The number of vehicles to build.
	 * @param connection The connection where the vehicles are to operate on.
	 */
	function BuyVehicles(engineID, number, connection);
}

function ManageVehiclesAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
}

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
		local connectionNode = engineInfo[2];
		local vehicleID = null;
		local vehicleGroup = null;
		
		Log.logInfo("Buy " + vehicleNumbers + " " + AIEngine.GetName(engineID) + ".");
		
		// Search if there are already have a vehicle group with this engine ID.
		foreach (vGroup in connectionNode.vehiclesOperating) {
			if (vGroup.engineID == engineID) {
				vehicleGroup = vGroup;
				break;
			}
		}	
		
		// If there isn't a vehicles group we create one.
		if (vehicleGroup == null) {
			vehicleGroup = VehicleGroup();
			vehicleGroup.connection = connectionNode;
			connectionNode.vehiclesOperating.push(vehicleGroup);
		}		
		
		for (local i = 0; i < vehicleNumbers; i++) {
			local vehicleID = AIVehicle.BuildVehicle(connectionNode.pathInfo.depot,	engineID);
			if (!AIVehicle.IsValidVehicle(vehicleID)) {
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
				continue;
			}
			
			vehicleGroup.vehicleIDs.push(vehicleID);
		}			
	}
	CallActionHandlers();
}