/**
 * In order to build and maintain connections between nodes we keep track
 * of all vehicles on those connections and their status.
 */
class VehicleGroup
{
	timeToTravelTo = null;			// Time in days it takes all vehicles in this group to 
									// travel from the accepting node to the producing
									// node.
	timeToTravelFrom = null;		// Time in days it takes all vehicles in this group to 
									// travel from the producing node to the accepting
									// node.
	incomePerRun = null;			// The average income per vehicle per run per vehicle.
	engineID = null;				// The engine ID of all vehicles in this group.
	connection = null;				// The connection all vehicles in this group
									// operate on.
	vehicleIDs = null;				// All vehicles IDs of this group.
	
	constructor() {
		vehicleIDs = [];
	}
}