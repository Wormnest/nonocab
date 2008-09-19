class ConnectionReport extends Report {

	profitPerMonthPerVehicle = 0;	// The utility value.
	engineID = 0;			// The vehicles to build.
	nrVehicles = 0;			// The number of vehicles to build.
	roadList = null;		// The road to build.

	fromConnectionNode = null;	// The node which produces the cargo.
	toConnectionNode = null;	// The node which accepts the produced cargo.
	
	cargoID = 0;			// The cargo to transport.
	
	cost = 0;			// The cost of this operation.
	
	constructor() {
		
	}
	
	/**
	 * Get the utility function, this is the profit per invested unit of money.
	 */
	function Utility() {
		return cost / (profitPerMonthPerVehicle * nrVehicles);
	}
	
	function Profit() {
		return profitPerMonthPerVehicle * nrVehicles;
	}
	
	function Print() {
		Log.logDebug(ToString());
	}
	
	function ToString() {
		return "Build a road from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " vehicles. Cost: " +
		cost + " income per month per vehicle: " + profitPerMonthPerVehicle;
	}
}
