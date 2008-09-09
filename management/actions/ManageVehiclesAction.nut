class ManageVehiclesAction extends Action {

	vehiclesToSell = null;		// List of vehicles IDs which need to be sold.
	vehiclesToBuy = null;		// List of [engine IDs, number of vehicles to buy, tile ID of a depot]
	buildVehicles = null;		// List of vehicles IDs of all vehicles that are build.
	
	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
		buildVehicles = [];
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
	 * @param depot The depot where the vehicles are build.
	 */
	function BuyVehicles(engineID, number, depot);
}

function ManageVehiclesAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
}

function ManageVehiclesAction::BuyVehicles(engineID, number, pathInfo)
{
	vehiclesToBuy.push([engineID, number, pathInfo]);
}

function ManageVehiclesAction::Execute()
{
	// Sell the vehicles.
	foreach (vehicleID in vehiclesToSell) {
		AIVehicle.SellVehicle(vehicleID);
	}
	
	// Buy the vehicles.
	Log.logInfo("Buy " + vehiclesToBuy.len() + " and sell " + vehiclesToSell.len() + " vehicles.");
	foreach (engineNumber in vehiclesToBuy) {
		
		for (local i = 0; i < engineNumber[1]; i++) {
			local vehicleID = AIVehicle.BuildVehicle(engineNumber[2].depot, engineNumber[0]);
			if (!AIVehicle.IsValidVehicle(vehicleID)) {
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
				continue;
			}
			
			buildVehicles.push(vehicleID);
		}
	}
	CallActionHandlers();
}