class ManageVehiclesAction extends Action {

	vehiclesToSell = null;
	vehiclesToBuy = null;
	
	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
	}
	
	function SellVehicle(vehicleID);
	function BuyVehicles(engineID, number, industryConnection);
}

function ManageVehiclesAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
}

function ManageVehiclesAction::BuyVehicles(engineID, number, industryConnection)
{
	vehiclesToBuy.push([engineID, number, industryConnection]);
}

function ManageVehiclesAction::Execute()
{
	Log.logInfo("Buy " + vehiclesToBuy.len() + " and sell " + vehiclesToSell.len() + " vehicles.");
	foreach (engineNumber in vehiclesToBuy) {
		
		local vehicleGroup = null;
		
		// Search if there are already have a vehicle group with this engine ID.
		foreach (vGroup in engineNumber[2].vehiclesOperating) {
			if (vGroup.engineID == engineNumber[0]) {
				vehicleGroup = vGroup;
				break;
			}
		}
		
		if (vehicleGroup == null) {
			vehicleGroup = VehicleGroup();
			vehicleGroup.industryConnection = engineNumber[2];
		}
		
		for (local i = 0; i < engineNumber[1]; i++) {
			local vehicleID = AIVehicle.BuildVehicle(engineNumber[2].pathInfo.depot, engineNumber[0]);
			if (!AIVehicle.IsValidVehicle(vehicleID))
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
			vehicleGroup.vehicleIDs.push(vehicleID);
		}
		
		engineNumber[2].vehiclesOperating.push(vehicleGroup);
	}
	
	foreach (vehicleID in vehiclesToSell) {
		AIVehicle.SellVehicle(vehicleID);
	}
}